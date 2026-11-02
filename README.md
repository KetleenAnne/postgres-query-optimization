# 🐘 PostgreSQL Query Optimization

**EN** · Four slow queries, each one diagnosed with `EXPLAIN (ANALYZE, BUFFERS)`, fixed, and measured again.
**PT** · Quatro consultas lentas, cada uma diagnosticada com `EXPLAIN (ANALYZE, BUFFERS)`, corrigida e medida de novo.

> 🧪 100% synthetic data (a tiny "public library": 100k members, 300k books, 2M loans). No company code, no real data.
> 🧪 Dados 100% sintéticos (uma "biblioteca": 100 mil membros, 300 mil livros, 2 milhões de empréstimos).

## 📊 Results · Resultados

Median of 5 runs after a warm-up, PostgreSQL 16, warm cache, small local machine. Your absolute numbers will differ; the **ratios and the plans** are what matter.
Mediana de 5 execuções após um aquecimento, PostgreSQL 16, cache quente, máquina local pequena. Os números absolutos variam; o que importa são as **proporções e os planos**.

| # | Problem · Problema | Fix · Correção | Before | After | Speed-up |
|---|---|---|---:|---:|---:|
| 01 | Filtering by a foreign key without an index · Filtro por chave estrangeira sem índice | `CREATE INDEX` on `loans(member_id)` | 91.6 ms | 0.3 ms | **~300x** |
| 02 | "Members with no loans" as a correlated `count(*)` · "Membros sem empréstimos" com `count(*)` correlacionado | Rewrite as `NOT EXISTS` (anti-join) · Reescrever como `NOT EXISTS` | 3,194 ms | 99.7 ms | **~32x** |
| 03 | Oldest overdue loans (only 2% of rows are open) · Empréstimos atrasados mais antigos (só 2% estão em aberto) | Partial index `ON loans (due_at) WHERE returned_at IS NULL` | 81.3 ms | 0.5 ms | **~150x** |
| 04 | `ILIKE '%word%'` over 300k titles · `ILIKE '%palavra%'` em 300 mil títulos | GIN trigram index (`pg_trgm`) | 118.8 ms | 2.0 ms | **~60x** |

Full plans are saved in [`results/`](results/) (`*_before.txt` and `*_after.txt`).
Os planos completos estão em [`results/`](results/).

## 🔍 What each scenario teaches · O que cada cenário ensina

**01 · Missing foreign-key index.** PostgreSQL does *not* index foreign keys automatically. The "before" plan is a parallel sequential scan that reads the whole table (18,678 buffers); the "after" plan is a bitmap index scan (21 buffers).
PostgreSQL *não* cria índice para chave estrangeira automaticamente. Antes: varredura sequencial na tabela toda; depois: índice.

**02 · Correlated subquery.** The `count(*)` version runs the subquery once per member (100,000 loops, ~2.3M buffer hits) *even though the index from scenario 01 exists*. `NOT EXISTS` lets the planner use a Nested Loop **Anti Join**, which can stop at the first match. Having the index is not enough: the shape of the query matters.
A versão com `count(*)` executa a subconsulta uma vez por membro (100 mil vezes), mesmo com o índice do cenário 01. O `NOT EXISTS` vira um anti-join que para no primeiro registro encontrado.

**03 · Partial index.** Only ~2% of loans are open, so an index restricted to `returned_at IS NULL` is tiny: **896 kB** instead of **43 MB** for a full index on the same column, and it returns rows already sorted by `due_at`, so `ORDER BY ... LIMIT 50` stops after reading 50 entries. The query must repeat the index predicate (`returned_at IS NULL`) for the planner to use it.
Só ~2% dos empréstimos estão em aberto, então o índice parcial é minúsculo (896 kB contra 43 MB de um índice completo) e já entrega as linhas ordenadas.

**04 · Trigram search.** A B-tree can't help with a leading wildcard (`'%word%'`). A GIN index on `gin_trgm_ops` can.
Um índice B-tree não ajuda com curinga no início (`'%palavra%'`). Um índice GIN com `gin_trgm_ops` ajuda.

## ▶️ Run it yourself · Rode você mesma

```bash
docker compose up -d                 # creates and seeds the database (~1 min on the first start)
export DATABASE_URL="postgresql://lab:lab@localhost:5432/lab"
./scripts/run.sh                     # all scenarios; or ./scripts/run.sh 03
cat results/summary.md
```

Requirements: Docker and the `psql` client. The scenarios were run against PostgreSQL 16.
Requisitos: Docker e o cliente `psql`. Os cenários foram executados no PostgreSQL 16.

📚 New to this? Start with the [docs](docs/): [Getting started](docs/GETTING_STARTED.md) · [Study guide (PT)](docs/STUDY_GUIDE.md) · [Glossary](docs/GLOSSARY.md) · [Exercises](docs/EXERCISES.md) · [Interview prep](docs/INTERVIEW_PREP.md) · [Sources](docs/SOURCES.md)
📚 Começando agora? Veja a pasta [docs](docs/).

## 🗂️ Structure · Estrutura

```
sql/                 schema and synthetic data (fixed random seed)
scenarios/NN_*/      query.sql (slow) · fix.sql or query_fixed.sql · reset.sql
scripts/run.sh       measures before/after and writes results/
results/             execution plans + summary.md
```

## ⚠️ Honest notes · Notas honestas

- Timings are from a warm cache (everything fits in memory). On a cold cache, the sequential scans in the "before" runs would be even slower.
- Indexes are not free: they cost disk space and slow down writes. In production, create them with `CREATE INDEX CONCURRENTLY` and check that they are actually used (`pg_stat_user_indexes`).
- Always **measure before optimizing**: the first step in each scenario is reading the plan, not guessing.

---

Made by [Ketleen](https://github.com/KetleenAnne) · ☕ + 🐱 (Gael supervised)
