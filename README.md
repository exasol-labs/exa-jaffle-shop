# exa-jaffle-shop

**[Jaffle Shop](https://github.com/dbt-labs/jaffle-shop)** is the canonical dbt sandbox project maintained by dbt Labs. It models a fictional restaurant that sells jaffles (toasted sandwich pies) and covers the full dbt workflow: raw CSV seeds → staging views → analytics-ready mart tables. The domain spans customers, orders, order items, products, supplies, and store locations — small enough to understand in an afternoon, realistic enough to exercise dbt's core features.

Using dbt with Exasol combines data orchestration with the high performance and scalability of an Exasol database. You can test this workflow with your existing Exasol database or set up a free Exasol instance via the [Exasol SaaS free trial](https://cloud.exasol.com) or the [Docker image](https://hub.docker.com/r/exasol/docker-db). This repository ports Jaffle Shop to **[Exasol](https://www.exasol.com)** and validates it against both dbt engines:

| Engine | Transport | Status |
|--------|-----------|--------|
| [dbt-fusion](https://github.com/dbt-labs/dbt-fusion) | Rust / ADBC ([exarrow-rs](https://github.com/exasol-labs/exarrow-rs)) | **PASS** (fix branch) |
| [dbt-core](https://github.com/dbt-labs/dbt-core) + [dbt-exasol](https://alligatorcompany.gitlab.io/dbt-exasol) | Python / pyexasol | **PASS** |

Seeds load raw data, 6 staging views transform it, and 3 mart tables join everything together. PASS=9 on both engines.

## Quick Start

### dbt-fusion

> **Note:** The current release binary has a known seed issue — see [dbt-fusion Known Issues](#dbt-fusion-known-issues).

```bash
# 1. Start Exasol
docker compose up -d && sleep 30

# 2. Install dbt-fusion
curl -fsSL https://public.cdn.getdbt.com/fs/install/install.sh | sh -s -- --update

# 3. Install the Exasol ADBC driver
curl -LsSf https://dbc.columnar.tech/install.sh | sh
dbc install exasol

# 4. Set environment (detects Linux / macOS / Windows automatically)
source scripts/setup_fusion_env.sh

# 5. Run
dbt deps
dbt seed
dbt run
```

The script sets `DBT_ALLOW_EXPERIMENTAL_ADAPTERS=1` and the correct library path variable
for your OS (`LD_LIBRARY_PATH` on Linux, `DYLD_LIBRARY_PATH` on macOS, `PATH` on Windows).
Add `source /path/to/exa-jaffle-shop/scripts/setup_fusion_env.sh` to your shell profile
to make it permanent.

### dbt-core (Python)

```bash
# 1. Start Exasol
docker compose up -d && sleep 30

# 2. Install dbt-exasol (pulls dbt-core and pyexasol automatically)
python3 -m venv .venv
.venv/bin/pip install dbt-exasol

# 3. Run
.venv/bin/dbt deps
.venv/bin/dbt seed --target python
.venv/bin/dbt run --target python
```

## Configuration

`profiles.yml` is included in the repository and pre-configured for the Exasol Docker container with default credentials. Override via environment variables:

| Variable | Default | Description |
|---|---|---|
| `EXASOL_HOST` | `localhost` | Exasol hostname |
| `EXASOL_PORT` | `8563` | Exasol port |
| `EXASOL_USER` | `sys` | Database user |
| `EXASOL_PASSWORD` | `exasol` | Password |

> **TLS note:** Exasol Docker uses a self-signed certificate. `profiles.yml` sets `certificate_validation: false` (dbt-fusion) and `validate_server_certificate: false` (dbt-exasol). Do not use this in production.

> **Schema casing:** Exasol stores identifiers as uppercase. `profiles.yml` uses uppercase `JAFFLE_SHOP` and `sources.yml` sets `quoting: identifier: false` so dbt passes identifiers unquoted (case-insensitive).

## dbt-fusion Known Issues

The released binary `2.0.0-preview.178` panics during `dbt seed`:

```
panic: not yet implemented
  at crates/sdf-adapter/src/sql_types.rs:207
```

Tracked in [issue #2231](https://github.com/dbt-labs/dbt-fusion/issues/2231); fix submitted in [PR #2232](https://github.com/dbt-labs/dbt-fusion/pull/2232). Once merged and a new preview is released, the Quick Start steps above will work as-is.


## Exasol Support for dbt

| Engine | Adapter | Transport | Tested version |
|--------|---------|-----------|----------------|
| [dbt-core](https://github.com/dbt-labs/dbt-core) | [dbt-exasol](https://alligatorcompany.gitlab.io/dbt-exasol) | Python / [pyexasol](https://github.com/exasol/pyexasol) | dbt-core 1.11.11 / dbt-exasol 1.10.6 |
| [dbt-fusion](https://github.com/dbt-labs/dbt-fusion) | [exarrow-rs](https://github.com/exasol-labs/exarrow-rs) | Rust / ADBC | fix pending on [`fix/exasol-adapt-seed-type`](https://github.com/marconae/dbt-fusion-fork/tree/fix/exasol-adapt-seed-type) |

### dbt-fusion Support

Exasol support was contributed to [dbt-labs/dbt-fusion](https://github.com/dbt-labs/dbt-fusion) via two PRs:

| PR | Title | Merged | Key commits | What it adds |
|----|-------|--------|-------------|--------------|
| [#1615](https://github.com/dbt-labs/dbt-fusion/pull/1615) | feature: exasol connector | 2026-04-28 | `82535e42` | Core Exasol backend (`Backend::Exasol`) via [exarrow-rs](https://github.com/exasol-labs/exarrow-rs) ADBC driver; authentication, adapter, schema, init, df-providers |
| [#1645](https://github.com/dbt-labs/dbt-fusion/pull/1645) | feature/exasol-connector-follow-up | 2026-05-06 | `735b508f` | System Load Strategy, Naming Strategy, identifier casing, metadata support |

Both PRs are merged into `dbt-labs/dbt-fusion` main. The Exasol adapter code is compiled into the latest binary (`2.0.0-preview.178`) but sits behind an **experimental adapter gate** controlled by `DBT_ALLOW_EXPERIMENTAL_ADAPTERS`.

```
# in crates/dbt-loader/src/load_profiles.rs
fn experimental_adapters_allowed() -> bool {
    !dbt_env::env_var_is_disabled(ALLOW_EXPERIMENTAL_ADAPTERS_ENV)
    // "DBT_ALLOW_EXPERIMENTAL_ADAPTERS"
}
```

The ADBC driver lives at [exasol-labs/exarrow-rs](https://github.com/exasol-labs/exarrow-rs), a Rust ADBC implementation for Exasol.


## Exasol SQL Compatibility Notes

Four issues were found and fixed relative to the original jaffle-shop SQL:

| Issue | Fix |
|---|---|
| `source` is a reserved word in Exasol | Renamed staging CTEs from `source` to `src` |
| `final` is a reserved word in Exasol | Renamed mart CTEs from `final` to `mart` |
| CTE names matching the table being created cause resolution errors | Renamed top-level mart CTEs to `base_*` |
| `USING (col)` across multiple joins is ambiguous | Replaced with explicit `ON a.col = b.col` |

Three Exasol-specific macro overrides are in `macros/exasol_overrides.sql`:

| Macro | Override | Reason |
|---|---|---|
| `dbt.type_string()` | `VARCHAR(2000000)` | Exasol has no `TEXT` type |
| `dbt.hash()` | uses `HASH_MD5()` | Exasol uses `HASH_MD5` not `MD5` |

## Project Structure

```
models/
  staging/         # Views: rename & lightly transform raw tables
    stg_customers.sql
    stg_orders.sql
    stg_locations.sql
    stg_order_items.sql
    stg_products.sql
    stg_supplies.sql
  marts/           # Tables: join staging models into analytics-ready facts/dims
    customers.sql
    orders.sql
    order_items.sql
macros/
  cents_to_dollars.sql
  exasol_overrides.sql    # Exasol-specific: type_string, hash
seeds/
  jaffle-data/     # Raw CSV data loaded into the raw schema
```

## License

MIT — see [LICENSE](LICENSE).

The dbt models and seed data are derived from [dbt-labs/jaffle-shop](https://github.com/dbt-labs/jaffle-shop) (copyright dbt Labs). That repository carries no license file — consult it directly for current terms.
