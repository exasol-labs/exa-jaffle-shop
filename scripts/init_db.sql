-- Initialize Exasol schemas and seed tables for exa-jaffle-shop.
--
-- Run via exapump before dbt seed on Rust-based engines (dbt-fusion, dbt-core v2):
--   exapump sql --profile ci < scripts/init_db.sql
--
-- Background: dbt-fusion's Exasol adapter maps CSV string columns to the
-- TEXT type, which Exasol does not support.  Pre-creating the tables here
-- with VARCHAR(2000000) bypasses dbt's DDL generation.  dbt seed then
-- performs a TRUNCATE + INSERT into the existing tables instead of
-- DROP + CREATE.

-- ── NLS: accept ISO 8601 timestamps (exarrow-rs sends 'T' separator) ───────
ALTER SYSTEM SET NLS_TIMESTAMP_FORMAT = 'YYYY-MM-DDTHH24:MI:SS.FF6';

-- ── Schemas ────────────────────────────────────────────────────────────────
CREATE SCHEMA IF NOT EXISTS JAFFLE_SHOP;
CREATE SCHEMA IF NOT EXISTS JAFFLE_SHOP_RAW;

-- ── Seed tables ────────────────────────────────────────────────────────────

CREATE OR REPLACE TABLE JAFFLE_SHOP_RAW.RAW_CUSTOMERS (
    ID   INTEGER,
    NAME VARCHAR(2000000)
);

CREATE OR REPLACE TABLE JAFFLE_SHOP_RAW.RAW_ITEMS (
    ID       INTEGER,
    ORDER_ID INTEGER,
    SKU      VARCHAR(2000000)
);

CREATE OR REPLACE TABLE JAFFLE_SHOP_RAW.RAW_ORDERS (
    ID          INTEGER,
    CUSTOMER    INTEGER,
    ORDERED_AT  TIMESTAMP,
    STORE_ID    INTEGER,
    SUBTOTAL    INTEGER,
    TAX_PAID    INTEGER,
    ORDER_TOTAL INTEGER
);

CREATE OR REPLACE TABLE JAFFLE_SHOP_RAW.RAW_PRODUCTS (
    SKU         VARCHAR(2000000),
    NAME        VARCHAR(2000000),
    TYPE        VARCHAR(2000000),
    PRICE       INTEGER,
    DESCRIPTION VARCHAR(2000000)
);

CREATE OR REPLACE TABLE JAFFLE_SHOP_RAW.RAW_STORES (
    ID        INTEGER,
    NAME      VARCHAR(2000000),
    OPENED_AT TIMESTAMP,
    TAX_RATE  DECIMAL(10,4)
);

CREATE OR REPLACE TABLE JAFFLE_SHOP_RAW.RAW_SUPPLIES (
    ID         INTEGER,
    NAME       VARCHAR(2000000),
    COST       INTEGER,
    PERISHABLE BOOLEAN,
    SKU        VARCHAR(2000000)
);
