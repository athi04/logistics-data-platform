from extract import extract_orders
from transform import transform_orders
from validate import validate_orders
from load import load_orders

def main():

    file_path = "data/olist_orders_dataset.csv"

    # 1. Extract
    orders = extract_orders(file_path)

    # 2. Transform
    orders = transform_orders(orders)

    # 3. Validate
    orders = validate_orders(orders)

    # 4. Load
    load_orders(orders) 
    
    print(f"Successfully processed {len(orders)} orders")


if __name__ == "__main__":
    main()