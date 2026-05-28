# exa-jaffle-shop

The [jaffle-shop](https://github.com/dbt-labs/jaffle-shop) demo project running on **Exasol** via **dbt-fusion** — the new Rust-powered dbt engine with native ADBC driver support.

This is a starter project that proves end-to-end dbt-fusion compatibility with Exasol: seeds load raw data, 6 staging views transform it, and 3 mart tables join everything together.

## Exasol Support in dbt-fusion

Exasol support was contributed to [dbt-labs/dbt-fusion](https://github.com/dbt-labs/dbt-fusion) via two PRs:

| PR | Title | Merged | Key commits | What it adds |
|----|-------|--------|-------------|--------------|
| [#1615](https://github.com/dbt-labs/dbt-fusion/pull/1615) | feature: exasol connector | 2026-04-28 | `193250aa` | Core Exasol backend via [exarrow-rs](https://github.com/exasol-labs/exarrow-rs) ADBC driver; authentication, adapter, schema, init, df-providers |
| [#1645](https://github.com/dbt-labs/dbt-fusion/pull/1645) | feature/exasol-connector-follow-up | 2026-05-06 | `4ae5c72f` | System Load Strategy, Naming Strategy, identifier casing, metadata support |

The ADBC driver itself lives at [exasol-labs/exarrow-rs](https://github.com/exasol-labs/exarrow-rs), a Rust implementation of the Arrow Database Connectivity interface for Exasol, originally created by [@marconae](https://github.com/marconae).

## Quick Start

```bash
docker compose up -d && sleep 30 && dbt deps && dbt seed && dbt run
```

This starts Exasol, waits for it to be ready, installs packages, seeds the raw data, and runs all 9 models.

## Prerequisites

### 1. Docker

Any recent Docker with Compose V2. The Exasol container requires `--privileged` mode.

### 2. dbt-fusion CLI

```bash
curl -fsSL https://public.cdn.getdbt.com/fs/install/install.sh | sh -s -- --update
```

Verify: `dbt --version`

### 3. Exasol ADBC driver

```bash
dbc install exasol
```

`dbc` is the ADBC driver manager. If you don't have it yet:

```bash
curl -LsSf https://dbc.columnar.tech/install.sh | sh
```

## Configuration

`profiles.yml` is included in this repository and pre-configured for the Exasol Docker container with default credentials. Override via environment variables if needed:

| Variable | Default | Description |
|---|---|---|
| `EXASOL_HOST` | `localhost` | Exasol hostname |
| `EXASOL_PORT` | `8563` | Exasol port |
| `EXASOL_USER` | `sys` | Database user |
| `EXASOL_PASSWORD` | `exasol` | Password |

> **Note on TLS**: Exasol Docker uses a self-signed certificate. `profiles.yml` sets `certificate_validation: false` to allow connections without a trusted CA chain. Do not use this in production.

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

# Pretty table output
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
