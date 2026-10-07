-- =========================================================
-- 01  Schemas
-- One schema per layer. public is left unused on purpose, so
-- a query without a schema prefix fails instead of finding a
-- stray table.
-- =========================================================

CREATE SCHEMA IF NOT EXISTS raw;
CREATE SCHEMA IF NOT EXISTS staging;
CREATE SCHEMA IF NOT EXISTS analytics;

-- Marts: one table per business question, built from analytics.
-- A separate schema makes the reporting contract explicit: Power BI
-- reads marts only, and analytics can change underneath it.
CREATE SCHEMA IF NOT EXISTS marts;
