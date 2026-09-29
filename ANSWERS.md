4.1

Fact table: fct_events
Grain: One row per unique, de-duplicated mobile event (1 row = 1 event_id).
Measures: revenue_usd (and optionally a count of 1 for event volume).
Dimensions:
- dim_apps (app_id, app_name, platform, store_id)
- dim_users (user_id, country)
- dim_campaigns (campaign, media_source)
- dim_date (date derived from event_time)

4.2

To handle a renamed campaign without breaking historical reports, I would implement
a Slowly Changing Dimension (SCD Type 2). I would add a surrogate primary key to the
campaign dimension table, along with valid_from, valid_to, and is_active columns.
When the name changes, the old record is closed out by updating its valid_to date,
and a new record with the new name is inserted. The cost: This significantly increases
query complexity, as fact table joins can no longer rely on a simple ID match;

4.3

To a marketing manager: Idempotency means you can press the "run" button on our data
pipeline as many times as you want without messing anything up. Whether you run it once or
ten times, the final dashboard will look exactly the same. It protects us from accidentally
doubling our revenue numbers or creating duplicate records.
To an engineer: A basic INSERT ... SELECT is not idempotent because re-running it simply
appends the same rows again, causing duplicates. The usual fixes are either using a DELETE
statement for the target time window right before the INSERT, or using an
INSERT ... ON CONFLICT DO UPDATE (UPSERT) pattern based on a primary key.

4.4

Since our pipeline's incremental load is built to filter on ingested_at rather than
event_time, Thursday's pipeline run will naturally pick up Monday's late-arriving event and
UPSERT it into the clean fact table.
I would tell the client that our reporting reflects a dynamic reality where late mobile
events are continuously processed. I would advise them to re-pull Monday's report, explaining
that the numbers have been finalized and the slight increase accurately reflects the
late-arriving offline conversions.

4.5

I would partition the fact table on the date of the event_time column. This is because
analytical workloads and dashboard queries almost universally filter data by when the business
event actually occurred (e.g., "show me last month's revenue"), making partition pruning highly
effective. If we partitioned by ingested_at, a query for a specific business month would havet
to scan multiple scattered partitions.
The trade-off: This choice makes queries that filter strictly by user_id across all time (like
checking a specific user's entire lifetime history) much slower, because the engine must scan
every single date partition to find that user's scattered events.

Here are the first five things I would check to isolate why one app shows 0
revenue for Sunday, despite a successful pipeline:

1. Check the source data (events_raw): Did we receive any rows for this
specific app_id on Sunday?

Yes: The vendor sent the data; the issue is within our internal transformation
pipeline or BI tool.

No: The issue is upstream (the vendor failed to send the data, or the app's
tracking SDK broke).

2. Check the target data (events_clean): Are there Sunday records for this app
in the final clean table?

Yes: The pipeline successfully processed the data. The issue is strictly in the
BI dashboard layer

No: The pipeline filtered the data out during processing.

3. Check the pipeline filters (e.g., is_test flag): Were all Sunday events for
this app accidentally flagged as is_test = 'true' or had revenue_usd = NULL/0?

Yes: The pipeline correctly filtered them out based on business rules. The data
itself is bad.

No: The data looks valid, meaning the issue lies elsewhere in the SQL logic.

Check the dimension tables (e.g., apps): Is this app_id missing from the apps
dimension table?

Yes (it is missing): A strict INNER JOIN in the reporting view might be dropping
the revenue because the app dimension isn't updated.

No (it is present): Referential integrity is fine.

Check the raw payload logs / Vendor status: Is there a known outage reported by
the mobile analytics vendor for this specific app or platform?

Yes: It's a known external incident. We wait for the vendor to send the late
data and rely on our incremental load to pick it up.

No: We need to escalate to the app's internal development team to check if an
update broke tracking.
