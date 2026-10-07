def validate_orders(orders):

    # -----------------------------
    # Critical validation checks
    # -----------------------------

    if orders.empty:
        raise ValueError("Orders dataset is empty")

    if orders["order_id"].isnull().any():
        raise ValueError("Found NULL order IDs")

    if orders["order_id"].duplicated().any():
        raise ValueError("Found duplicate order IDs")

    # -----------------------------
    # Order status validation
    # -----------------------------

    valid_statuses = {
        "delivered",
        "shipped",
        "canceled",
        "unavailable",
        "invoiced",
        "processing",
        "created",
        "approved"
    }

    invalid_statuses = (
        set(orders["order_status"].dropna().unique())
        - valid_statuses
    )

    if invalid_statuses:
        raise ValueError(
            f"Found invalid order statuses: {invalid_statuses}"
        )

    # -----------------------------
    # Data-quality warnings
    # -----------------------------

    invalid_approval_dates = (
        orders["order_approved_at"].notna()
        & (
            orders["order_approved_at"]
            < orders["order_purchase_timestamp"]
        )
    )

    if invalid_approval_dates.any():
        print(
            f"WARNING: {invalid_approval_dates.sum()} orders "
            "have approval timestamps before purchase timestamps"
        )

    invalid_carrier_dates = (
        orders["order_delivered_carrier_date"].notna()
        & orders["order_approved_at"].notna()
        & (
            orders["order_delivered_carrier_date"]
            < orders["order_approved_at"]
        )
    )

    if invalid_carrier_dates.any():
        print(
            f"WARNING: {invalid_carrier_dates.sum()} orders "
            "have carrier timestamps before approval timestamps"
        )

    invalid_delivery_dates = (
        orders["order_delivered_customer_date"].notna()
        & orders["order_delivered_carrier_date"].notna()
        & (
            orders["order_delivered_customer_date"]
            < orders["order_delivered_carrier_date"]
        )
    )

    if invalid_delivery_dates.any():
        print(
            f"WARNING: {invalid_delivery_dates.sum()} orders "
            "have customer delivery timestamps before carrier timestamps"
        )

    print("Critical data validation passed")

    return orders