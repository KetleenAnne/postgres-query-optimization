# 🎓 Study Guide · Guia de Estudo (PT)

> Guia em português, com os termos técnicos em inglês (é como você vai ouvir nas entrevistas e na documentação). Os números vêm do próprio laboratório: veja [`results/`](../results/). As fontes estão em [SOURCES.md](SOURCES.md).

## 📑 Sumário

- [0. A ideia central em 1 minuto](#ideia)
- [1. Como ler um `EXPLAIN` (sem medo)](#explain)
- [2. Cenário 01: índice faltando na chave estrangeira](#c01)
- [3. Cenário 02: subconsulta correlacionada](#c02)
- [4. Cenário 03: índice parcial](#c03)
- [5. Cenário 04: busca de texto com `%palavra%`](#c04)
- [6. Quadro-resumo](#resumo)
- [7. Armadilhas comuns](#armadilhas)
- [8. Para ir além](#alem)

<a id="ideia"></a>

## 0. A ideia central em 1 minuto

Quando você manda uma query, o PostgreSQL **não executa direto**: o *planner* escolhe um plano (a "receita"). Otimizar é:

1. **Medir** (não chutar) → `EXPLAIN (ANALYZE, BUFFERS)`
2. **Achar o gargalo** no plano (qual nó demora ou lê muitas páginas?)
3. **Mudar uma coisa** (índice ou reescrever a query)
4. **Medir de novo** e comparar

Regra de ouro: **uma mudança por vez**, senão você não sabe o que funcionou.

<a id="explain"></a>

## 1. Como ler um `EXPLAIN` (sem medo)

Leia **de dentro para fora** (o nó mais indentado roda primeiro) e **de baixo para cima**.

```
Aggregate                                   ← 3. soma o resultado
  -> Bitmap Heap Scan on loans              ← 2. lê as linhas nas páginas marcadas
       -> Bitmap Index Scan on loans_member_id_idx   ← 1. acha QUAIS páginas (usa o índice)
```

O que olhar, em ordem:

| Onde | O que significa | Sinal de alerta |
|---|---|---|
| `Seq Scan` / `Parallel Seq Scan` | Leu a tabela inteira | Em tabela grande, quando você queria poucas linhas |
| `Buffers: shared hit=N` | Páginas de 8 kB lidas | Números enormes (milhares ou milhões) |
| `loops=N` | Quantas vezes o nó rodou | `loops=100000` num nó interno |
| `actual time=a..b` | Tempo do 1º ao último resultado, **por loop** | Multiplique por `loops` |
| `rows=` estimado vs real | Quão certo o planner estava | Muito diferente → rode `ANALYZE` |
| `Execution Time` (no fim) | Tempo total real | É a métrica que usamos |

> ⚠️ `cost=` **não é tempo**: é uma estimativa em unidades arbitrárias. Use `actual time` e `Execution Time`.

<a id="c01"></a>

## 2. Cenário 01: índice faltando na chave estrangeira

**A query:** `SELECT count(*), max(loaned_at) FROM loans WHERE member_id = 4242;`

**O problema.** `loans.member_id` aponta para `members.id`, mas o PostgreSQL **não cria índice** para chaves estrangeiras sozinho. Sem índice, o jeito de achar os empréstimos do membro 4242 é olhar a tabela inteira.

**O que o plano mostra (antes):** `Parallel Seq Scan on loans`, **18.678 buffers**. Para devolver ~15 linhas, ele leu 2 milhões.

**A correção:** `CREATE INDEX loans_member_id_idx ON loans (member_id);`

**Depois:** `Bitmap Index Scan` + `Bitmap Heap Scan`, **21 buffers** no nó principal. De 91,6 ms para 0,3 ms (~300x).

**Para guardar:** *filtro ou JOIN por uma coluna em tabela grande? Pergunte "tem índice nela?"*. Em chave estrangeira, quase sempre vale ter.

**Mas tem custo:** todo índice ocupa disco e deixa `INSERT/UPDATE/DELETE` um pouco mais lentos. Não é "índice em tudo".

<a id="c02"></a>

## 3. Cenário 02: subconsulta correlacionada

**A query ruim:**
```sql
SELECT count(*) FROM members m
WHERE (SELECT count(*) FROM loans l WHERE l.member_id = m.id) = 0;
```
Lê como "para **cada** membro, **conte** todos os empréstimos dele e veja se é zero".

**O que o plano mostra:** a subconsulta roda com `loops=100000` (uma vez por membro) e soma **~2,3 milhões de buffers**. E repare: **o índice do cenário 01 já existe** e mesmo assim demora 3,2 s.

**A correção** (mesma pergunta, outra forma):
```sql
SELECT count(*) FROM members m
WHERE NOT EXISTS (SELECT 1 FROM loans l WHERE l.member_id = m.id);
```
Agora o plano vira `Nested Loop Anti Join`: para cada membro, basta achar **um** empréstimo para descartá-lo. Não precisa contar tudo. ~300 mil buffers, 99,7 ms (~32x).

**Para guardar:** *ter o índice não basta; o formato da query importa.* `count(*) = 0` quer dizer "conte tudo"; `NOT EXISTS` quer dizer "existe algum?", e para no primeiro.

<a id="c03"></a>

## 4. Cenário 03: índice parcial

**A query:** os 50 empréstimos atrasados mais antigos (`returned_at IS NULL` e vencidos há mais de 30 dias), `ORDER BY due_at LIMIT 50`.

**Antes:** `Gather Merge` + `Sort` (top-N heapsort) sobre **18.752 buffers**. Leu a tabela toda para ordenar e pegar 50.

**A correção:**
```sql
CREATE INDEX loans_open_due_idx ON loans (due_at) WHERE returned_at IS NULL;
```
Só ~2% dos empréstimos estão em aberto, então o índice só guarda essas linhas: **896 kB em vez de 43 MB** para um índice completo na mesma coluna. Como o índice já está ordenado por `due_at`, o `ORDER BY ... LIMIT 50` **lê 50 entradas e para**.

**Depois:** `Index Scan using loans_open_due_idx`, **52 buffers**, 0,5 ms (~150x).

**Pegadinha:** a query precisa **repetir o predicado do índice** (`returned_at IS NULL`) para o planner poder usá-lo. Se você tirar essa condição da query, o índice parcial não serve.

**Para guardar:** *quando você consulta sempre um pedaço pequeno e "quente" da tabela (pendentes, ativos, não processados), um índice parcial é menor, mais rápido e mais barato de manter.*

<a id="c04"></a>

## 5. Cenário 04: busca de texto com `%palavra%`

**A query:** `SELECT count(*) FROM books WHERE title ILIKE '%lighthouse%';`

**O problema.** Um B-tree é como uma lista telefônica: ordenada pelo **começo** da palavra. Com `%` no início você não sabe por onde começar, então ele lê tudo: `Parallel Seq Scan`, 3.349 buffers.

**A correção:**
```sql
CREATE INDEX books_title_trgm_idx ON books USING gin (title gin_trgm_ops);
```
A extensão `pg_trgm` quebra o texto em **trigramas** (pedaços de 3 letras) e o GIN indexa cada pedaço. Buscar `'%lighthouse%'` vira buscar os trigramas dessa palavra, o que **não precisa começar no início**.

**Depois:** `Bitmap Index Scan` (33 buffers) + `Bitmap Heap Scan`, 2,0 ms (~60x).

**Limite:** a documentação avisa que um padrão sem trigramas extraíveis (por exemplo, muito curto) degrada para varrer o índice inteiro. Ver [SOURCES.md](SOURCES.md).

**Para guardar:** *busca "contém" em texto grande → trigram + GIN. Busca de linguagem natural (stemming, ranking) é outro assunto: full-text search.*

<a id="resumo"></a>

## 6. Quadro-resumo

| # | Sintoma no plano | Causa | Remédio |
|---|---|---|---|
| 01 | `Seq Scan` retornando poucas linhas | Falta índice em FK/filtro | `CREATE INDEX` |
| 02 | `loops` enorme + muitos buffers | Subconsulta correlacionada | Reescrever (`NOT EXISTS`/JOIN) |
| 03 | `Sort` + `Seq Scan` para `LIMIT` pequeno em subconjunto | Índice completo seria grande/inútil | Índice **parcial** |
| 04 | `Seq Scan` com `LIKE '%x%'` | B-tree não atende curinga no início | GIN + `pg_trgm` |

<a id="armadilhas"></a>

## 7. Armadilhas comuns

- **Medir uma vez só.** A primeira execução pode ser mais lenta (cache). O laboratório faz aquecimento + mediana de 5.
- **Esquecer o `ANALYZE`** depois de criar índice ou carregar dados: o planner decide com estatísticas velhas.
- **`EXPLAIN ANALYZE` em `UPDATE/DELETE`** executa de verdade. Use dentro de `BEGIN; ... ROLLBACK;`.
- **Criar índice em produção sem pensar:** `CREATE INDEX` comum bloqueia escritas na tabela. Em produção, estude `CREATE INDEX CONCURRENTLY` (ver [SOURCES.md](SOURCES.md)).
- **Achar que o índice sempre é usado.** Se a query devolve boa parte da tabela, o `Seq Scan` pode ser a melhor escolha, e o planner sabe disso.
- **Concluir demais.** O laboratório é pequeno, com dados sintéticos e cache quente. As **proporções e os planos** ensinam; os milissegundos absolutos não.

<a id="alem"></a>

## 8. Para ir além

- [Use The Index, Luke](https://use-the-index-luke.com/): tutorial gratuito e muito bom sobre índices (cobre PostgreSQL).
- Documentação oficial do PostgreSQL sobre `EXPLAIN`, índices parciais e `pg_trgm`: links verificados em [SOURCES.md](SOURCES.md).
- Depois do guia, faça os [EXERCISES.md](EXERCISES.md) e treine a explicação em voz alta com o [INTERVIEW_PREP.md](INTERVIEW_PREP.md).
