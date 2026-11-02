# 🔗 Sources · Fontes

**EN** · Where the technical claims in these docs come from. Each link below was opened and checked while writing; the note says what it confirms and which PostgreSQL version the page I opened belongs to. Behaviour described here is long-standing, but **always check the page for your own version** (the version switcher is at the top of every PostgreSQL docs page).
**PT** · De onde vêm as afirmações técnicas destes documentos. Cada link foi aberto e conferido; a nota diz o que ele confirma e de qual versão do PostgreSQL é a página que abri. Confira sempre a página da **sua** versão.

## Official PostgreSQL documentation · Documentação oficial

| Topic · Assunto | Source · Fonte | What it confirms · O que confirma |
|---|---|---|
| `EXPLAIN`, `ANALYZE`, `BUFFERS` | [EXPLAIN (docs v12)](https://www.postgresql.org/docs/12/sql-explain.html) | `ANALYZE` runs the command and shows actual times; `BUFFERS` shows buffer usage and only works together with `ANALYZE`. |
| Partial indexes (scenario 03) | [11.8. Partial Indexes (docs v16)](https://postgresql.org/docs/16/indexes-partial.html) | "A partial index is an index built over a subset of a table; the subset is defined by a conditional expression." |
| Trigram search (scenario 04) | [F.32. pg_trgm (docs v10)](https://www.postgresql.org/docs/10/pgtrgm.html) | GIN/GiST trigram indexes support `LIKE`/`ILIKE`, and "the search string need not be left-anchored" (unlike B-tree). A pattern with no extractable trigrams degrades to a full-index scan. |
| `CREATE INDEX CONCURRENTLY` | [CREATE INDEX (docs v9.3)](https://www.postgresql.org/docs/9.3/sql-createindex.html) | Builds the index without locks that block inserts/updates/deletes (a normal build blocks writes, not reads); takes longer; cannot run inside a transaction block. |

The pages above are older versions than the PostgreSQL 16 used in the lab because those were the ones I could open; the options and behaviours quoted exist in 16 as well, but verify on the 16 pages if you quote them.
As páginas acima são de versões mais antigas que o PostgreSQL 16 do laboratório, porque foram as que consegui abrir; confira nas páginas da versão 16 se for citar.

## Learning material · Material de estudo

| Source · Fonte | Note · Observação |
|---|---|
| [Use The Index, Luke](https://use-the-index-luke.com/) | Free online tutorial on SQL indexing and tuning by Markus Winand; covers PostgreSQL among other databases. The same author's book is *SQL Performance Explained*. · Tutorial gratuito sobre índices e tuning de SQL, de Markus Winand; cobre PostgreSQL entre outros bancos. O livro do mesmo autor é *SQL Performance Explained*. |

## Foreign keys are not indexed automatically (scenario 01) · Chave estrangeira não é indexada sozinha

- Verified in a third-party guide: [PostgreSQL Indexes, PostGraphile docs](https://postgraphile.org/postgraphile/5/postgresql-indexes) — "PostgreSQL does NOT automatically create an index on the referencing column(s)."
- I could not open the equivalent page in the official docs, so it is **not cited as official**. You can see it yourself in the lab: after `docker compose up`, run `\d loans` in `psql` and notice there is no index on `member_id`.
- Eu não consegui abrir a página equivalente da documentação oficial, então ela **não** é citada como oficial. Você mesma comprova no laboratório com `\d loans`.

## What is the lab's own measurement · O que é medição do próprio laboratório

Timings, buffer counts, index sizes (896 kB vs 43 MB) and the speed-ups come from running this repository (see [`results/`](../results/)), not from any external source. They depend on hardware and cache state.
Tempos, contagem de buffers, tamanhos de índice e ganhos vêm da execução deste repositório, não de fonte externa.
