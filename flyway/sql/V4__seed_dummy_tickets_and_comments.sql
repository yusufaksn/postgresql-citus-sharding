-- V4__seed_dummy_tickets_and_comments.sql

DO $$
BEGIN
    IF (SELECT count(*) FROM tickets) > 0 THEN
        RAISE EXCEPTION 'tickets table is not empty — aborting to avoid duplicate seed data.';
    END IF;
END $$;

CREATE UNLOGGED TABLE ticket_staging AS
SELECT
    gen_random_uuid() AS id,
    ('00000000-0000-0000-0000-' || LPAD((((gs - 1) % 100) + 1)::text, 12, '0'))::uuid AS tenant_id,
    gs
FROM generate_series(1, 10000000) AS gs;

DO $$
DECLARE
    batch_size   INT := 500000;
    total_rows   INT := 10000000;
    batch_start  INT;
    batch_end    INT;
    started_at   TIMESTAMP := clock_timestamp();
BEGIN
    FOR batch_start IN 1..total_rows BY batch_size LOOP
        batch_end := LEAST(batch_start + batch_size - 1, total_rows);

        INSERT INTO tickets (id, tenant_id, description, notes, assignee, ticket_date, priority_type, ticket_status)
        SELECT id, tenant_id,
               'Dummy ticket description ' || gs,
               'Dummy ticket notes ' || gs,
               'user_' || (((gs - 1) % 50) + 1),
               CURRENT_TIMESTAMP - (random() * INTERVAL '365 days'),
               CASE (gs - 1) % 3 WHEN 0 THEN 'LOW' WHEN 1 THEN 'MEDIUM' ELSE 'HIGH' END,
               CASE (gs - 1) % 4 WHEN 0 THEN 'OPEN' WHEN 1 THEN 'IN_PROGRESS' WHEN 2 THEN 'RESOLVED' ELSE 'CLOSED' END
        FROM ticket_staging
        WHERE gs BETWEEN batch_start AND batch_end;

        RAISE NOTICE 'tickets: % / % inserted (%%%) — elapsed %',
            batch_end, total_rows,
            round(100.0 * batch_end / total_rows, 1),
            clock_timestamp() - started_at;
    END LOOP;
END $$;

DO $$
DECLARE
    batch_size   INT := 500000;
    total_rows   INT := 10000000;
    batch_start  INT;
    batch_end    INT;
    started_at   TIMESTAMP := clock_timestamp();
BEGIN
    FOR batch_start IN 1..total_rows BY batch_size LOOP
        batch_end := LEAST(batch_start + batch_size - 1, total_rows);

        INSERT INTO ticket_comments (id, tenant_id, ticket_id, comment, created_at)
        SELECT gen_random_uuid(), tenant_id, id, 'Dummy comment 1 for ticket ' || id, CURRENT_TIMESTAMP
        FROM ticket_staging WHERE gs BETWEEN batch_start AND batch_end
        UNION ALL
        SELECT gen_random_uuid(), tenant_id, id, 'Dummy comment 2 for ticket ' || id, CURRENT_TIMESTAMP
        FROM ticket_staging WHERE gs BETWEEN batch_start AND batch_end;

        RAISE NOTICE 'ticket_comments: % / % source tickets processed (%%%) — elapsed %',
            batch_end, total_rows,
            round(100.0 * batch_end / total_rows, 1),
            clock_timestamp() - started_at;
    END LOOP;
END $$;

DROP TABLE ticket_staging;