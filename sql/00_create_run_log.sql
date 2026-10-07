-- =========================================================
-- 00  Run log
-- One row per pipeline run. Created before anything else so
-- even a run that fails at step 1 is recorded.
-- A row left at 'running' means the process was killed
-- before it could record how it ended.
-- =========================================================

CREATE SCHEMA IF NOT EXISTS meta;

CREATE TABLE IF NOT EXISTS meta.pipeline_runs (
    run_id            INTEGER        GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    started_at        TIMESTAMPTZ    NOT NULL DEFAULT now(),
    finished_at       TIMESTAMPTZ,
    status            VARCHAR(20)    NOT NULL
        CHECK (status IN ('running', 'succeeded', 'failed')),
    failed_step       VARCHAR(100),
    error_message     TEXT,
    duration_seconds  NUMERIC(10,1),
    rows_loaded       BIGINT,
    warnings          INTEGER
);
