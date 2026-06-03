# exa-jaffle-shop

**[Jaffle Shop](https://github.com/dbt-labs/jaffle-shop)** is the canonical dbt sandbox project maintained by dbt Labs. It models a fictional restaurant that sells jaffles (toasted sandwich pies) and covers the full dbt workflow: raw CSV seeds → staging views → analytics-ready mart tables. The domain spans customers, orders, order items, products, supplies, and store locations — small enough to understand in an afternoon, realistic enough to exercise dbt's core features.

Using dbt with Exasol combines data orchestration with the high performance and scalability of an Exasol database. You can test this workflow with your existing Exasol database or set up a free Exasol instance via the [Exasol SaaS free trial](https://cloud.exasol.com) or the [Docker image](https://hub.docker.com/r/exasol/docker-db). This repository ports Jaffle Shop to **[Exasol](https://www.exasol.com)** and validates it against both dbt engines:

| Engine | Version | Transport | Status |
|--------|---------|-----------|--------|
| [dbt-fusion](https://github.com/dbt-labs/dbt-fusion) | 2.0.0-preview.183 | Rust / ADBC ([exarrow-rs](https://github.com/exasol-labs/exarrow-rs)) | **PASS** (6 seeds · 9 models) |
| [dbt-core v2](https://github.com/dbt-labs/dbt-core) | 2.0.0-alpha.1 | Rust / ADBC ([exarrow-rs](https://github.com/exasol-labs/exarrow-rs)) | **PASS** (6 seeds · 9 models) |
| [dbt-core 1.x](https://github.com/dbt-labs/dbt-core) + [dbt-exasol](https://alligatorcompany.gitlab.io/dbt-exasol) | 1.11.11 / 1.10.6 | Python / [pyexasol](https://github.com/exasol/pyexasol) | **PASS** (6 seeds · 9 models) |

You can run Exasol locally for free via the [Docker image](https://hub.docker.com/r/exasol/docker-db) or sign up for a [free SaaS trial](https://cloud.exasol.com).

---

## Quick Start

### One-shot: all three engines

```bash
# 1. Start Exasol
docker compose up -d && sleep 30

# 2. Install engines (first time only)

# Engine: dbt-fusion
curl -fsSL https://public.cdn.getdbt.com/fs/install/install.sh | sh -s -- --update 

# Engine: dbt-core v1 (Python)
python3 -m venv .venv    && .venv/bin/pip install    "dbt-core==1.11.11" "dbt-exasol==1.10.6"

# Engine: dbt-core v2 (Rust)
python3 -m venv .venv-v2 && .venv-v2/bin/pip install "dbt-core==2.0.0-alpha.1"

# Exasol ADBC driver (exarrow-rs)
curl -LsSf https://dbc.columnar.tech/install.sh | sh && dbc install exasol

# 3. Run
make all
```

`make all` calls `make init` (creates schemas and seed tables with correct DDL via
[exapump](https://github.com/exasol-labs/exapump)), then runs all three engines in turn.

### Individual engines

```bash
make init         # always run first for Rust engines (idempotent)
make run-fusion   # dbt-fusion  — Rust/ADBC
make run-v2       # dbt-core v2 — Rust/ADBC
make run-python   # dbt-core 1.x — Python/pyexasol
make clean        # remove target/ and dbt_packages/
```

Override connection settings via environment variables:

```bash
EXASOL_HOST=my.exasol.cloud EXASOL_PASSWORD=secret make all
```

---

## Detailed Quick Start

### dbt-fusion

```bash
docker compose up -d && sleep 30
curl -fsSL https://public.cdn.getdbt.com/fs/install/install.sh | sh -s -- --update
curl -LsSf https://dbc.columnar.tech/install.sh | sh && dbc install exasol
source scripts/setup_fusion_env.sh   # sets LD_LIBRARY_PATH + DBT_ALLOW_EXPERIMENTAL_ADAPTERS
make init
dbt deps && dbt seed && dbt run
```

### dbt-core v2 (Rust, open-source)

dbt-core v2 and dbt-fusion share the same Rust engine and Exasol ADBC adapter.
dbt-fusion ships as a prebuilt binary; dbt-core v2 is the pip-installable open-source package.

```bash
docker compose up -d && sleep 30
python3 -m venv .venv-v2
.venv-v2/bin/pip install "dbt-core==2.0.0-alpha.1"
curl -LsSf https://dbc.columnar.tech/install.sh | sh && dbc install exasol
source scripts/setup_fusion_env.sh
make init
.venv-v2/bin/dbt deps && .venv-v2/bin/dbt seed && .venv-v2/bin/dbt run
```

### dbt-core 1.x (Python)

```bash
docker compose up -d && sleep 30
python3 -m venv .venv
.venv/bin/pip install "dbt-core==1.11.11" "dbt-exasol==1.10.6"
.venv/bin/dbt deps
.venv/bin/dbt seed --target python
.venv/bin/dbt run  --target python
```

The Python engine does not require `make init` — dbt-exasol creates schemas and tables with
correct Exasol types automatically.

---

## Configuration

`profiles.yml` is pre-configured for the Exasol Docker container. Override via environment variables:

| Variable | Default | Description |
|---|---|---|
| `EXASOL_HOST` | `localhost` | Exasol hostname |
| `EXASOL_PORT` | `8563` | Exasol port |
| `EXASOL_USER` | `sys` | Database user |
| `EXASOL_PASSWORD` | `exasol` | Password |

> **TLS note:** Exasol Docker uses a self-signed certificate. `profiles.yml` sets
> `certificate_validation: false` (Rust engines) and `validate_server_certificate: false`
> (dbt-exasol). Do not use this in production.

> **Schema casing:** Exasol stores identifiers as uppercase. `profiles.yml` uses
> `JAFFLE_SHOP` and `sources.yml` sets `quoting: identifier: false`.

---

## How `make init` works

The Rust-based engines (dbt-fusion, dbt-core v2) have two known adapter bugs that `make init`
works around:

| Bug | Symptom | Workaround |
|-----|---------|------------|
| Seed DDL emits `TEXT` type | Exasol has no `TEXT` type | `scripts/init_db.sql` pre-creates seed tables with `VARCHAR(2000000)`; `+full_refresh: false` makes dbt seed `TRUNCATE + INSERT` into them instead of `DROP + CREATE` |
| ADBC driver formats timestamps as ISO 8601 (`T` separator) | Exasol default NLS expects a space | `scripts/init_db.sql` runs `ALTER SYSTEM SET NLS_TIMESTAMP_FORMAT = 'YYYY-MM-DDTHH24:MI:SS.FF6'`; pyexasol's IMPORT FROM CSV also benefits since it passes raw CSV strings to Exasol's parser |

`make init` is idempotent — it uses `CREATE SCHEMA IF NOT EXISTS` and `CREATE OR REPLACE TABLE`.

---

## Exasol Support for dbt

| Engine | Adapter | Transport | Tested |
|--------|---------|-----------|--------|
| dbt-core 1.x | [dbt-exasol 1.10.6](https://alligatorcompany.gitlab.io/dbt-exasol) | Python / pyexasol | dbt-core 1.11.11 |
| dbt-fusion | [exarrow-rs](https://github.com/exasol-labs/exarrow-rs) (built-in) | Rust / ADBC | 2.0.0-preview.183 |
| dbt-core v2 | [exarrow-rs](https://github.com/exasol-labs/exarrow-rs) (built-in) | Rust / ADBC | 2.0.0-alpha.1 |

### dbt-fusion and dbt-core v2

Exasol support was contributed to dbt-fusion via two PRs:

| PR | Title | Merged | What it adds |
|----|-------|--------|--------------|
| [#1615](https://github.com/dbt-labs/dbt-fusion/pull/1615) | feature: exasol connector | 2026-04-28 | Core Exasol backend via [exarrow-rs](https://github.com/exasol-labs/exarrow-rs) ADBC |
| [#1645](https://github.com/dbt-labs/dbt-fusion/pull/1645) | feature/exasol-connector-follow-up | 2026-05-06 | Load strategy, naming, identifier casing, metadata |

Both are merged to main. dbt-fusion and dbt-core v2 share the same Rust engine; issue tracking
for both lives at [dbt-labs/dbt-core](https://github.com/dbt-labs/dbt-core). The adapter is
compiled into the binary behind the `DBT_ALLOW_EXPERIMENTAL_ADAPTERS` gate
(`scripts/setup_fusion_env.sh` sets this automatically).

---

## Exasol SQL Compatibility Notes

Four issues were fixed relative to the upstream jaffle-shop SQL:

| Issue | Fix |
|---|---|
| `source` is a reserved word | Renamed staging CTEs from `source` to `src` |
| `final` is a reserved word | Renamed mart CTEs from `final` to `mart` |
| CTE name matching the target table causes resolution errors | Renamed top-level mart CTEs to `base_*` |
| `USING (col)` across multiple joins is ambiguous | Replaced with explicit `ON a.col = b.col` |

Three Exasol-specific macro overrides live in `macros/exasol_overrides.sql`:

| Macro | Override | Reason |
|---|---|---|
| `dbt.type_string()` | `VARCHAR(2000000)` | Exasol has no `TEXT` type |
| `dbt.hash()` | `HASH_MD5()` | Exasol uses `HASH_MD5` not `MD5` |

---

## Project Structure

```
Makefile                      # init + run-fusion / run-v2 / run-python / all / clean
scripts/
  init_db.sql                 # NLS fix + CREATE SCHEMA + CREATE TABLE (Rust engines)
  setup_fusion_env.sh         # LD_LIBRARY_PATH + DBT_ALLOW_EXPERIMENTAL_ADAPTERS
  wait_for_exasol.sh          # exapump-based readiness probe
models/
  staging/                    # Views: rename & lightly transform raw tables
  marts/                      # Tables: join staging into analytics-ready facts/dims
macros/
  exasol_overrides.sql        # type_string, hash
seeds/
  jaffle-data/                # Raw CSV data → JAFFLE_SHOP_RAW schema
```

---

## License

MIT — see [LICENSE](LICENSE).

The dbt models and seed data are derived from [dbt-labs/jaffle-shop](https://github.com/dbt-labs/jaffle-shop) (copyright dbt Labs). That repository carries no license file — consult it directly for current terms.
