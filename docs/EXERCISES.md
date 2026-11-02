# 🧪 Exercises · Exercícios

Do each one with the lab running ([GETTING_STARTED.md](GETTING_STARTED.md)). Write your prediction **before** you run it; the learning is in the surprise.
Faça com o laboratório rodando. Escreva sua previsão **antes** de rodar; o aprendizado está na surpresa.

Shortcut used below · Atalho usado abaixo:
```bash
explain() { (echo "EXPLAIN (ANALYZE, BUFFERS)"; cat "$1") | psql "$DATABASE_URL"; }
```

1. **Read before fixing.** Run `explain scenarios/01_missing_fk_index/query.sql` after `reset.sql`. Find `Seq Scan`, `Buffers`, `Execution Time`. How many pages were read to return a handful of rows?
2. **Prove the FK is not indexed.** In `psql`, run `\d loans` and `\di+`. Which indexes exist? Then apply scenario 01's `fix.sql` and run `\d loans` again.
3. **Different member.** Change `4242` to a member with many loans and one with none. Does the plan change? Why might the planner prefer a different scan for many rows?
4. **Break scenario 03's index.** With the partial index in place, remove `AND`/`returned_at IS NULL` from the query. Is `loans_open_due_idx` still used? Explain why.
5. **Index size.** Create a *full* index `CREATE INDEX tmp_full ON loans (due_at);` and compare with the partial one using `\di+`. Drop `tmp_full` afterwards.
6. **Scenario 02 without the index.** `reset.sql`, then run `query_fixed.sql` (no `setup.sql`). Is `NOT EXISTS` still fast? What does that tell you about queries vs indexes working together?
7. **Trigram limits.** After scenario 04's fix, search `ILIKE '%a%'` and `ILIKE '%lighthouse%'`. Compare plans. Why does a 1-letter pattern behave differently?
8. **Cost of an index.** Time `INSERT`s of many rows with and without `loans_member_id_idx` (use `\timing` and `INSERT ... SELECT ... FROM generate_series(1, 100000)` inside `BEGIN; ... ROLLBACK;`). How much slower are writes?
9. **Stale statistics.** Run `explain` on any scenario query and compare estimated `rows=` with actual `rows=`. Then run `ANALYZE loans;` and compare again. When do they diverge most? (Tip: right after a big load or delete.)
10. **Your own scenario.** Invent a 5th slow query on this schema, document the symptom, fix, and measure. Add it as `scenarios/05_*` with `query.sql`, `fix.sql`, `reset.sql`.

Hints for the harder ones · Dicas: (4) a partial index is only used when the planner can prove the query's `WHERE` implies the index predicate. (7) a pattern needs enough characters to produce trigrams.
