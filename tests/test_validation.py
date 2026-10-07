from extract import extract_orders
from transform import transform_orders
from validate import validate_orders


orders = extract_orders("data/olist_orders_dataset.csv")

orders = transform_orders(orders)

orders = validate_orders(orders)

print(f"Validated {len(orders)} orders")