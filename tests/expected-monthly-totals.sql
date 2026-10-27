\set ON_ERROR_STOP on

-- Read-only truth set for the deterministic data in db/init/00-create-lab.sql.
WITH expected (month_start, expected_sales, expected_budget) AS (
  VALUES
    (date '2025-01-01', 6059.00::numeric, 5525.00::numeric),
    (date '2025-02-01', 5512.00::numeric, 5114.00::numeric),
    (date '2025-03-01', 6104.00::numeric, 5705.00::numeric),
    (date '2025-04-01', 5870.00::numeric, 5586.00::numeric),
    (date '2025-05-01', 6054.00::numeric, 6002.00::numeric),
    (date '2025-06-01', 5935.00::numeric, 5808.00::numeric),
    (date '2025-07-01', 6099.00::numeric, 6026.00::numeric),
    (date '2025-08-01', 6074.00::numeric, 6272.00::numeric),
    (date '2025-09-01', 5842.50::numeric, 6102.00::numeric),
    (date '2025-10-01', 6119.00::numeric, 6296.00::numeric),
    (date '2025-11-01', 5907.50::numeric, 6324.00::numeric),
    (date '2025-12-01', 6069.00::numeric, 6632.00::numeric),
    (date '2026-01-01', 6124.00::numeric, 5459.00::numeric),
    (date '2026-02-01', 5537.00::numeric, 5150.00::numeric),
    (date '2026-03-01', 6074.00::numeric, 5795.00::numeric),
    (date '2026-04-01', 5842.50::numeric, 5580.00::numeric),
    (date '2026-05-01', 6119.00::numeric, 5897.00::numeric),
    (date '2026-06-01', 5907.50::numeric, 5880.00::numeric),
    (date '2026-07-01', 6069.00::numeric, 6077.00::numeric),
    (date '2026-08-01', 6091.50::numeric, 6128.00::numeric),
    (date '2026-09-01', 5910.00::numeric, 6174.00::numeric),
    (date '2026-10-01', 6089.00::numeric, 6386.00::numeric),
    (date '2026-11-01', 5880.00::numeric, 6201.00::numeric),
    (date '2026-12-01', 6134.00::numeric, 6644.00::numeric)
),
actual_sales AS (
  SELECT
    d.month_start,
    round(sum(s.sales_amount)::numeric, 2) AS actual_sales
  FROM shared.dim_date AS d
  JOIN src_a.fact_sales AS s USING (date_key)
  GROUP BY d.month_start
),
actual_budget AS (
  SELECT
    d.month_start,
    round(sum(b.budget_amount)::numeric, 2) AS actual_budget
  FROM shared.dim_date AS d
  JOIN src_b.fact_budget AS b USING (date_key)
  GROUP BY d.month_start
),
all_months AS (
  SELECT month_start FROM expected
  UNION
  SELECT month_start FROM actual_sales
  UNION
  SELECT month_start FROM actual_budget
)
SELECT
  m.month_start,
  e.expected_sales,
  s.actual_sales,
  e.expected_budget,
  b.actual_budget,
  e.expected_sales - e.expected_budget AS expected_variance,
  s.actual_sales - b.actual_budget AS actual_variance,
  CASE
    WHEN e.expected_sales = s.actual_sales
     AND e.expected_budget = b.actual_budget
     AND e.expected_sales - e.expected_budget
         = s.actual_sales - b.actual_budget
    THEN 'PASS'
    ELSE 'FAIL'
  END AS result
FROM all_months AS m
LEFT JOIN expected AS e USING (month_start)
LEFT JOIN actual_sales AS s USING (month_start)
LEFT JOIN actual_budget AS b USING (month_start)
ORDER BY m.month_start;

SELECT
  round((SELECT sum(sales_amount) FROM src_a.fact_sales)::numeric, 2)
    AS actual_sales_total,
  143422.50::numeric AS expected_sales_total,
  round((SELECT sum(budget_amount) FROM src_b.fact_budget)::numeric, 2)
    AS actual_budget_total,
  142763.00::numeric AS expected_budget_total,
  CASE
    WHEN round((SELECT sum(sales_amount) FROM src_a.fact_sales)::numeric, 2)
           = 143422.50::numeric
     AND round((SELECT sum(budget_amount) FROM src_b.fact_budget)::numeric, 2)
           = 142763.00::numeric
    THEN 'PASS'
    ELSE 'FAIL'
  END AS result;
