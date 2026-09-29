WITH new_and_corrected_data AS (
    SELECT
        event_id, user_id, app_id, event_name, event_time,
        ingested_at, country, media_source, campaign,
        CAST(REPLACE(NULLIF(NULLIF(TRIM(revenue_usd), ''), 'NULL'), ',', '.') AS NUMERIC) AS revenue_usd,
        ROW_NUMBER() OVER (PARTITION BY event_id ORDER BY ingested_at DESC, revenue_usd DESC) as rn
    FROM events_raw
    WHERE is_test = 'false'
)
INSERT INTO events_clean (
    event_id, user_id, app_id, event_name, event_time,
    ingested_at, country, media_source, campaign, revenue_usd
)
SELECT
    event_id, user_id, app_id, event_name, event_time,
    ingested_at, country, media_source, campaign, revenue_usd
FROM new_and_corrected_data
WHERE rn = 1
ON CONFLICT (event_id) DO UPDATE
SET
    revenue_usd = EXCLUDED.revenue_usd,
    ingested_at = EXCLUDED.ingested_at,
    user_id = EXCLUDED.user_id,
    app_id = EXCLUDED.app_id,
    event_name = EXCLUDED.event_name,
    event_time = EXCLUDED.event_time,
    country = EXCLUDED.country,
    media_source = EXCLUDED.media_source,
    campaign = EXCLUDED.campaign
WHERE events_clean.ingested_at < EXCLUDED.ingested_at;
