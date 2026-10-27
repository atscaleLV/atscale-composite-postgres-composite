\set ON_ERROR_STOP on

BEGIN;

-- The exact two-account composite is retained as a negative compiler test.
-- This third local-only account is the single-warehouse control that lets the
-- same composite model and UDA run end to end.
DO $roles$
BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_roles WHERE rolname = 'svc_composite_control') THEN
    CREATE ROLE svc_composite_control
      LOGIN
      PASSWORD 'svc_composite_control_local'
      NOSUPERUSER
      NOCREATEDB
      NOCREATEROLE
      NOREPLICATION
      NOINHERIT;
  ELSE
    ALTER ROLE svc_composite_control PASSWORD 'svc_composite_control_local';
  END IF;
END
$roles$;

GRANT CONNECT ON DATABASE atscale_lab TO svc_composite_control;

CREATE SCHEMA IF NOT EXISTS agg_control AUTHORIZATION postgres;
REVOKE ALL ON SCHEMA agg_control FROM PUBLIC;

GRANT USAGE ON SCHEMA shared, src_a, src_b TO svc_composite_control;
GRANT SELECT ON ALL TABLES IN SCHEMA shared, src_a, src_b TO svc_composite_control;
GRANT ALL PRIVILEGES ON SCHEMA agg_control TO svc_composite_control;

ALTER DEFAULT PRIVILEGES FOR ROLE postgres IN SCHEMA shared
  GRANT SELECT ON TABLES TO svc_composite_control;
ALTER DEFAULT PRIVILEGES FOR ROLE postgres IN SCHEMA src_a
  GRANT SELECT ON TABLES TO svc_composite_control;
ALTER DEFAULT PRIVILEGES FOR ROLE postgres IN SCHEMA src_b
  GRANT SELECT ON TABLES TO svc_composite_control;

ALTER ROLE svc_composite_control IN DATABASE atscale_lab
  SET search_path = src_a, src_b, shared, agg_control;

COMMIT;
