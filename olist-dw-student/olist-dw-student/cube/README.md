# Olist Sales cube (SSAS Multidimensional)

SQL Server **Express does not include Analysis Services**. Install SSAS from the free
**SQL Server Developer** media: Custom install -> select **only Analysis Services** ->
mode **Multidimensional and Data Mining**. The warehouse stays on Express.

## Build (Visual Studio + Analysis Services Projects extension)
1. New project: *Analysis Services Multidimensional and Data Mining Project* -> `OlistCube`.
2. Data Source: provider *Microsoft OLE DB Driver for SQL Server*, server `localhost\SQLEXPRESS`
   (or `localhost,1433`), Windows authentication, database `OlistDW`.
   Impersonation: *Use the service account* (run `include/sql/05_ssas_service_access.sql` first).
3. Data Source View: all tables of schema `marts`. Draw relationships fact key -> dimension key
   (fact_orders has 4 relationships to dim_date).
4. Dimensions: Date (Calendar Year > Quarter > Month > Day), Customer (State > City > Customer),
   Product (Category > Product), Seller (State > City > Seller), Payment Type, Order Status.
5. Cube `Olist Sales`, measure groups:
   - **Sales** (fact_sales): Sales Amount, Freight Amount, Total Amount, Item Count, Order Count (distinct order_id)
   - **Payments** (fact_payments): Payment Value, Installments
   - **Orders** (fact_orders): Orders Count, Late Orders (sum is_late), Delivery Days, Review Score Sum
6. Calculations: paste `mdx/calculated_members.mdx`.
7. Deploy to `localhost` (the SSAS instance), process, browse in SSMS or Excel.

## Expected results (course files)

| Check | Value |
|---|---|
| Sales Amount (all years) | 13,591,643.70 |
| Sales Amount 2016 / 2017 / 2018 | 49,785.92 / 6,155,806.98 / 7,386,050.80 |
| Item Count 2016 / 2017 / 2018 | 370 / 50,864 / 61,416 |
| Payment Value | 16,008,872.12 |
| Late Rate (delivered orders) | 6.77% (6,535 of 96,476) |


## Files of this folder

| File | What it is |
|---|---|
| `mdx/calculated_members.mdx` | the calculated members and named sets to paste in the **Calculations** tab of the cube (KPIs: Average Order Value, Freight %, Late Rate, Average Delivery Days, Average Review Score, YTD, YoY, top-10 sets) |
| `mdx/business_questions.mdx` | 13 MDX queries to run in SSMS (Analysis Services) and compare with the numbers above |
| `../include/sql/06_validate_warehouse_totals.sql` | the same numbers verified **in SQL** on `marts`, before even opening the cube |

## Two pitfalls that change the numbers

1. **Late Rate is computed on delivered orders only.** `Late Orders / Orders Count` over
   *all* orders gives 0.79%; the reference 6.77% is `Late Orders / Delivered Orders`
   (6,534 / 96,478). Use the `[Measures].[Late Rate]` member, which already restricts to
   `[Order Status].[Order Status].[Delivered]`.
2. **`is_late` compares dates, not timestamps.** The `fact_orders` model computes it at day
   level; on timestamps the count is 7,826 (8.11%) because the estimated date is stored at
   00:00:00.

## Measure groups to create (before pasting the calculations)

| Measure group | Source table | Measures |
|---|---|---|
| Sales | `marts.fact_sales` | Sales Amount (`price`), Freight Amount (`freight_value`), Total Amount (`total_value`), Item Count (sum of `item_count`), Order Count (**distinct count** of `order_id`) |
| Payments | `marts.fact_payments` | Payment Value (`payment_value`), Installments (`payment_installments`) |
| Orders | `marts.fact_orders` | Orders Count (sum of `orders_count`), Late Orders (sum of `is_late`), Delivery Days (`delivery_days`), Review Score Sum (`review_score`) |

## Dimension relationships

| Dimension | Fact | Key on the fact |
|---|---|---|
| Date | `fact_sales` | `date_key` |
| Date | `fact_payments` | `date_key` |
| Date | `fact_orders` | `purchase_date_key`, `approved_date_key`, `delivered_carrier_date_key`, `delivered_customer_date_key` (four relationships) |
| Customer | `fact_sales`, `fact_payments`, `fact_orders` | `customer_key` |
| Product | `fact_sales` | `product_key` |
| Seller | `fact_sales` | `seller_key` |
| Payment Type | `fact_payments` | `payment_type_key` |
| Order Status | `fact_sales`, `fact_orders` | `order_status_key` |

## Validate
Run `mdx/business_questions.mdx` in SSMS (Analysis Services, MDX query) and compare with
`include/sql/06_validate_cube_totals.sql`.
