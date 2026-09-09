# Hotel Booking — Local Database

## Structure

```
db/init.sql          -> schema + index (runs first, as 01-init.sql)
scripts/seed.sql      -> seed data (runs second, as 02-seed.sql)
backups/backup.sh      -> creates a timestamped pg_dump
backups/restore.sh     -> restores a dump into a FRESH database
docker-compose.yml     -> Postgres 16 container
```

## Setup

```bash
docker compose up -d
docker compose ps    # wait for healthy
```

`db/init.sql` and `scripts/seed.sql` run automatically on first container start
(Postgres only runs `docker-entrypoint-initdb.d/*` scripts the first time a
fresh volume is initialized — delete the `postgres_data` volume to re-seed
from scratch).

## Schema

```sql
hotel_bookings (
  id UUID PRIMARY KEY,
  org_id UUID NOT NULL,
  hotel_id VARCHAR(100) NOT NULL,
  city VARCHAR(100) NOT NULL,
  checkin_date DATE NOT NULL,
  checkout_date DATE NOT NULL,
  amount NUMERIC(12,2) NOT NULL,
  status VARCHAR(50) NOT NULL,
  created_at TIMESTAMP NOT NULL
);

booking_events (
  id BIGSERIAL PRIMARY KEY,
  booking_id UUID NOT NULL REFERENCES hotel_bookings(id),
  event_type VARCHAR(100) NOT NULL,
  payload JSONB,
  created_at TIMESTAMP NOT NULL
);
```

There's no separate `organizations` table in this schema, so seed data
draws `org_id` from a fixed pool of 5 UUIDs reused across bookings —
that's what gives "multiple organizations."

## Part 5 — Seed data

`scripts/seed.sql` inserts:
- **150 bookings** (comfortably over the 100 minimum)
- **6 cities** (delhi, mumbai, bengaluru, chennai, hyderabad, pune)
- **5 organizations** (fixed UUID pool)
- **5 statuses** (pending, confirmed, cancelled, completed, no_show)
- **`created_at` spread over the last 60 days**, so roughly half the rows
  fall inside the 30-day window the target query filters on and half
  fall outside it — this makes the index selectivity realistic instead
  of trivially matching every row
- **booking_events for ~1/3 of bookings** (every 3rd inserted row gets
  1-3 lifecycle events: created, payment_received, and a status-appropriate
  terminal event)

## Part 5 — Index

Target query:

```sql
SELECT org_id, status, COUNT(*), SUM(amount)
FROM hotel_bookings
WHERE city = 'delhi'
  AND created_at >= NOW() - INTERVAL '30 days'
GROUP BY org_id, status;
```

Index added (in `db/init.sql`):

```sql
CREATE INDEX idx_hotel_bookings_city_created_at
    ON hotel_bookings (city, created_at DESC)
    INCLUDE (org_id, status, amount);
```

**Why this shape:**

- **`city` first, `created_at` second:** `city` is an equality predicate
  and `created_at` is a range predicate. B-tree indexes work best when
  equality columns precede range columns — Postgres jumps straight to
  the `delhi` entries and then range-scans only the recent slice, instead
  of scanning every `delhi` row and filtering by date afterward.
- **`INCLUDE (org_id, status, amount)`:** these are exactly the columns
  the query needs beyond the filter columns. As non-key included columns
  (rather than part of the index key) they keep the index cheaper to
  maintain while still letting the whole query run as an **index-only
  scan** — Postgres never touches the heap, it aggregates straight off
  the index.
- **Not a partial index** (`WHERE created_at >= NOW() - INTERVAL '30 days'`):
  Postgres rejects this because `NOW()` isn't immutable — the boundary
  would need to shift constantly. The composite key achieves the same
  pruning via a normal range scan instead.
- **`idx_booking_events_booking_id`** is added as a supporting index for
  the FK relationship and any join/lookup by `booking_id`.


## Part 6 — Backup and restore

```bash
# Create a timestamped dump into backups/
./backups/backup.sh

# Restore a dump into a FRESH database (does not touch the live one)
./backups/restore.sh backups/hotel_booking_backup_20260909_231247.dump
```

- `backup.sh` runs `pg_dump -F c` (custom format) inside the container and
  copies the resulting file out to `backups/<db>_backup_<timestamp>.dump`.
- `restore.sh` copies the dump back into the container, creates a brand
  new database (`hotel_booking_restore_test` by default, override with
  `RESTORE_DB_NAME`), and runs `pg_restore` into it — the original
  `hotel_booking` database is never touched, so a bad restore can't
  destroy live data.

### How to verify the restore worked

1. Run `restore.sh` as above; it restores into `hotel_booking_restore_test`.

2. Confirm:
   - Both tables (`hotel_bookings`, `booking_events`) exist.
   - Row counts match what was in the source database at backup time
     (e.g. 150 bookings, matching event count) — compare against
   - `city`/`status`/`org_id` breakdowns look the same as the source.
   - Orphaned-events check returns `0`.
   - `idx_hotel_bookings_city_created_at` is listed under indexes (indexes
     are part of the dump, so they should already exist post-restore — no
     need to re-run `init.sql`).
   - The target query's `EXPLAIN` still shows an index-only scan.

If all of the above match between the source and the restored database,
the restore is considered verified. Once confirmed, the temporary
`hotel_booking_restore_test` database can be dropped:

```bash
docker exec -it hotel-booking-postgres \
  psql -U postgres -d postgres -c "DROP DATABASE hotel_booking_restore_test;"
```
