# AtScale Composite PostgreSQL Lab — Composite

This is the third repository in the three-repository AtScale composite-model
lab. It imports the independently linked Model A and Model B repositories as
immutable SML packages, then owns only the cross-model calculation and the
composite model with its user-defined aggregate (UDA).

## Repository topology

| Repository | Ownership |
| --- | --- |
| [`atscale-composite-postgres-model-a`](https://github.com/atscaleLV/atscale-composite-postgres-model-a) | Sales model and canonical `Lab Date Control` dimension |
| [`atscale-composite-postgres-model-b`](https://github.com/atscaleLV/atscale-composite-postgres-model-b) | Budget model, referencing Model A's packaged Date |
| `atscale-composite-postgres-composite` | Variance calculation, composite model, and monthly UDA |

`package.yml` pins both dependencies to full commit SHAs. Keep these pins
immutable and advance them together after upstream changes.

## What the deployable control proves

The default branches of all three repositories use the AtScale warehouse ID
`pg_composite_control`. This lets `lab_sales_budget_composite_control` compile
and lets you observe query routing and the
`uda_monthly_sales_budget_control` aggregate across both component models.

The component repositories also expose `isolated-service-account` branches:

- Model A uses `pg_model_a` / PostgreSQL role `svc_a`.
- Model B uses `pg_model_b` / PostgreSQL role `svc_b`.

Those branches prove the separate service-account boundaries independently.
On AtScale C2026.7.1, combining the two different AtScale warehouse IDs into
this composite is an intentional negative test: a regular component model
must resolve to one warehouse ID, so the deployable composite control uses
`pg_composite_control` for both.

## PostgreSQL fixture

The portable database installer is kept in this repository's
`database-fixture` branch so the lab remains exactly three GitHub repositories:

```bash
git switch database-fixture
cp .env.example .env
docker compose up -d
./scripts/verify-db.sh
```

It starts PostgreSQL on `127.0.0.1:54329`, creates database `atscale_lab`, and
creates the three roles, source schemas, deterministic sample data, and
aggregate schemas required by the lab.

## Design Center order

1. Link all three GitHub URLs as separate Design Center repositories, exposing
   `main` and `isolated-service-account` where present.
2. Create AtScale data warehouses `pg_model_a`, `pg_model_b`, and
   `pg_composite_control` from the fixture connection details.
3. Open/deploy Model A `main`, then Model B `main`, then this repository's
   `main` branch.
4. Build `uda_monthly_sales_budget_control` and compare the query plan and
   aggregate tables with the same query before and after the build.

Because the repositories are private, the GitHub credential configured in
AtScale must be able to read all three repositories and their pinned commits.
