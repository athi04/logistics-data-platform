# Reference figures

Every figure below is produced by `python src/run_pipeline.py` on a
fresh database. All money values are Brazilian reais (BRL).

Last validated: 7 October 2026, after a full wipe and rebuild.

## Row counts

| Table | Rows |
|---|---|
| Orders | 99,441 |
| Order items | 112,650 |
| Payments | 103,886 |
| Reviews (key: `review_id, order_id`) | 99,224 |
| Products | 32,951 |
| Sellers | 3,095 |
| Customers | 99,441 |
| Raw geolocation points | 1,000,163 |
| Geography ZIP prefixes | 19,015 |
| Date dimension (4 Sep 2016 to 12 Nov 2018) | 800 |

## Delivery

Late means delivered on a later **date** than estimated. Estimated
delivery times are all midnight, so comparing timestamps would wrongly
count 1,292 orders delivered on the promised day as late.

| Result | Orders |
|---|---|
| On time or early | 89,941 |
| Late | 6,535 (6.77% of delivered) |
| No delivery date | 2,965 |

## Delivery categories (marts.delivery_performance)

| Category | Orders |
|---|---|
| on_time_or_early | 89,941 (includes 5 canceled after delivery) |
| late | 6,535 (includes 1 canceled after delivery) |
| in_progress | 1,729 |
| not_completed | 1,228 |
| missing_delivery_date | 8 |
| **Total** | **99,441** |

## Products

| Category translation status | Products |
|---|---|
| translated | 32,328 |
| no_category | 610 |
| missing_translation | 13 |

## Categories (marts.category_performance)

| Figure | Value |
|---|---|
| Categories | 74 (71 translated, 2 missing a translation, 1 unknown) |
| Sum of item_count | 112,650 (equals all items) |
| Sum of total_value | 15,843,553.24 BRL (equals item total) |
| Sum of order_count | 99,470, more than the 98,666 orders with items, because 786 orders span several categories |
| Top category by value | health_beauty, 1,441,248.07 BRL |

## Customers (marts.customer_performance)

| Figure | Value |
|---|---|
| Real customers (customer_unique_id) | 96,096 |
| Repeat customers (more than one order) | 2,997 (3.12%) |
| Sum of order_count | 99,441 (equals all orders) |
| Sum of total_spent | 15,843,553.24 BRL (equals item total) |
| Customers with no review | 716 |
| Customers whose orders had no items | 676 |
| Avg review score, no late delivery | 4.29 (86,857 customers) |
| Avg review score, at least one late delivery | 2.30 (6,499 customers) |

## Money

| Figure | BRL |
|---|---|
| Product value | 13,591,643.70 |
| Freight | 2,251,909.54 |
| Item total | 15,843,553.24 |
| Payment total | 16,008,872.12 |
| Payments minus items | 165,318.88 |

## Reconciliation (one row per order)

Tolerance of 0.01 BRL for instalment rounding.

| Status | Orders | Net difference (BRL) |
|---|---|---|
| reconciled | 98,365 (98.92%) | -0.67 |
| payment_without_items | 772 | 162,591.95 |
| payment_greater_than_items | 264 | 3,070.14 |
| items_greater_than_payment | 39 | -199.08 |
| items_without_payment | 1 | -143.46 |

Exceptions net to 165,319.55; adding the -0.67 of rounding gives the
165,318.88 overall difference.

## Performance

| Measure | Value |
|---|---|
| Raw load, row by row vs COPY | 128.746 s vs 23.771 s (5.42x faster) |
| Full pipeline from empty | under one minute |
