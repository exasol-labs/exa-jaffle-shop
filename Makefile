# .ONESHELL runs every recipe in a single bash session so that
# 'source'/'.' propagates exported variables across lines.
.ONESHELL:
SHELL         := /bin/bash
.SHELLFLAGS   := -euo pipefail -c

# ── Exasol connection (override via env or make invocation) ─────────────────
EXASOL_HOST     ?= localhost
EXASOL_PORT     ?= 8563
EXASOL_USER     ?= sys
EXASOL_PASSWORD ?= exasol

export EXASOL_HOST EXASOL_PORT EXASOL_USER EXASOL_PASSWORD
export DBT_PROFILES_DIR := $(CURDIR)

.PHONY: init run-fusion run-v2 run-python all clean help

help:   ## Show this help
	@grep -E '^[a-zA-Z_-]+:.*##' $(MAKEFILE_LIST) \
		| awk 'BEGIN{FS=":.*##"} {printf "  %-14s %s\n", $$1, $$2}'

## ── init ────────────────────────────────────────────────────────────────────
## Write the exapump profile from env vars, then create schemas and seed tables
## with correct Exasol DDL.  Run this once before any Rust engine target.
init:   ## Create schemas + seed tables via exapump (required for Rust engines)
	mkdir -p ~/.exapump
	printf '[ci]\nhost = "%s"\nport = %s\nuser = "%s"\npassword = "%s"\ntls = true\nvalidate_certificate = false\n' \
		'$(EXASOL_HOST)' '$(EXASOL_PORT)' '$(EXASOL_USER)' '$(EXASOL_PASSWORD)' \
		> ~/.exapump/config.toml
	exapump sql --profile ci < scripts/init_db.sql

## ── Rust engines ─────────────────────────────────────────────────────────────
## Both dbt-fusion and dbt-core v2 use the Exasol ADBC driver (exarrow-rs).
## Run 'make init' before these targets on a fresh database.

run-fusion:   ## deps + seed + run with dbt-fusion (latest binary, ADBC)
	. scripts/setup_fusion_env.sh
	dbt deps
	dbt seed
	dbt run

run-v2:   ## deps + seed + run with dbt-core v2 (.venv-v2, ADBC)
	. scripts/setup_fusion_env.sh
	.venv-v2/bin/dbt deps
	.venv-v2/bin/dbt seed
	.venv-v2/bin/dbt run

## ── Python engine ─────────────────────────────────────────────────────────
## dbt-exasol creates tables with correct types — no init required.

run-python:   ## deps + seed + run with dbt-core 1.x + dbt-exasol (.venv, Python/pyexasol)
	.venv/bin/dbt deps
	.venv/bin/dbt seed --target python
	.venv/bin/dbt run  --target python

## ── Combined ──────────────────────────────────────────────────────────────

all:   ## init + run all three engines sequentially
	$(MAKE) init
	$(MAKE) run-python
	$(MAKE) run-fusion
	$(MAKE) run-v2

clean:   ## Remove generated artifacts (target/, dbt_packages/)
	rm -rf target dbt_packages
