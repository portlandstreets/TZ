WITH deduplicated_events AS (
    SELECT * FROM (
        SELECT
            app_id,
            DATE(event_time) AS event_date,
            CAST(REPLACE(NULLIF(NULLIF(TRIM(revenue_usd), ''), 'NULL'), ',', '.') AS NUMERIC) AS clean_revenue,
            ROW_NUMBER() OVER (PARTITION BY event_id ORDER BY ingested_at DESC, revenue_usd DESC) as rn
        FROM events_raw
        WHERE is_test = 'false'
    ) t
    WHERE rn = 1
),
daily_agg AS (
    SELECT
        app_id,
        event_date,
        COALESCE(SUM(clean_revenue), 0) AS daily_revenue
    FROM deduplicated_events
    GROUP BY app_id, event_date
)
SELECT
    app_id,
    event_date,
    daily_revenue,
    SUM(daily_revenue) OVER (PARTITION BY app_id ORDER BY event_date) AS running_total_revenue,
    AVG(daily_revenue) OVER (PARTITION BY app_id ORDER BY event_date ROWS BETWEEN 6 PRECEDING AND CURRENT ROW) AS moving_avg_7d,
    (daily_revenue - LAG(daily_revenue) OVER (PARTITION BY app_id ORDER BY event_date))
    / NULLIF(LAG(daily_revenue) OVER (PARTITION BY app_id ORDER BY event_date), 0) * 100 AS dod_change_pct
FROM daily_agg
ORDER BY app_id, event_date;
