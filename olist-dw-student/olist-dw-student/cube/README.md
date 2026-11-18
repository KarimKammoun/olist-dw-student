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

## Validate
Run `mdx/business_questions.mdx` in SSMS (Analysis Services, MDX query) and compare with
`include/sql/06_validate_cube_totals.sql`.
