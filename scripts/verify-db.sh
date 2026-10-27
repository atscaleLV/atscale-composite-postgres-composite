#!/bin/sh

set -eu

LAB_SCRIPT_DIR=$(CDPATH= cd "$(dirname "$0")" && pwd)
LAB_ROOT=$(dirname "$LAB_SCRIPT_DIR")
cd "$LAB_ROOT"

fail() {
  printf 'FAIL: %s\n' "$1" >&2
  exit 1
}

admin_query() {
  docker compose exec -T postgres \
    psql -X -A -t -v ON_ERROR_STOP=1 -U postgres -d atscale_lab -c "$1"
}

service_query() {
  lab_user=$1
  lab_password=$2
  lab_sql=$3
  docker compose exec -T -e "PGPASSWORD=$lab_password" postgres \
    psql -X -A -t -v ON_ERROR_STOP=1 -h 127.0.0.1 \
    -U "$lab_user" -d atscale_lab -c "$lab_sql"
}

printf 'Checking PostgreSQL health and deterministic row counts...\n'
lab_counts=$(admin_query "SELECT (SELECT count(*) FROM shared.dim_date) || '|' || (SELECT count(*) FROM src_a.fact_sales) || '|' || (SELECT count(*) FROM src_b.fact_budget);")
[ "$lab_counts" = '730|2190|1460' ] || \
  fail "unexpected row counts: $lab_counts (expected 730|2190|1460)"

printf 'Checking positive service-account reads...\n'
[ "$(service_query svc_a svc_a_local 'SELECT count(*) FROM src_a.fact_sales;')" = '2190' ] || \
  fail 'svc_a could not read the Sales fact'
[ "$(service_query svc_b svc_b_local 'SELECT count(*) FROM src_b.fact_budget;')" = '1460' ] || \
  fail 'svc_b could not read the Budget fact'
[ "$(service_query svc_composite_control svc_composite_control_local "SELECT (SELECT count(*) FROM shared.dim_date) || '|' || (SELECT count(*) FROM src_a.fact_sales) || '|' || (SELECT count(*) FROM src_b.fact_budget);")" = '730|2190|1460' ] || \
  fail 'svc_composite_control could not read all control sources'

printf 'Checking that cross-account reads are denied...\n'
if lab_error=$(service_query svc_a svc_a_local 'SELECT count(*) FROM src_b.fact_budget;' 2>&1); then
  fail 'svc_a unexpectedly read the Budget fact'
fi
case "$lab_error" in
  *'permission denied'*) ;;
  *) fail "svc_a failed for an unexpected reason: $lab_error" ;;
esac

if lab_error=$(service_query svc_b svc_b_local 'SELECT count(*) FROM src_a.fact_sales;' 2>&1); then
  fail 'svc_b unexpectedly read the Sales fact'
fi
case "$lab_error" in
  *'permission denied'*) ;;
  *) fail "svc_b failed for an unexpected reason: $lab_error" ;;
esac

printf 'Checking aggregate-schema write grants transactionally...\n'
service_query svc_a svc_a_local \
  'BEGIN; CREATE TABLE agg_a.install_verification (id integer); ROLLBACK;' >/dev/null
service_query svc_b svc_b_local \
  'BEGIN; CREATE TABLE agg_b.install_verification (id integer); ROLLBACK;' >/dev/null
service_query svc_composite_control svc_composite_control_local \
  'BEGIN; CREATE TABLE agg_control.install_verification (id integer); ROLLBACK;' >/dev/null

printf 'Checking all 24 monthly values and grand totals...\n'
lab_truth=$(docker compose exec -T postgres \
  psql -X -A -t -v ON_ERROR_STOP=1 -U postgres -d atscale_lab -f - \
  < tests/expected-monthly-totals.sql)

if printf '%s\n' "$lab_truth" | grep -q '|FAIL$'; then
  printf '%s\n' "$lab_truth" >&2
  fail 'the deterministic truth set contains a failure'
fi

lab_pass_count=$(printf '%s\n' "$lab_truth" | grep -c '|PASS$' || true)
[ "$lab_pass_count" -eq 25 ] || \
  fail "truth set returned $lab_pass_count PASS rows (expected 25: 24 months plus totals)"

printf 'PASS: database fixture, account isolation, aggregate-schema writes, and 24-month truth set\n'
