# Sandbox: dbt + PostgreSQL + Airflow 3 (Cosmos) + Elementary Data

Local sandbox to verify how **dbt** and **Elementary** handle all test types (generic, native unit tests dbt 1.8+, Elementary anomalies) and how failed tests and invalid rows are stored (`store_failures`).

## Stack

| Component | Role |
|-----------|------|
| PostgreSQL 16 | Warehouse (`demo_db`) + Airflow metadata (`airflow`) |
| dbt-postgres (dbt-core 1.11.x) | Models, seeds, generic/unit tests |
| Elementary Data 0.25.1 | Anomalies + test result tables |
| Airflow 3.2.2 + Astronomer Cosmos 1.14.0 | Orchestration `seed → run → test` |

> Version pins live in [`Dockerfile.airflow`](Dockerfile.airflow) (image source of truth) and [`requirements.txt`](requirements.txt) (local reference). Keep them in sync when bumping packages.

## Project layout

```
.
├── docker-compose.yml      # postgres + airflow (api / scheduler / dag-processor)
├── Dockerfile.airflow      # Airflow 3.2.2 + cosmos (no dbt extra) + /opt/airflow/dbt_venv
├── init.sql                # schemas + CREATE DATABASE airflow
├── profiles.yml            # dbt + elementary profiles (localhost)
├── requirements.txt
├── config/
│   └── simple_auth_passwords.json
├── dags/
│   └── dbt_cosmos_dag.py   # Cosmos DAG
├── dbt_demo/               # dbt project
│   ├── dbt_project.yml     # data_tests: store_failures + schema dbt_test_failures
│   ├── packages.yml        # elementary-data/elementary 0.25.1
│   ├── macros/             # generate_schema_name, elementary materialization override
│   ├── seeds/              # CSVs with intentional DQ issues (+ payments/shipments)
│   ├── tests/              # custom / singular tests
│   └── models/
│       ├── staging/        # stg_* + generic tests + sources
│       ├── intermediate/   # int_payments_broken (model ERROR demo)
│       └── marts/          # fct_orders, dim_customers, mart_payment_summary, mart_demo_unit_fail
└── scripts/generate_seeds.py
```

## Quick start (Docker)

```bash
# 1. AIRFLOW_UID — use 50000 (apache/airflow image user).
#    On macOS do NOT set $(id -u): UID 501 is missing from /etc/passwd in the container.
cp .env.example .env
# On Linux if needed: echo "AIRFLOW_UID=$(id -u)" > .env

# 2. Build and start
docker compose build
docker compose up -d

# 3. Wait for Postgres healthcheck and Airflow init
docker compose ps
docker compose logs airflow-init
```

- **Airflow UI**: http://localhost:8080 — login `admin` / `admin`
  - In Airflow 3, `SIMPLE_AUTH_MANAGER_USERS=admin:admin` means **username:role**, not the password.
  - Fixed password is in [`config/simple_auth_passwords.json`](config/simple_auth_passwords.json).
  - Image: **Airflow 3.2.2** (Python 3.12).
- **PostgreSQL**: `localhost:5432`, database `demo_db`, user/pass `postgres` / `postgres`

### Connect from PyCharm / DBeaver

| Parameter | Value |
|-----------|-------|
| Host | `localhost` |
| Port | `5432` |
| Database | `demo_db` |
| User | `postgres` |
| Password | `postgres` |
| Schemas | `dbt_test`, `dbt_marts`, `elementary`, `dbt_test_failures` |

## Local dbt (without Airflow)

Requires running Postgres (`docker compose up -d postgres`).

> **Python:** use **3.11–3.12** for local `dbt`. Python 3.14 is poorly compatible with dbt/mashumaro. Docker uses 3.12.

```bash
# venv (optional)
python3 -m venv .venv && source .venv/bin/activate
pip install -r requirements.txt

# Profile: copy, or point at the repo profiles dir
cp profiles.yml ~/.dbt/profiles.yml
# or:
export DBT_PROFILES_DIR="$(pwd)"

cd dbt_demo
dbt deps               # downloads elementary
dbt seed               # loads CSVs → schema dbt_test
dbt build              # run + test; BUILD is needed so downstream of error → skipped
dbt source freshness   # fills elementary.dbt_source_freshness_results
```

Step equivalent: `dbt run` + `dbt test` (prefer `dbt build` for the `skipped` matrix).

Showcase branch only: `dbt build --select tag:demo_showcase`.

### Elementary report

After `dbt seed && dbt build && dbt source freshness`.

`edr` looks for a **profile named `elementary`** in `profiles.yml` by default (a separate top-level key, not the `elementary` target under `demo_dbt`). It is already present in the root [`profiles.yml`](profiles.yml).

```bash
# from repo root — profiles-dir = "." (not "..")
edr report --project-dir dbt_demo --profiles-dir . --profile-target dev
# HTML report lands in edr_target/ (or the path printed by the CLI)
```

Profile fragment (already in `profiles.yml`):

```yaml
elementary:
  target: dev
  outputs:
    dev:
      type: postgres
      host: localhost
      user: postgres
      password: postgres
      port: 5432
      dbname: demo_db
      schema: elementary
      threads: 4
      keepalives_idle: 0
```

Or inside the Airflow container (needs a profile with `host: postgres` — generate a temporary one or edit the target; the mounted `profiles.yml` with `localhost` will not reach Postgres from the container):

```bash
docker compose exec airflow-scheduler bash -c \
  'cd /opt/airflow && /opt/airflow/dbt_venv/bin/edr report --project-dir dbt_demo --profiles-dir . --profile-target dev'
```

Prefer running `edr` **on the host** (`--profiles-dir .` at the repo root, Postgres on `localhost:5432`). Do not use `--profiles-dir ..` — edr then looks in the parent directory (`PycharmProjects`) and cannot find the profile.

## Elementary status matrix (`demo_showcase`)

A separate subgraph tagged `demo_showcase` **does not break** the main path `orders → fct_orders / dim_customers` (mart models stay `success`).

### Model Run Results

| Status | How it is produced |
|--------|--------------------|
| `success` | `stg_*`, `fct_orders`, `dim_customers`, `stg_payments`, `stg_shipments` |
| `error` | `int_payments_broken` — SQL references a nonexistent column |
| `skipped` | `mart_payment_summary` (upstream model error) + `mart_demo_unit_fail` (upstream unit FAIL) |

### Test Results (`elementary.elementary_test_results`)

| Status | How it is produced |
|--------|--------------------|
| `pass` | tests on `stg_products` / clean columns (`currency` on payments) |
| `warn` | `severity: warn` (users/orders/shipments relationships, accepted_values) |
| `fail` | source tests on `payments.raw_payments` (`not_null` amount, `accepted_values` method) + `stg_shipments.shipment_status` |
| `error` | test on `stg_demo_error_probe.nonexistent_column_for_demo_error` — column missing, DB error at runtime |

### Source freshness (`elementary.dbt_source_freshness_results`)

| Status | Source / table | How |
|--------|----------------|-----|
| `pass` | `payments.raw_payments` | fresh `_loaded_at` (generator writes “now”) |
| `warn` | `raw.raw_users` | `created_at` from 2024 + `warn_after: 3 day` |
| `error` | `ops.raw_shipments` | `_loaded_at` ~45 days ago + `error_after: 14 day` |

### Unit tests — caveat

Elementary **does not write unit tests into `elementary_test_results`** ([elementary#1709](https://github.com/elementary-data/elementary/issues/1709)).

| Unit test | Expectation | Where to look |
|-----------|-------------|---------------|
| `test_fct_orders_calculated_total` | **PASS** | dbt logs / `dbt_run_results` |
| `test_mart_demo_unit_fail_wrong_amount` | **FAIL** (intentionally wrong expect) → leaf model `mart_demo_unit_fail` **skipped** on build | dbt logs / `dbt_run_results` — **not** the Test Results UI tab |

> On the same model you cannot get both a unit FAIL and a model `success` in one `dbt build`: the unit test runs before materialize and blocks the model on fail. That is why the FAIL unit lives on leaf `mart_demo_unit_fail`, while `dim_customers` / `fct_orders` stay success.

## Intentional seed errors

| File | Error | Effect |
|------|-------|--------|
| `raw_users.csv` | duplicate `user_id=1` | `unique` warn on `stg_users.user_id` |
| `raw_users.csv` | empty `email` for `user_id=9999` | `not_null` / `unique` **warn** on `email` |
| `raw_users.csv` | old `created_at` | source freshness **warn** |
| `raw_orders.csv` | `order_status=invalid_unknown_status` | `accepted_values` warn on `stg_orders` |
| `raw_payments.csv` | empty `amount` (`payment_id=9001`) | source `not_null` **fail**; model test **warn** |
| `raw_payments.csv` | `payment_method=crypto_unknown` | source `accepted_values` **fail**; model test **warn** |
| `raw_payments.csv` | `order_id=888888` (orphan) | `relationships` **warn** |
| `raw_payments.csv` | fresh `_loaded_at` | source freshness **pass** |
| `raw_shipments.csv` | `shipment_status=lost_in_space`, orphan order | model `accepted_values` **fail** + relationships **warn** |
| `raw_shipments.csv` | stale `_loaded_at` (~45d) | source freshness **error** |
| — | `stg_demo_error_probe` nonexistent column test | test status **error** (DB) |
| — | `int_payments_broken` SQL | model run **error** → `mart_payment_summary` **skipped** |

Regenerate CSVs (including fresh payment timestamps):

```bash
python3 scripts/generate_seeds.py
```

## Test types in the project

1. **Generic / source** — `models/staging/schema.yml` + `sources.yml` (`unique`, `not_null`, `accepted_values`, `relationships`). Mix of `severity: warn` / `error` + `store_failures: true`.
2. **Native unit tests (dbt 1.8+)** — PASS on `fct_orders`, intentional FAIL on `mart_demo_unit_fail` (see caveat above).
3. **Elementary anomalies** — `models/marts/schema.yml`:
   - `elementary.volume_anomalies` on `fct_orders` (`order_date`, day bucket)
   - `elementary.dimension_anomalies` by `category` on `fct_orders`
   - `elementary.freshness_anomalies` on `updated_at`

> **Caveat:** Elementary anomalies usually need run history. On the first `dbt test` they may skip / warn / lack a baseline — expected for a sandbox. Repeat `dbt build` over several days (or shift seed dates) for a more realistic signal.

## Airflow DAG (Cosmos)

DAG id: **`dbt_cosmos_demo`**

Task order:

1. **`init_elementary_tables`** — one `DbtRunLocalOperator` with `--select package:elementary` (creates Elementary tables without ~35 separate UI tasks).
2. **`dbt_project`** (`DbtTaskGroup`) — seeds / staging / marts / tests; `RenderConfig.exclude=["package:elementary"]` so the package is not duplicated in the graph.

Config:

- `ProjectConfig` → `/opt/airflow/dbt_demo` (`install_dbt_deps=True`)
- `ExecutionConfig.dbt_executable_path` → `/opt/airflow/dbt_venv/bin/dbt` (isolated venv; Cosmos without `[dbt-postgres]` extra)
- `PostgresUserPasswordProfileMapping(conn_id="postgres_default")` — **host=`postgres`** (Docker service name), not `localhost`
- `TestBehavior.BUILD` — Cosmos renders `dbt build` semantics (models + tests together)
- `install_deps: True` on the Elementary init operator — `dbt deps` before commands

> **profiles.yml:** root file with `host: localhost` is for dbt/edr **on the host**. Inside containers Cosmos **does not** use it for run/test: the profile is built from Airflow Connection `postgres_default`. Do not run raw `dbt --profiles-dir /opt/airflow/dbt_demo` inside the container — compose mounts `profiles.yml` with `localhost`, and the Postgres connection fails with `Connection refused`.

Open the UI → DAG `dbt_cosmos_demo` → Trigger.

Failing generic tests with `severity: warn` do not fail the whole DAG, but rows are still written via `store_failures`. With `severity: error`, the test task goes red — expected.

## SQL: failed tests and invalid rows

Connect to `demo_db`.

### 1. Elementary test results (non-pass)

```sql
-- Statuses fail / warn / error (names may vary by version)
SELECT
    id,
    test_unique_id,
    model_unique_id,
    detected_at,
    status,
    test_name,
    test_short_name,
    failures,
    failed_row_count,
    test_results_description
FROM elementary.elementary_test_results
WHERE lower(status) NOT IN ('pass', 'passed')
ORDER BY detected_at DESC
LIMIT 100;
```

```sql
-- Test status summary
SELECT status, count(*) AS cnt
FROM elementary.elementary_test_results
GROUP BY 1
ORDER BY 2 DESC;
```

```sql
-- Model Run Results: success / error / skipped
SELECT status, count(*) AS cnt
FROM elementary.model_run_results
GROUP BY 1
ORDER BY 2 DESC;
```

```sql
-- Model run details (error / skip showcase)
SELECT name, status, message, generated_at
FROM elementary.model_run_results
WHERE name ILIKE '%payment%'
   OR name ILIKE '%demo%'
   OR lower(status) IN ('error', 'skipped')
ORDER BY generated_at DESC
LIMIT 50;
```

```sql
-- Source freshness: pass / warn / error
SELECT unique_id, status, max_loaded_at, snapshotted_at
FROM elementary.dbt_source_freshness_results
ORDER BY snapshotted_at DESC
LIMIT 50;
```

```sql
SELECT status, count(*) AS cnt
FROM elementary.dbt_source_freshness_results
GROUP BY 1;
```

### 2. store_failures tables (invalid rows)

With `+store_failures: true` and `+schema: dbt_test_failures`, dbt creates failed-row tables in schema `dbt_test_failures` (names are usually `<test_name>` / hash).

```sql
-- Find all tables with failed rows
SELECT table_schema, table_name
FROM information_schema.tables
WHERE table_schema IN ('dbt_test_failures', 'dbt_marts', 'dbt_test', 'elementary')
  AND (
        table_name ILIKE '%not_null%'
     OR table_name ILIKE '%unique%'
     OR table_name ILIKE '%accepted_values%'
     OR table_name ILIKE '%fail%'
     OR table_name ILIKE 'dbt_test__audit%'
  )
ORDER BY table_schema, table_name;
```

```sql
-- List all user tables in the failures schema
SELECT table_schema, table_name, table_type
FROM information_schema.tables
WHERE table_schema = 'dbt_test_failures'
ORDER BY table_name;
```

Example (table name depends on dbt version / test name — substitute from the query above):

```sql
-- Example: failed rows for not_null email / unique user_id
-- SELECT * FROM dbt_test_failures.<table_name_from_information_schema> LIMIT 50;
```

Quick listing of failure tables via `psql`:

```bash
docker compose exec postgres \
  psql -U postgres -d demo_db -c "\dt dbt_test_failures.*"
```

### 3. Check source “broken” data

```sql
-- Duplicate user_id
SELECT user_id, count(*) AS cnt
FROM dbt_test.raw_users
GROUP BY 1
HAVING count(*) > 1;

-- Empty / NULL email in staging
SELECT *
FROM dbt_test.stg_users
WHERE email IS NULL OR email = '';

-- Invalid order status
SELECT *
FROM dbt_test.stg_orders
WHERE order_status = 'invalid_unknown_status';

-- Payments DQ issues (demo_showcase)
SELECT *
FROM dbt_test.stg_payments
WHERE amount IS NULL
   OR payment_method = 'crypto_unknown'
   OR order_id = 888888;
```

### 4. Marts after a successful run

```sql
SELECT * FROM dbt_marts.fct_orders ORDER BY order_id, item_id LIMIT 20;
SELECT * FROM dbt_marts.dim_customers ORDER BY user_id LIMIT 20;
```

### 5. dbt run_results / Elementary model runs (if present)

```sql
SELECT *
FROM elementary.dbt_run_results
ORDER BY generated_at DESC
LIMIT 50;
```

```sql
SELECT *
FROM elementary.dbt_tests
ORDER BY name
LIMIT 50;
```

## Important settings

- **`store_failures: true`** — under `data_tests` in `dbt_project.yml` (and on individual tests). Invalid rows go to `dbt_test_failures`.
- **`macros/generate_schema_name.sql`** — custom schemas (`dbt_test`, `dbt_marts`, `elementary`) are used **as-is**, without a target-schema prefix.
- **Do not add `on-run-end: elementary.on_run_end()`** in `dbt_project.yml` — the Elementary package already registers that hook. Duplicating it cleans anomaly temp tables twice and fails with `relation elementary.test_*__metrics__tmp_* does not exist`.
- **`macros/elementary_materialization.sql`** — project-owned materialization override for Elementary 0.25+ (avoids the deprecated `require_explicit_package_overrides_for_builtin_materializations` flag).
- **`source_freshness_run_project_hooks: true`** — required so `dbt source freshness` still runs project hooks and fills `elementary.dbt_source_freshness_results`.

## Common issues

| Symptom | What to do |
|---------|------------|
| Port 5432 in use | Stop local Postgres or change the host port in compose |
| `docker compose build` / `ResolutionTooDeep` | Do not install `astronomer-cosmos[dbt-postgres]` in the Airflow image; keep dbt only in `dbt_venv`. Pin Cosmos + use `--constraint` from `constraints-3.2.2` |
| `ImportError: context_to_airflow_vars` | Need **astronomer-cosmos ≥ 1.10** (Airflow 3). Image uses `1.14.0` without `[dbt-postgres]` |
| `ModuleNotFoundError: No module named 'cosmos'` | Do not put `dbt_venv` at the front of `PATH` — otherwise `python` comes from the venv without cosmos. Use `DBT_EXECUTABLE` |
| Base image / Cosmos mismatch | Current image is `apache/airflow:3.2.2-python3.12` with Cosmos `1.14.0` |
| `POST /auth/token` → 401 with admin/admin | `admin:admin` in config is the role, not the password. Password is in `config/simple_auth_passwords.json` or in the api-server log (`Password for user 'admin': ...`) |
| All tasks `failed` + `state mismatch` / `Connection refused` | In Airflow 3 set `AIRFLOW__CORE__EXECUTION_API_SERVER_URL=http://airflow-api-server:8080/execution/` (not localhost) |
| `fct_orders.test` / on-run-end: `relation elementary.test_*__metrics__tmp_* does not exist` | Do not duplicate `on-run-end: elementary.on_run_end()` in `dbt_project.yml`. Also do not set `elementary: +materialized: table` |
| `init_elementary_tables` / dbt: `connection to server at "localhost" … refused` | In Docker, Postgres is the `postgres` service, not `localhost`. Use Cosmos `ProfileMapping` / `postgres_default`; do not rely on the mounted `profiles.yml` with `host: localhost` |
| `getpwuid(): uid not found: 501` / no username | Set `AIRFLOW_UID=50000` in `.env` (not `$(id -u)` on macOS), then `docker compose up -d --force-recreate` |
| `dbt deps` fail | Needs internet; retry from `dbt_demo/` |
| `edr`: `Could not find profile named 'elementary'` | Need a top-level `elementary` profile in `profiles.yml` (not a target under `demo_dbt`). Run with `--profiles-dir .` from the repo root, not `..` |
| Anomalies “nothing to judge” | Need history; re-run builds |
| Airflow DAG not visible | `docker compose logs airflow-dag-processor`; check DAG syntax |
| Permission denied on volume | Keep `AIRFLOW_UID=50000`; if needed `chmod -R a+rwX dags dbt_demo` (logs use a named volume) |
| Need a clean Postgres | `docker compose down -v` (deletes the volume!) then `up` again |

## Stop

```bash
docker compose down          # containers
docker compose down -v       # + delete Postgres data
```
