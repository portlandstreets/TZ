import pandas as pd

def load_daily(path: str, day: str) -> pd.DataFrame:
    df = pd.read_csv(path, usecols=["app_id", "media_source", "event_time", "revenue_usd"])
    
    df = df[df['event_time'].str.startswith(day)]
    
    df['revenue_usd'] = pd.to_numeric(df['revenue_usd'].str.replace(',', '.'), errors='coerce').fillna(0.0)
    
    df['key'] = df['app_id'] + '-' + df['media_source']
    result = df.groupby('key', as_index=False)['revenue_usd'].sum()
    
    result = result.rename(columns={'revenue_usd': 'revenue'}).sort_values('revenue', ascending=False)
    
    return result