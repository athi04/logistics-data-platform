-- =========================================================
-- 01  Schemas
-- One schema per layer. public is left unused on purpose, so
-- a query without a schema prefix fails instead of finding a
-- stray table.
-- =========================================================

CREATE SCHEMA IF NOT EXISTS raw;
CREATE SCHEMA IF NOT EXISTS staging;
CREATE SCHEMA IF NOT EXISTS analytics;
