# 🎤 Interview Prep · Preparação para entrevista

> Honest framing: this is a **learning lab on synthetic data**, not production work. Say so. Interviewers value "I built this to learn X and measured it" far more than inflated claims. For real production stories, use your own experience (without confidential details).
> Enquadramento honesto: este é um **laboratório de estudo com dados sintéticos**, não trabalho de produção. Diga isso. Para histórias de produção, use sua experiência real (sem detalhes confidenciais).

## 30-second pitch · Pitch de 30 segundos

**EN** — "I built a small PostgreSQL lab with 100k members, 300k books and 2 million loans. It has four slow queries, each diagnosed with `EXPLAIN (ANALYZE, BUFFERS)`, fixed with an index or a rewrite, and measured again using the median of five runs. The gains ranged from about 32x to 300x, and the repo explains why each fix works and what it costs."

**PT** — "Montei um laboratório de PostgreSQL com 100 mil membros, 300 mil livros e 2 milhões de empréstimos. São quatro consultas lentas, cada uma diagnosticada com `EXPLAIN (ANALYZE, BUFFERS)`, corrigida com índice ou reescrita e medida de novo pela mediana de cinco execuções. Os ganhos ficaram entre ~32x e ~300x, e o repositório explica por que cada correção funciona e o que ela custa."

## Questions and answer outlines · Perguntas e roteiros de resposta

### 1. "How do you approach a slow query?" · "Como você investiga uma query lenta?"
- **Measure first:** `EXPLAIN (ANALYZE, BUFFERS)`, not guessing.
- **Find the bottleneck node:** big `Buffers`, high `loops`, `Seq Scan` returning few rows, estimates far from actual.
- **Change one thing**, re-measure, keep the plans before/after.
- Example from the lab: scenario 01, 18,678 buffers → 21.

### 2. "Does PostgreSQL index foreign keys automatically?" · "O PostgreSQL indexa chaves estrangeiras sozinho?"
- No. The referenced side (a primary key) is indexed; the referencing column is not. You verify with `\d table`.
- Lab: filtering `loans` by `member_id` did a parallel Seq Scan until the index was created.
- Trade-off: indexes cost disk and write speed. Index FKs you filter/join on.

### 3. "Why was the `count(*) = 0` version slow even with the index?" · "Por que a versão com `count(*) = 0` era lenta mesmo com índice?"
- Correlated subquery: ran once per member (`loops=100000`, ~2.3M buffers).
- `NOT EXISTS` becomes an Anti Join that stops at the first match.
- Message: *an index helps each lookup, but doesn't change how many lookups you make.*

### 4. "What is a partial index and when would you use it?" · "O que é índice parcial e quando usar?"
- An index over a subset of rows (`WHERE returned_at IS NULL`).
- Use for small "hot" subsets: pending, active, unprocessed.
- Lab: 896 kB vs 43 MB, and `ORDER BY ... LIMIT 50` stops after 50 entries.
- Caveat: the query must imply the index predicate.

### 5. "How do you speed up `LIKE '%text%'`?" · "Como acelerar `LIKE '%texto%'`?"
- B-tree can't (not left-anchored). Use `pg_trgm` + GIN (`gin_trgm_ops`).
- Lab: ~118 ms → ~2 ms.
- Caveats: bigger index, slower writes, very short patterns degrade; for linguistic search consider full-text search.

### 6. "What are the downsides of adding indexes?" · "Quais os contras de criar índices?"
- Disk space, slower `INSERT/UPDATE/DELETE`, more maintenance (vacuum), planner choices.
- In production: `CREATE INDEX CONCURRENTLY` avoids blocking writes (takes longer, can't run in a transaction block).

### 7. "How do you know your benchmark is trustworthy?" · "Como saber se seu benchmark é confiável?"
- Fixed seed for repeatable data, warm-up, median of 5 runs, plans saved in `results/`.
- Known limits (say them!): synthetic data, warm cache, single small machine; compare ratios and plan shapes, not absolute milliseconds.

### 8. "What would you do differently / next?" · "O que você faria depois?"
- Cold-cache runs, more data skew, compare with `pg_stat_statements`, try covering indexes (`INCLUDE`), and partitioning as a separate lab.

## STAR template for your own real stories · Modelo STAR para suas histórias reais

| | Prompt | Your notes · Suas notas |
|---|---|---|
| **S**ituation | What was slow/broken, how big was the data? | |
| **T**ask | What were you responsible for? | |
| **A**ction | How did you measure, what did you change, why that and not something else? | |
| **R**esult | Numbers (before/after), what you learned, what you'd do next. | |

Tip: practise out loud, 90 seconds per answer. · Dica: treine em voz alta, 90 segundos por resposta.
