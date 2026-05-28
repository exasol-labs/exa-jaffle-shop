# exa-jaffle-shop

The [jaffle-shop](https://github.com/dbt-labs/jaffle-shop) demo project running on **Exasol** — adapted for the **dbt-fusion** engine with Exasol's ADBC driver.

This project proves end-to-end compatibility with Exasol: seeds load raw data, 6 staging views transform it, and 3 mart tables join everything together.

## Exasol Support in dbt-fusion

Exasol support was contributed to [dbt-labs/dbt-fusion](https://github.com/dbt-labs/dbt-fusion) via two PRs co-authored by [@marconae](https://github.com/marconae):

| PR | Title | Merged | Key commits | What it adds |
|----|-------|--------|-------------|--------------|
| [#1615](https://github.com/dbt-labs/dbt-fusion/pull/1615) | feature: exasol connector | 2026-04-28 | `193250aa` | Core Exasol backend via [exarrow-rs](https://github.com/exasol-labs/exarrow-rs) ADBC driver; authentication, adapter, schema, init, df-providers |
| [#1645](https://github.com/dbt-labs/dbt-fusion/pull/1645) | feature/exasol-connector-follow-up | 2026-05-06 | `4ae5c72f` | System Load Strategy, Naming Strategy, identifier casing, metadata support |

The ADBC driver lives at [exasol-labs/exarrow-rs](https://github.com/exasol-labs/exarrow-rs), a Rust implementation of Arrow Database Connectivity for Exasol, originally created by [@marconae](https://github.com/marconae).

> **Status (2026-05-28):** Both PRs are merged into `dbt-labs/dbt-fusion` main. The Exasol adapter is compiled into the latest binary (`2.0.0-preview.178`) but not yet unlocked for general use — the release gate will be lowered in an upcoming preview. Until then, the models run and have been validated using **dbt-core 1.11 + dbt-exasol 1.10** (the stable path).

## Quick Start

```bash
docker compose up -d && sleep 30 && dbt deps && dbt seed && dbt run
```

This starts Exasol, waits for it to be ready, installs packages, seeds the raw data, and materializes all 9 models.

## Prerequisites

### 1. Docker

Any recent Docker with Compose V2. The Exasol container requires `--privileged` mode.

### 2. dbt

**Option A — dbt-core (works today):**

```bash
pip install dbt-exasol
```

**Option B — dbt-fusion (once the release gate is lowered):**

```bash
# Install dbt-fusion CLI
curl -fsSL https://public.cdn.getdbt.com/fs/install/install.sh | sh -s -- --update

# Install the Exasol ADBC driver
curl -LsSf https://dbc.columnar.tech/install.sh | sh
dbc install exasol
```

## Configuration

`profiles.yml` is included in the repository and pre-configured for the Exasol Docker container with default credentials. Override via environment variables if needed:

| Variable | Default | Description |
|---|---|---|
| `EXASOL_HOST` | `localhost` | Exasol hostname |
| `EXASOL_PORT` | `8563` | Exasol port |
| `EXASOL_USER` | `sys` | Database user |
| `EXASOL_PASSWORD` | `exasol` | Password |

> **Note on TLS:** Exasol Docker uses a self-signed certificate. `profiles.yml` sets `certificate_validation: false` to allow connections without a trusted CA chain. Do not use this in production.

> **Note for dbt-core users:** dbt-exasol uses a `dsn: "host:port"` field instead of separate `host`/`port` fields. Swap `profiles.yml` with the dbt-core format shown in the dbt-core docs or copy the example below:
> ```yaml
> exa_jaffle_shop:
>   outputs:
>     dev:
>       type: exasol
>       dsn: "localhost:8563"
>       user: sys
>       password: exasol
>       schema: jaffle_shop
>       validate_server_certificate: false
> ```

## Proof of Working Models

Validated on 2026-05-28 against `exasol/docker-db:2025.2.1` using dbt-core 1.11.11 + dbt-exasol 1.10.6:

```
PASS=9  WARN=0  ERROR=0  SKIP=0  TOTAL=9

jaffle_shop.stg_customers      OK  (view)
jaffle_shop.stg_orders         OK  (view)
jaffle_shop.stg_locations      OK  (view)
jaffle_shop.stg_order_items    OK  (view)
jaffle_shop.stg_products       OK  (view)
jaffle_shop.stg_supplies       OK  (view)
jaffle_shop.customers          OK  (table, 10 rows)
jaffle_shop.orders             OK  (table, 15 rows)
jaffle_shop.order_items        OK  (table, 25 rows)
```

### Exasol SQL Compatibility Notes

Two reserved-word conflicts were discovered and fixed relative to the original jaffle-shop SQL:

| Issue | Fix |
|---|---|
| `source` is a reserved word in Exasol (`IMPORT FROM ... SOURCE ...`) | Renamed staging CTEs from `source` to `src` |
| `final` is a reserved word in Exasol | Renamed mart CTEs from `final` to `mart` |
| CTE names matching the table being created cause resolution errors | Renamed top-level CTEs in mart models to `base_*` |
| `USING (col)` across multiple joins is ambiguous | Replaced with explicit `ON a.col = b.col` |

## Development with exapump

[exapump](https://github.com/exasol-labs/exapump) is a single-binary CLI for Exasol that's useful during development to inspect data without a full SQL client.

Add a connection profile for the local Docker container:

```bash
exapump profile add default   # auto-configures for Docker (localhost:8563, sys/exasol, no cert check)
```

Then query away:

```bash
# Check seeded raw data
exapump sql 'SELECT COUNT(*) FROM jaffle_shop_raw.raw_orders'

# Inspect mart output
exapump sql 'SELECT * FROM jaffle_shop.customers LIMIT 5'

# Interactive REPL
exapump interactive
```

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
seeds/
  jaffle-data/     # Raw CSV data loaded into the `raw` schema
macros/
  cents_to_dollars.sql
```

## License

MIT — see [LICENSE](LICENSE).

The dbt models and seed data are derived from [dbt-labs/jaffle-shop](https://github.com/dbt-labs/jaffle-shop) (Apache 2.0).
