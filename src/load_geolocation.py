import pandas as pd

from load_raw import load_dataframe_to_postgres


file_path = "data/olist_geolocation_dataset.csv"

chunk_size = 50_000

for chunk_number, df in enumerate(
    pd.read_csv(file_path, chunksize=chunk_size),
    start=1
):

    columns = [
        "geolocation_zip_code_prefix",
        "geolocation_lat",
        "geolocation_lng",
        "geolocation_city",
        "geolocation_state"
    ]

    load_dataframe_to_postgres(
        df=df,
        table_name="raw.geolocation",
        columns=columns,
        chunk_name=f"raw.geolocation chunk {chunk_number}"
    )