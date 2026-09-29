WITH clean_events AS (
    SELECT * FROM (
        SELECT
            DATE(event_time) AS event_date,
            app_id, media_source, campaign,
            CAST(REPLACE(NULLIF(NULLIF(TRIM(revenue_usd), ''), 'NULL'), ',', '.') AS NUMERIC) AS revenue_usd,
            ROW_NUMBER() OVER (PARTITION BY event_id ORDER BY ingested_at DESC, revenue_usd DESC) as rn
        FROM events_raw
        WHERE is_test = 'false'
    ) t
    WHERE rn = 1
),
daily_revenue AS (
    SELECT
        event_date AS date, app_id, media_source, campaign, SUM(revenue_usd) AS daily_revenue
    FROM clean_events
    GROUP BY date, app_id, media_source, campaign
),
daily_costs AS (
    SELECT
        date, app_id, media_source, campaign, SUM(cost_usd) AS daily_cost
    FROM campaign_costs
    GROUP BY date, app_id, media_source, campaign
)
SELECT
    COALESCE(r.date, c.date) AS date,
    COALESCE(r.app_id, c.app_id) AS app_id,
    COALESCE(r.media_source, c.media_source) AS media_source,
    COALESCE(r.campaign, c.campaign) AS campaign,
    COALESCE(r.daily_revenue, 0) AS revenue,
    COALESCE(c.daily_cost, 0) AS cost,
    CASE
        WHEN COALESCE(c.daily_cost, 0) = 0 THEN NULL
        ELSE COALESCE(r.daily_revenue, 0) / c.daily_cost
    END AS roas
FROM daily_revenue r
FULL OUTER JOIN daily_costs c
    ON r.date = c.date AND r.app_id = c.app_id AND r.media_source = c.media_source AND r.campaign = c.campaign
ORDER BY date, app_id;
