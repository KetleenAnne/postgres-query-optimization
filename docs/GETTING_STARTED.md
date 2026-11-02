# 🚀 Getting Started · Primeiros passos

**EN** · Everything you need to run the lab, run a scenario by hand, and fix common problems.
**PT** · Tudo para rodar o laboratório, rodar um cenário na mão e resolver problemas comuns.

## 1. Requirements · Requisitos

| Tool · Ferramenta | Why · Para quê | Check · Conferir |
|---|---|---|
| Docker (with Compose) | Runs PostgreSQL 16 · Roda o PostgreSQL 16 | `docker compose version` |
| `psql` client | Talks to the database · Conversa com o banco | `psql --version` |
| Bash | Runs `scripts/run.sh` · Roda o script | Linux, macOS or WSL on Windows |

Installing `psql` only (no server) · Instalando só o `psql`:
- Ubuntu/Debian/WSL: `sudo apt install postgresql-client`
- macOS: `brew install libpq` (then add it to your `PATH`, as brew tells you)

## 2. Start the database · Subir o banco

```bash
docker compose up -d
docker compose logs -f db      # wait for "database system is ready to accept connections"
```

The first start creates the tables and inserts ~2.4 million synthetic rows (≈1 minute). Data lives inside the container, so nothing is installed on your machine besides the image.
A primeira subida cria as tabelas e insere ~2,4 milhões de linhas sintéticas (≈1 minuto).

```bash
export DATABASE_URL="postgresql://lab:lab@localhost:5432/lab"
psql "$DATABASE_URL" -c "SELECT count(*) FROM loans;"      # expect 2000000
```

## 3. Run everything · Rodar tudo

```bash
./scripts/run.sh          # all four scenarios · os quatro cenários
./scripts/run.sh 03       # only scenario 03 · só o cenário 03
RUNS=10 ./scripts/run.sh  # more runs per measurement · mais execuções por medição
cat results/summary.md
```

For each scenario the script resets the indexes, measures the query 5 times (after a warm-up) and keeps the **median**, applies the fix, measures again and saves both plans in `results/`.
Para cada cenário o script limpa os índices, mede 5 vezes (após aquecimento) e guarda a **mediana**, aplica a correção, mede de novo e salva os dois planos em `results/`.

## 4. Run one scenario by hand · Rodar um cenário na mão

This is the best way to learn. Example with scenario 01 · Este é o melhor jeito de aprender. Exemplo com o cenário 01:

```bash
S=scenarios/01_missing_fk_index

psql "$DATABASE_URL" -f $S/reset.sql                                   # 1. start clean · começar limpo
(echo "EXPLAIN (ANALYZE, BUFFERS)"; cat $S/query.sql) | psql "$DATABASE_URL"   # 2. BEFORE · antes
psql "$DATABASE_URL" -f $S/fix.sql                                     # 3. apply the fix · aplicar a correção
psql "$DATABASE_URL" -c "ANALYZE loans"                                # 4. refresh statistics · atualizar estatísticas
(echo "EXPLAIN (ANALYZE, BUFFERS)"; cat $S/query.sql) | psql "$DATABASE_URL"   # 5. AFTER · depois
```

Scenario 02 is special: its "before" needs the index from scenario 01, so run `psql "$DATABASE_URL" -f scenarios/02_correlated_subquery/setup.sql` first, then compare `query.sql` with `query_fixed.sql` (there is no `fix.sql`: the fix is the rewritten query).
O cenário 02 é especial: o "antes" precisa do índice do cenário 01, então rode `setup.sql` antes e compare `query.sql` com `query_fixed.sql` (a correção é a consulta reescrita).

Tip · Dica: inside `psql`, `\timing on` shows the time of every command, `\d loans` shows the table and its indexes, `\di+` lists indexes with their size.

## 5. Clean up · Limpar

```bash
docker compose down        # stop (keeps the data) · parar (mantém os dados)
docker compose down -v     # stop and delete the data · parar e apagar os dados
```

## 6. Troubleshooting · Problemas comuns

| Problem · Problema | Fix · Solução |
|---|---|
| `port 5432 is already allocated` | Another PostgreSQL is running. Stop it, or change `"5432:5432"` to `"5433:5432"` in `docker-compose.yml` and use `localhost:5433` in `DATABASE_URL`. |
| `connection refused` right after `up` | The database is still seeding. Wait for the "ready to accept connections" log line. |
| `psql: command not found` | Install the client (section 1). |
| `Permission denied: ./scripts/run.sh` | `chmod +x scripts/run.sh` |
| `password authentication failed` | The volume was created with other credentials. `docker compose down -v` and `up -d` again. |
| Times are very different from the README | Normal: other hardware. Compare the **ratios** and the **plan shapes**, not the milliseconds. |
| Plan did not change after the fix | Run `ANALYZE` (the script does it) and check that the query text still matches the index (see scenario 03). |
| Changed the seed and nothing happened | Init scripts only run on an empty volume: `docker compose down -v && docker compose up -d`. |
