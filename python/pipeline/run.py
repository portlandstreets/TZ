import argparse
import shutil
import sys
from pathlib import Path
import pandas as pd
from pipeline.cleaner import clean_events

def main():
    parser = argparse.ArgumentParser(description="Data Cleaning Pipeline")
    parser.add_argument("--input", required=True, type=str, help="Input directory")
    parser.add_argument("--output", required=True, type=str, help="Output directory")
    parser.add_argument("--since", required=True, type=str, help="Start date YYYY-MM-DD")
    args = parser.parse_args()

    input_dir = Path(args.input)
    output_dir = Path(args.output)
    
    source_file = input_dir / "events_raw.csv"
    if not source_file.exists():
        print(f"Error: Could not find {source_file}")
        sys.exit(1)

    clean_df, quarantined_df, meta = clean_events(str(source_file))
    
    rows_in = len(clean_df) + meta.get("duplicates_removed", 0) + len(quarantined_df)

    since_ts = pd.to_datetime(args.since, utc=True)
    clean_df = clean_df[clean_df['event_time'] >= since_ts].copy()
    clean_df['event_date'] = clean_df['event_time'].dt.date

    if output_dir.exists():
        shutil.rmtree(output_dir)
    
    clean_out_dir = output_dir / "clean_events"
    quarantine_out_dir = output_dir / "quarantined_events"
    clean_out_dir.mkdir(parents=True, exist_ok=True)
    quarantine_out_dir.mkdir(parents=True, exist_ok=True)

    if not clean_df.empty:
        clean_df.to_parquet(clean_out_dir, engine='pyarrow', partition_cols=['event_date'], index=False)
        
    if not quarantined_df.empty:
        quarantined_df.to_parquet(quarantine_out_dir / "bad_rows.parquet", engine='pyarrow', index=False)

    print(f"Summary -> Rows in: {rows_in} | Rows out: {len(clean_df)} | Duplicates removed: {meta.get('duplicates_removed', 0)} | Rows quarantined: {len(quarantined_df)}")

if __name__ == "__main__":
    main()