<a id="top"></a>

# 🐘 PostgreSQL Query Optimization

🇬🇧 **English** · [🇧🇷 Português](README.pt-BR.md)

Four slow queries, each one diagnosed with `EXPLAIN (ANALYZE, BUFFERS)`, fixed, and measured again. Every fix comes with the plan before and after, so you can see *why* it got faster, not just that it did.

> 🧪 100% synthetic data (a tiny "public library": 100k members, 300k books, 2M loans). No company code, no real data.

## 📑 Table of contents

- [📊 Results](#results)
- [🔍 What each scenario teaches](#scenarios)
  - [01 · Missing foreign-key index](#scenario-01)
  - [02 · Correlated subquery](#scenario-02)
  - [03 · Partial index](#scenario-03)
  - [04 · Trigram search](#scenario-04)
- [▶️ Run it yourself](#run)
- [📚 Docs and study material](#docs)
- [🗂️ Project structure](#structure)
- [⚠️ Honest notes](#notes)

<a id="results"></a>

## Results

Median of 5 runs after a warm-up, PostgreSQL 16, warm cache, small local machine. Your absolute numbers will differ; the **ratios and the plans** are what matter.

| # | Problem | Fix | Before | After | Speed-up |
|---|---|---|---:|---:|---:|
| [01](#scenario-01) | Filtering by a foreign key without an index | `CREATE INDEX` on `loans(member_id)` | 91.6 ms | 0.3 ms | **~300x** |
| [02](#scenario-02) | "Members with no loans" written as a correlated `count(*)` | Rewrite as `NOT EXISTS` (anti-join) | 3,194 ms | 99.7 ms | **~32x** |
| [03](#scenario-03) | Oldest overdue loans (only 2% of rows are open) | Partial index `ON loans (due_at) WHERE returned_at IS NULL` | 81.3 ms | 0.5 ms | **~150x** |
| [04](#scenario-04) | `ILIKE '%word%'` over 300k titles | GIN trigram index (`pg_trgm`) | 118.8 ms | 2.0 ms | **~60x** |

Full plans are saved in [`results/`](results/) (`*_before.txt` and `*_after.txt`).

<sub>[⬆ back to top](#top)</sub>

<a id="scenarios"></a>

## What each scenario teaches

<a id="scenario-01"></a>

### 01 · Missing foreign-key index

```sql
SELECT count(*), max(loaned_at) FROM loans WHERE member_id = 4242;
-- fix
CREATE INDEX loans_member_id_idx ON loans (member_id);
```

PostgreSQL does *not* index foreign keys automatically. The "before" plan is a parallel sequential scan that reads the whole table (18,678 buffers) to return a handful of rows; the "after" plan is a bitmap index scan (21 buffers).

**Takeaway:** filtering or joining by a column on a big table? Ask "is there an index on it?"

<a id="scenario-02"></a>

### 02 · Correlated subquery

```sql
-- slow: one count per member
SELECT count(*) FROM members m
WHERE (SELECT count(*) FROM loans l WHERE l.member_id = m.id) = 0;
-- fast: same question as an anti-join
SELECT count(*) FROM members m
WHERE NOT EXISTS (SELECT 1 FROM loans l WHERE l.member_id = m.id);
```

The `count(*)` version runs the subquery once per member (100,000 loops, ~2.3M buffer hits) *even though the index from scenario 01 exists*. `NOT EXISTS` lets the planner use a Nested Loop **Anti Join**, which can stop at the first match.

**Takeaway:** having the index is not enough: the shape of the query matters.

<a id="scenario-03"></a>

### 03 · Partial index

```sql
CREATE INDEX loans_open_due_idx ON loans (due_at) WHERE returned_at IS NULL;
```

Only ~2% of loans are open, so an index restricted to `returned_at IS NULL` is tiny: **896 kB** instead of **43 MB** for a full index on the same column. It also returns rows already sorted by `due_at`, so `ORDER BY ... LIMIT 50` stops after reading 50 entries. The query must repeat the index predicate (`returned_at IS NULL`) for the planner to use it.

**Takeaway:** for a small "hot" subset (pending, active, unprocessed), a partial index is smaller, faster and cheaper to maintain.

<a id="scenario-04"></a>

### 04 · Trigram search

```sql
CREATE INDEX books_title_trgm_idx ON books USING gin (title gin_trgm_ops);
```

A B-tree can't help with a leading wildcard (`'%word%'`). A GIN index with `gin_trgm_ops` (extension `pg_trgm`) can, because it indexes 3-character pieces of the text.

**Takeaway:** "contains" search over large text → trigram + GIN.

<sub>[⬆ back to top](#top)</sub>

<a id="run"></a>

## Run it yourself

```bash
docker compose up -d                 # creates and seeds the database (~1 min on the first start)
export DATABASE_URL="postgresql://lab:lab@localhost:5432/lab"
./scripts/run.sh                     # all scenarios; or ./scripts/run.sh 03
cat results/summary.md
```

Requirements: Docker and the `psql` client. The scenarios were run against PostgreSQL 16. To run a scenario step by step and fix common problems, see [Getting started](docs/GETTING_STARTED.md).

<sub>[⬆ back to top](#top)</sub>

<a id="docs"></a>

## Docs and study material

| Doc | What it is |
|---|---|
| [Getting started](docs/GETTING_STARTED.md) | Install, run, run by hand, troubleshoot |
| [Study guide](docs/STUDY_GUIDE.md) | Lessons per scenario + how to read `EXPLAIN` (Portuguese) |
| [Glossary](docs/GLOSSARY.md) | Every term in plain words |
| [Exercises](docs/EXERCISES.md) | Break it, fix it, measure it |
| [Interview prep](docs/INTERVIEW_PREP.md) | Questions an interviewer may ask about this project |
| [Sources](docs/SOURCES.md) | Verified sources for the technical claims |

<a id="structure"></a>

## Project structure

```
sql/                 schema and synthetic data (fixed random seed)
scenarios/NN_*/      query.sql (slow) · fix.sql or query_fixed.sql · reset.sql
scripts/run.sh       measures before/after and writes results/
results/             execution plans + summary.md
docs/                guides, glossary, exercises, sources
```

<a id="notes"></a>

## Honest notes

- Timings are from a warm cache (everything fits in memory). On a cold cache, the sequential scans in the "before" runs would be even slower.
- Indexes are not free: they cost disk space and slow down writes. In production, create them with `CREATE INDEX CONCURRENTLY` and check that they are actually used (`pg_stat_user_indexes`).
- Always **measure before optimizing**: the first step in each scenario is reading the plan, not guessing.

---

Made by [Ketleen](https://github.com/KetleenAnne) · ☕ + 🐱 (Gael supervised)
