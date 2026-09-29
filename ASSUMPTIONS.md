Assumptions Made:

SQL Dialect: All SQL scripts are written and tested in standard PostgreSQL.

Task 3.1 & 3.2 (Python): I assumed the input CSV files are small enough to fit
into memory using standard Pandas. For a production environment with massive data
volumes, I would implement PyArrow/Polars streaming or chunking.

Data Quality (Task 2.5): I assumed the data quality queries are designed to
monitor and report anomalies on a dashboard, not to automatically drop records
from the clean fact table, in order to preserve the audit trail.
