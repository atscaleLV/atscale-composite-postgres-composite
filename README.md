# AtScale composite PostgreSQL fixture

This is a self-contained PostgreSQL 14 fixture. It does not require AtScale,
Gitea, a locally installed PostgreSQL client, or any pre-existing database.
Docker Compose creates the database, roles, grants, schemas, and deterministic
sample rows from the versioned SQL under `db/init/`.

## Requirements

- Docker Desktop, or Docker Engine with the Compose v2 plugin
- Git
- approximately 500 MB of free disk space for the image and data volume

## Install and verify

Clone the fixture branch, enter its root, and run:

```bash
git clone --branch database-fixture --single-branch \
  https://github.com/atscaleLV/atscale-composite-postgres-composite.git
cd atscale-composite-postgres-composite
```

Then start and verify the fixture:

```bash
docker compose up -d --wait postgres
./scripts/verify-db.sh
```

The verifier runs entirely through the PostgreSQL container. A successful run
ends with:

```text
PASS: database fixture, account isolation, aggregate-schema writes, and 24-month truth set
```

PostgreSQL is then available at `127.0.0.1:54329`, database `atscale_lab`.
These credentials are intentionally simple and are only for this disposable,
loopback-bound lab:

| AtScale warehouse ID | PostgreSQL role | Password | Read schemas | Aggregate schema |
|---|---|---|---|---|
| `pg_model_a` | `svc_a` | `svc_a_local` | `shared`, `src_a` | `agg_a` |
| `pg_model_b` | `svc_b` | `svc_b_local` | `shared`, `src_b` | `agg_b` |
| `pg_composite_control` | `svc_composite_control` | `svc_composite_control_local` | `shared`, `src_a`, `src_b` | `agg_control` |

All three use database `atscale_lab`, port `54329`, and PostgreSQL type. The
administrative fixture login is `postgres` / `local_admin_only`.

If port `54329` or one of the default Docker resource names is already in use,
copy `.env.example` to `.env` and change the conflicting value before the first
`docker compose up`. For example:

```dotenv
COMPOSITE_PROJECT_NAME=atscale-composite-lab-alice
COMPOSITE_PG_CONTAINER_NAME=atscale-composite-postgres-alice
COMPOSITE_PG_VOLUME=atscale-composite-pg-data-alice
COMPOSITE_PG_PORT=55432
```

Changing only the host port is also possible without an `.env` file:

```bash
COMPOSITE_PG_PORT=55432 docker compose up -d --wait postgres
```

## Stop, resume, or reinstall

These commands preserve the database volume:

```bash
docker compose stop postgres
docker compose start postgres
docker compose down
```

This command deletes the fixture volume and rebuilds everything from the
versioned initialization SQL on the next start:

```bash
docker compose down -v
docker compose up -d --wait postgres
./scripts/verify-db.sh
```

Do not run `down -v` if this disposable fixture contains changes you need to
keep. AtScale-created aggregate tables are runtime output and are intentionally
not baked into the portable database fixture; rebuild them from the supplied
SML after configuring the AtScale data warehouses.

## Connect AtScale after the database passes

On Docker Desktop for macOS or Windows, an AtScale container can normally use
`host.docker.internal` and the configured host port. A host-native client uses
`127.0.0.1`. Linux container networking varies; use a secured host address or
attach the containers to an explicitly chosen shared Docker network.

After creating those three AtScale data warehouses, link these three private
GitHub repositories separately in Design Center:

```text
https://github.com/atscaleLV/atscale-composite-postgres-model-a.git
https://github.com/atscaleLV/atscale-composite-postgres-model-b.git
https://github.com/atscaleLV/atscale-composite-postgres-composite.git
```

The three `main` branches form the deployable single-connection composite/UDA
control. The Model A and Model B `isolated-service-account` branches exercise
the two database accounts independently; combining those two AtScale warehouse
IDs remains the expected compiler-boundary case on C2026.7.1.

For Docker Desktop, set the warehouse host to `host.docker.internal`. For a
host-native AtScale installation, use `127.0.0.1`. On Linux, explicitly choose
a secured host-gateway address or shared Docker network that both stacks can
reach. Keep this fixture bound to loopback; it is not production-hardened.
