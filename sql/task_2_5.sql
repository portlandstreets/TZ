WITH dq_metrics AS (
    SELECT
        SUM(CASE WHEN revenue_usd < 0 THEN 1 ELSE 0 END) AS negative_revenue_errors,
        SUM(CASE WHEN event_time > ingested_at THEN 1 ELSE 0 END) AS time_travel_errors,
        SUM(CASE WHEN user_id IS NULL OR user_id = '' THEN 1 ELSE 0 END) AS missing_user_errors
    FROM events_clean
)
SELECT * FROM dq_metrics;
