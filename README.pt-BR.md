<a id="topo"></a>

# 🐘 PostgreSQL Query Optimization

[🇬🇧 English](README.md) · 🇧🇷 **Português**

Quatro consultas lentas, cada uma diagnosticada com `EXPLAIN (ANALYZE, BUFFERS)`, corrigida e medida de novo. Cada correção traz o plano antes e depois, para você ver *por que* ficou mais rápido, e não só que ficou.

> 🧪 Dados 100% sintéticos (uma "biblioteca" pequena: 100 mil membros, 300 mil livros, 2 milhões de empréstimos). Nenhum código de empresa, nenhum dado real.

## 📑 Sumário

- [📊 Resultados](#resultados)
- [🔍 O que cada cenário ensina](#cenarios)
  - [01 · Índice faltando na chave estrangeira](#cenario-01)
  - [02 · Subconsulta correlacionada](#cenario-02)
  - [03 · Índice parcial](#cenario-03)
  - [04 · Busca por trigramas](#cenario-04)
- [▶️ Rode você mesma](#rodar)
- [📚 Documentação e material de estudo](#docs)
- [🗂️ Estrutura do projeto](#estrutura)
- [⚠️ Notas honestas](#notas)

<a id="resultados"></a>

## Resultados

Mediana de 5 execuções após um aquecimento, PostgreSQL 16, cache quente, máquina local pequena. Os números absolutos variam; o que importa são as **proporções e os planos**.

| # | Problema | Correção | Antes | Depois | Ganho |
|---|---|---|---:|---:|---:|
| [01](#cenario-01) | Filtro por chave estrangeira sem índice | `CREATE INDEX` em `loans(member_id)` | 91,6 ms | 0,3 ms | **~300x** |
| [02](#cenario-02) | "Membros sem empréstimos" escrito com `count(*)` correlacionado | Reescrever como `NOT EXISTS` (anti-join) | 3.194 ms | 99,7 ms | **~32x** |
| [03](#cenario-03) | Empréstimos atrasados mais antigos (só 2% das linhas estão em aberto) | Índice parcial `ON loans (due_at) WHERE returned_at IS NULL` | 81,3 ms | 0,5 ms | **~150x** |
| [04](#cenario-04) | `ILIKE '%palavra%'` em 300 mil títulos | Índice GIN de trigramas (`pg_trgm`) | 118,8 ms | 2,0 ms | **~60x** |

Os planos completos estão em [`results/`](results/) (`*_before.txt` e `*_after.txt`).

<sub>[⬆ voltar ao topo](#topo)</sub>

<a id="cenarios"></a>

## O que cada cenário ensina

<a id="cenario-01"></a>

### 01 · Índice faltando na chave estrangeira

```sql
SELECT count(*), max(loaned_at) FROM loans WHERE member_id = 4242;
-- correção
CREATE INDEX loans_member_id_idx ON loans (member_id);
```

O PostgreSQL *não* cria índice para chave estrangeira automaticamente. No plano "antes" há uma varredura sequencial paralela que lê a tabela inteira (18.678 buffers) para devolver poucas linhas; no plano "depois" há uma varredura por índice em bitmap (21 buffers).

**Para guardar:** filtra ou junta por uma coluna de uma tabela grande? Pergunte "tem índice nela?"

<a id="cenario-02"></a>

### 02 · Subconsulta correlacionada

```sql
-- lenta: uma contagem por membro
SELECT count(*) FROM members m
WHERE (SELECT count(*) FROM loans l WHERE l.member_id = m.id) = 0;
-- rápida: a mesma pergunta como anti-join
SELECT count(*) FROM members m
WHERE NOT EXISTS (SELECT 1 FROM loans l WHERE l.member_id = m.id);
```

A versão com `count(*)` executa a subconsulta uma vez por membro (100 mil repetições, ~2,3 milhões de acessos a buffers), *mesmo com o índice do cenário 01*. O `NOT EXISTS` permite ao planner usar um **Anti Join** com Nested Loop, que pode parar no primeiro registro encontrado.

**Para guardar:** ter o índice não basta: o formato da consulta importa.

<a id="cenario-03"></a>

### 03 · Índice parcial

```sql
CREATE INDEX loans_open_due_idx ON loans (due_at) WHERE returned_at IS NULL;
```

Só ~2% dos empréstimos estão em aberto, então um índice restrito a `returned_at IS NULL` é minúsculo: **896 kB** contra **43 MB** de um índice completo na mesma coluna. Ele também entrega as linhas já ordenadas por `due_at`, então `ORDER BY ... LIMIT 50` para depois de ler 50 entradas. A consulta precisa repetir o predicado do índice (`returned_at IS NULL`) para o planner poder usá-lo.

**Para guardar:** para um subconjunto pequeno e "quente" (pendentes, ativos, não processados), o índice parcial é menor, mais rápido e mais barato de manter.

<a id="cenario-04"></a>

### 04 · Busca por trigramas

```sql
CREATE INDEX books_title_trgm_idx ON books USING gin (title gin_trgm_ops);
```

Um índice B-tree não ajuda com curinga no início (`'%palavra%'`). Um índice GIN com `gin_trgm_ops` (extensão `pg_trgm`) ajuda, porque indexa pedaços de 3 caracteres do texto.

**Para guardar:** busca "contém" em texto grande → trigramas + GIN.

<sub>[⬆ voltar ao topo](#topo)</sub>

<a id="rodar"></a>

## Rode você mesma

```bash
docker compose up -d                 # cria e popula o banco (~1 min na primeira vez)
export DATABASE_URL="postgresql://lab:lab@localhost:5432/lab"
./scripts/run.sh                     # todos os cenários; ou ./scripts/run.sh 03
cat results/summary.md
```

Requisitos: Docker e o cliente `psql`. Os cenários foram executados no PostgreSQL 16. Para rodar um cenário passo a passo e resolver problemas comuns, veja o [Primeiros passos](docs/GETTING_STARTED.md).

<sub>[⬆ voltar ao topo](#topo)</sub>

<a id="docs"></a>

## Documentação e material de estudo

| Documento | O que é |
|---|---|
| [Primeiros passos](docs/GETTING_STARTED.md) | Instalar, rodar, rodar na mão, resolver problemas |
| [Guia de estudo](docs/STUDY_GUIDE.md) | Aulas por cenário + como ler `EXPLAIN` |
| [Glossário](docs/GLOSSARY.md) | Todos os termos em linguagem simples |
| [Exercícios](docs/EXERCISES.md) | Quebre, conserte, meça |
| [Preparação para entrevista](docs/INTERVIEW_PREP.md) | Perguntas que podem surgir sobre este projeto |
| [Fontes](docs/SOURCES.md) | Fontes verificadas das afirmações técnicas |

<a id="estrutura"></a>

## Estrutura do projeto

```
sql/                 schema e dados sintéticos (semente aleatória fixa)
scenarios/NN_*/      query.sql (lenta) · fix.sql ou query_fixed.sql · reset.sql
scripts/run.sh       mede antes/depois e grava em results/
results/             planos de execução + summary.md
docs/                guias, glossário, exercícios, fontes
```

<a id="notas"></a>

## Notas honestas

- Os tempos vêm de cache quente (tudo cabe em memória). Com cache frio, as varreduras sequenciais do "antes" seriam ainda mais lentas.
- Índices não são de graça: ocupam disco e deixam as escritas mais lentas. Em produção, crie com `CREATE INDEX CONCURRENTLY` e confira se estão realmente sendo usados (`pg_stat_user_indexes`).
- **Meça antes de otimizar**: o primeiro passo de cada cenário é ler o plano, não chutar.

---

Feito por [Ketleen](https://github.com/KetleenAnne) · ☕ + 🐱 (o Gael supervisionou)
