import pandas as pd


def extract_orders(file_path):
    orders = pd.read_csv(file_path)

    print(f"Loaded {len(orders)} orders")

    return orders