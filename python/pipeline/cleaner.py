import csv
import pandas as pd
from typing import Tuple, Dict

def clean_events(file_path: str) -> Tuple[pd.DataFrame, pd.DataFrame, Dict[str, int]]:
    good_rows = []
    bad_rows = []
    
    with open(file_path, 'r', encoding='utf-8') as f:
        reader = csv.reader(f)
        try:
            header = next(reader)
            expected_cols = len(header)
        except StopIteration:
            return pd.DataFrame(), pd.DataFrame(), {"unparseable_revenue_count": 0, "duplicates_removed": 0}
        for row in reader:
            if len(row) == expected_cols:
                good_rows.append(row)
            else:
                bad_rows.append(row)

    if not good_rows:
        return pd.DataFrame(columns=header), pd.DataFrame(bad_rows), {"unparseable_revenue_count": 0, "duplicates_removed": 0}

    df = pd.DataFrame(good_rows, columns=header)
    quarantined_df = pd.DataFrame(bad_rows)

    df = df[df['is_test'].str.lower() != 'true'].copy()

    unparseable_count = 0
    def parse_revenue(val: str) -> float:
        nonlocal unparseable_count
        if pd.isna(val):
            unparseable_count += 1
            return 0.0
        val_str = str(val).strip().replace(',', '.')
        if val_str == '' or val_str.upper() == 'NULL':
            unparseable_count += 1
            return 0.0
        try:
            return float(val_str)
        except ValueError:
            unparseable_count += 1
            return 0.0
    df['revenue_usd'] = df['revenue_usd'].apply(parse_revenue)

    def clean_country(val: str) -> str:
        if pd.isna(val):
            return 'XX'
        val_str = str(val).strip().upper()
        if len(val_str) == 2 and val_str.isalpha():
            return val_str
        return 'XX'
    df['country'] = df['country'].apply(clean_country)

    df['event_time'] = pd.to_datetime(df['event_time'], utc=True, errors='coerce')
    df['ingested_at'] = pd.to_datetime(df['ingested_at'], utc=True, errors='coerce')

    rows_before_dedup = len(df)
    df = df.sort_values(by=['ingested_at', 'revenue_usd'], ascending=[False, False])
    df = df.drop_duplicates(subset=['event_id'], keep='first')

    metadata = {
        "unparseable_revenue_count": unparseable_count,
        "duplicates_removed": rows_before_dedup - len(df)
    }
    return df, quarantined_df, metadata