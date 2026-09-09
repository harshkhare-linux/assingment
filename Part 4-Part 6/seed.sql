BEGIN;

CREATE TEMP TABLE tmp_inserted_bookings (
    id          UUID,
    status      VARCHAR(50),
    created_at  TIMESTAMP
) ON COMMIT DROP;

WITH org_pool AS (
    SELECT unnest(ARRAY[
        '11111111-1111-1111-1111-111111111111',
        '22222222-2222-2222-2222-222222222222',
        '33333333-3333-3333-3333-333333333333',
        '44444444-4444-4444-4444-444444444444',
        '55555555-5555-5555-5555-555555555555'
    ]::uuid[]) AS org_id
),
generated AS (
    SELECT
        g,
        (SELECT org_id FROM org_pool ORDER BY random() LIMIT 1) AS org_id,
        'HTL-' || lpad((1 + floor(random() * 40))::text, 3, '0') AS hotel_id,
        (ARRAY['delhi','mumbai','bengaluru','chennai','hyderabad','pune'])
            [1 + floor(random() * 6)::int] AS city,
        (current_date + floor(random() * 90)::int) AS checkin_date,
        (ARRAY['pending','confirmed','confirmed','cancelled','completed','completed','no_show'])
            [1 + floor(random() * 7)::int] AS status,
        now() - (random() * interval '60 days') AS created_at
    FROM generate_series(1, 150) AS g
),
inserted AS (
    INSERT INTO hotel_bookings
        (org_id, hotel_id, city, checkin_date, checkout_date, amount, status, created_at)
    SELECT
        org_id,
        hotel_id,
        city,
        checkin_date,
        checkin_date + (1 + floor(random() * 5))::int,   -- 1-5 night stay
        round((1500 + random() * 43500)::numeric, 2),    -- amount 1500-45000
        status,
        created_at
    FROM generated
    RETURNING id, status, created_at
)
INSERT INTO tmp_inserted_bookings
SELECT id, status, created_at FROM inserted;


WITH numbered AS (
    SELECT id, status, created_at,
           row_number() OVER (ORDER BY id) AS rn
    FROM tmp_inserted_bookings
),
selected AS (
    SELECT * FROM numbered WHERE rn % 3 = 0
)
INSERT INTO booking_events (booking_id, event_type, payload, created_at)
SELECT
    s.id,
    ev.event_type,
    jsonb_build_object('note', ev.event_type || ' event for booking ' || s.id),
    s.created_at + (ev.ord || ' hours')::interval
FROM selected s
CROSS JOIN LATERAL (
    SELECT * FROM (VALUES
        (1,  'created'),
        (4,  'payment_received'),
        (24, CASE WHEN s.status = 'cancelled' THEN 'cancelled'
                  WHEN s.status = 'completed' THEN 'checked_out'
                  ELSE 'checked_in' END)
    ) AS v(ord, event_type)
) ev;

COMMIT;

ANALYZE hotel_bookings;
ANALYZE booking_events;
