# Citus Ticket Sharding Demo — Seed Data & Verification

This document describes the seed script that generates dummy data for the `tickets` and `ticket_comments` tables, and the verification queries used after loading.

---

## ⚠️ IMPORTANT: This Migration Takes Time to Run

> <span style="color:red">**This migration runs synchronously and takes noticeable time to complete. Do not close the terminal/app or re-trigger the migration before it finishes — doing so will load the data twice (duplicate seed).**</span>

**Reference timing:** loading 10,000,000 tickets + 20,000,000 comments took approximately **~56 seconds** (about 1 second per batch, 20 batches × 2 tables). If you increase the row count, the duration scales up proportionally.

While the migration runs, you'll see live progress in the terminal:
```
tickets: 5000000 / 10000000 inserted (%50.0) — elapsed 00:00:10.16
ticket_comments: 5000000 / 10000000 source tickets processed (%50.0) — elapsed 00:00:12.73
```

---

## How the Migration Is Run

This seed script is applied via Flyway:

```bash
docker-compose up -d
# The Flyway container automatically applies migrations under /flyway/sql
```

Migration file: `flyway/sql/V4__seed_dummy_tickets_and_comments.sql`

---

## How to Increase the Row Count in the Script

The row count is controlled by a single `generate_series` call:

```sql
CREATE UNLOGGED TABLE ticket_staging AS
SELECT
    gen_random_uuid() AS id,
    ('00000000-0000-0000-0000-' || LPAD((((gs - 1) % 100) + 1)::text, 12, '0'))::uuid AS tenant_id,
    gs
FROM generate_series(1, 10000000) AS gs;   -- 👈 change this number
```

Replace `10000000` with the desired ticket count (e.g. `20000000`). Also update the `total_rows` variable in the batch loops to match — otherwise the progress percentage (`%`) will be calculated incorrectly:

```sql
DECLARE
    batch_size   INT := 500000;
    total_rows   INT := 10000000;  -- 👈 update this to the same value
```

> **Note:** The comment count always scales automatically to 2× the ticket count (2 comments per ticket) — no need to change anything else.

---

## Verification Queries (Run in This Order)

After the migration finishes, run the following queries **in order**.

### 1) Total row counts
```sql
SELECT count(*) FROM tickets;          -- expected: your row count (e.g. 10,000,000)
SELECT count(*) FROM ticket_comments;  -- expected: 2x the ticket count
```

### 2) Tenant distribution — evenly spread across 100 tenants
```sql
SELECT tenant_id, count(*) 
FROM tickets 
GROUP BY tenant_id 
ORDER BY count(*) DESC;
-- expected: 100 rows, each with (total tickets / 100)
```

### 3) tenant_id / ticket_id match — colocation check
```sql
SELECT tc.id, tc.tenant_id AS comment_tenant, t.tenant_id AS ticket_tenant
FROM ticket_comments tc
JOIN tickets t 
    ON tc.ticket_id = t.id 
    AND tc.tenant_id = t.tenant_id
WHERE tc.tenant_id <> t.tenant_id
LIMIT 10;
-- expected: 0 rows
```

### 4) Each ticket has exactly 2 comments
```sql
SELECT ticket_id, count(*)
FROM ticket_comments
GROUP BY ticket_id
HAVING count(*) <> 2
LIMIT 10;
-- expected: 0 rows
```

### 5) Orphan comments (comments with no matching ticket)
```sql
SELECT tc.ticket_id
FROM ticket_comments tc
LEFT JOIN tickets t ON t.id = tc.ticket_id
WHERE t.id IS NULL
LIMIT 10;
-- expected: 0 rows
```

### 6) Shard distribution balance (shard count + size per worker)
```sql
SELECT
    nodename,
    nodeport,
    count(*) AS shard_count,
    pg_size_pretty(sum(shard_size)) AS total_size
FROM citus_shards
WHERE table_name = 'tickets'::regclass
GROUP BY nodename, nodeport
ORDER BY nodename;
```

### 7) Colocation ID match
```sql
SELECT logicalrelid::regclass AS table_name, colocationid
FROM pg_dist_partition
WHERE logicalrelid IN ('tickets'::regclass, 'ticket_comments'::regclass);
-- expected: both rows have the same colocationid
```

### 8) Rows per shard (spot outliers)
```sql
SELECT
    get_shard_id_for_distribution_column('tickets', tenant_id) AS shard_id,
    count(*) 
FROM tickets
GROUP BY shard_id
ORDER BY count(*) DESC
LIMIT 10;
```

### 9) Pushdown / router behavior test
```sql
SET max_parallel_workers_per_gather = 0;

EXPLAIN SELECT * 
FROM tickets t 
JOIN ticket_comments tc 
    ON tc.ticket_id = t.id AND tc.tenant_id = t.tenant_id
WHERE t.tenant_id = '00000000-0000-0000-0000-000000000001'::uuid;
-- expected: plan shows "Custom Scan (Citus Adaptive/Router)" and Task Count: 1
```

---

## Summary Checklist

| Check | Expected Result |
|---|---|
| `tickets` row count | Matches the `generate_series` upper bound in the script |
| `ticket_comments` row count | 2x the ticket count |
| Tenant distribution | 100 tenants, evenly split |
| tenant_id / ticket_id match | 0 mismatches |
| Comments per ticket | Exactly 2 |
| Orphan comments | 0 |
| Colocation ID | Same for both tables |
| Pushdown behavior | Single tenant -> single shard, single node |