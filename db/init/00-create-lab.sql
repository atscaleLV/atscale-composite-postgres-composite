\set ON_ERROR_STOP on

BEGIN;

-- These credentials are intentionally simple and are only for this local lab.
DO $roles$
BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_roles WHERE rolname = 'svc_a') THEN
    CREATE ROLE svc_a
      LOGIN
      PASSWORD 'svc_a_local'
      NOSUPERUSER
      NOCREATEDB
      NOCREATEROLE
      NOREPLICATION
      NOINHERIT;
  ELSE
    ALTER ROLE svc_a PASSWORD 'svc_a_local';
  END IF;

  IF NOT EXISTS (SELECT 1 FROM pg_roles WHERE rolname = 'svc_b') THEN
    CREATE ROLE svc_b
      LOGIN
      PASSWORD 'svc_b_local'
      NOSUPERUSER
      NOCREATEDB
      NOCREATEROLE
      NOREPLICATION
      NOINHERIT;
  ELSE
    ALTER ROLE svc_b PASSWORD 'svc_b_local';
  END IF;
END
$roles$;

REVOKE ALL ON DATABASE atscale_lab FROM PUBLIC;
GRANT CONNECT ON DATABASE atscale_lab TO svc_a, svc_b;

REVOKE ALL ON SCHEMA public FROM PUBLIC;

CREATE SCHEMA IF NOT EXISTS shared AUTHORIZATION postgres;
CREATE SCHEMA IF NOT EXISTS src_a AUTHORIZATION postgres;
CREATE SCHEMA IF NOT EXISTS src_b AUTHORIZATION postgres;
CREATE SCHEMA IF NOT EXISTS agg_a AUTHORIZATION postgres;
CREATE SCHEMA IF NOT EXISTS agg_b AUTHORIZATION postgres;

REVOKE ALL ON SCHEMA shared, src_a, src_b, agg_a, agg_b FROM PUBLIC;

CREATE TABLE IF NOT EXISTS shared.dim_date (
  date_key integer PRIMARY KEY,
  date_day date NOT NULL UNIQUE,
  month_start date NOT NULL,
  month_name text NOT NULL,
  year_number integer NOT NULL
);

CREATE TABLE IF NOT EXISTS src_a.fact_sales (
  sales_row_id bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  date_key integer NOT NULL REFERENCES shared.dim_date (date_key),
  sales_amount double precision NOT NULL
);

CREATE INDEX IF NOT EXISTS fact_sales_date_key_idx
  ON src_a.fact_sales (date_key);

CREATE TABLE IF NOT EXISTS src_b.fact_budget (
  budget_row_id bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  date_key integer NOT NULL REFERENCES shared.dim_date (date_key),
  budget_amount double precision NOT NULL
);

CREATE INDEX IF NOT EXISTS fact_budget_date_key_idx
  ON src_b.fact_budget (date_key);

TRUNCATE TABLE
  src_a.fact_sales,
  src_b.fact_budget,
  shared.dim_date
RESTART IDENTITY;

INSERT INTO shared.dim_date (
  date_key,
  date_day,
  month_start,
  month_name,
  year_number
)
SELECT
  to_char(date '2025-01-01' + day_offset, 'YYYYMMDD')::integer,
  date '2025-01-01' + day_offset,
  date_trunc('month', date '2025-01-01' + day_offset)::date,
  to_char(date '2025-01-01' + day_offset, 'FMMonth'),
  extract(year FROM date '2025-01-01' + day_offset)::integer
FROM generate_series(0, 729) AS generated(day_offset);

-- Three deterministic sales rows per day make roll-up behavior observable.
INSERT INTO src_a.fact_sales (date_key, sales_amount)
SELECT
  date_key,
  (
    35.0
    + ((date_key + transaction_number * 7) % 19) * 2.5
    + transaction_number * 4.0
  )::double precision
FROM shared.dim_date
CROSS JOIN generate_series(1, 3) AS transactions(transaction_number);

-- Two deterministic budget rows per day use a different distribution.
INSERT INTO src_b.fact_budget (date_key, budget_amount)
SELECT
  date_key,
  (
    70.0
    + ((date_key + budget_line * 11) % 13) * 3.0
    + extract(month FROM date_day)::integer * 1.5
  )::double precision
FROM shared.dim_date
CROSS JOIN generate_series(1, 2) AS budget_lines(budget_line);

GRANT USAGE ON SCHEMA shared, src_a TO svc_a;
GRANT SELECT ON ALL TABLES IN SCHEMA shared, src_a TO svc_a;
GRANT ALL PRIVILEGES ON SCHEMA agg_a TO svc_a;

GRANT USAGE ON SCHEMA shared, src_b TO svc_b;
GRANT SELECT ON ALL TABLES IN SCHEMA shared, src_b TO svc_b;
GRANT ALL PRIVILEGES ON SCHEMA agg_b TO svc_b;

-- Make the separation explicit even if this script is reapplied to a reused DB.
REVOKE ALL ON SCHEMA src_b, agg_b FROM svc_a;
REVOKE ALL ON ALL TABLES IN SCHEMA src_b, agg_b FROM svc_a;
REVOKE ALL ON ALL SEQUENCES IN SCHEMA src_b, agg_b FROM svc_a;

REVOKE ALL ON SCHEMA src_a, agg_a FROM svc_b;
REVOKE ALL ON ALL TABLES IN SCHEMA src_a, agg_a FROM svc_b;
REVOKE ALL ON ALL SEQUENCES IN SCHEMA src_a, agg_a FROM svc_b;

ALTER DEFAULT PRIVILEGES FOR ROLE postgres IN SCHEMA shared
  GRANT SELECT ON TABLES TO svc_a, svc_b;
ALTER DEFAULT PRIVILEGES FOR ROLE postgres IN SCHEMA src_a
  GRANT SELECT ON TABLES TO svc_a;
ALTER DEFAULT PRIVILEGES FOR ROLE postgres IN SCHEMA src_b
  GRANT SELECT ON TABLES TO svc_b;

ALTER ROLE svc_a IN DATABASE atscale_lab
  SET search_path = src_a, shared, agg_a;
ALTER ROLE svc_b IN DATABASE atscale_lab
  SET search_path = src_b, shared, agg_b;

ANALYZE shared.dim_date;
ANALYZE src_a.fact_sales;
ANALYZE src_b.fact_budget;

COMMIT;
