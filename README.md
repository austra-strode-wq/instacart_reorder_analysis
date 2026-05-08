# Instacart Grocery Reordering Pattern Analysis

## Project Overview

This project analyses customer reordering behaviour using the Instacart Online Grocery Shopping Dataset 2017, a publicly available dataset released by Instacart containing over 3 million anonymised grocery orders from more than 200,000 customers.
The analysis was conducted using Microsoft SQL Server (SSMS) for data cleaning, transformation and analysis, and Microsoft Power BI for visualisation.
The central business question driving this project:
"What reordering patterns exist in customer behaviour, and how can this inform stock and inventory planning?"
This question was chosen to reflect real operational challenges in grocery retail - understanding what customers buy repeatedly, when they buy it, and how frequently, has direct implications for stock availability, replenishment planning and workforce scheduling.

## Business Questions
The analysis is structured around one central question with four supporting sub-questions:

### Central Question: 
What reordering patterns exist in customer behaviour, and how can this inform stock and inventory planning?

### Sub-questions:
- Which aisles and product categories are reordered most frequently, and what does this tell us about high-demand inventory?
- How much does time of day and day of week influence ordering volume - and what are the implications for delivery scheduling and workforce planning?
- How large and how varied are customer orders - are customers buying broadly across categories or concentrating on specific aisles?
- Are there distinct customer segments based on ordering frequency - and what does the split between casual, regular and loyal customers look like?

## Dataset

**Source:** [Instacart Online Grocery Shopping Dataset 2017](https://www.kaggle.com/datasets/yasserh/instacart-online-grocery-basket-analysis-dataset/data), originally released as part of a Kaggle machine learning competition.

**Tables used:** 5 tables imported into SQL Server

| Table | Rows | Description |
|-------|------|-------------|
| orders | 3,421,083 | One row per order - contains user ID, day of week, hour of day, and days since prior order |
| order_products_prior | 32,434,489 | Line-item level — one row per product per order, includes reorder flag |
| products | 49,428 | Product names and their aisle and department IDs |
| aisles | 134 | Aisle ID to aisle name mapping |
| departments | 21 | Department ID to department name mapping |

**Note:** A sixth .csv file (order_products_train) was excluded as it is a subset of order_products_prior created for machine learning purposes and adds no analytical value.

## Tools Used

- **SQL Server (SSMS)** — data import, cleaning, transformation and analysis
- **Microsoft Power BI** — dashboard and visualisation
- **GitHub** — version control and portfolio publishing

## Data Cleaning & Preparation

The dataset was largely clean on import, however several issues were identified and resolved during the cleaning phase.

### Import Challenges

The largest table (order_products_prior, 32M rows) could not be imported using SSMS's standard flat file wizard due to memory limitations. This was resolved using the SQL Server Import and Export Wizard with OLE DB provider, which streams data rather than loading it entirely into memory.

Several data type mismatches were flagged during import and corrected:
- user_id auto-detected as tinyint (max 255) — corrected to int
- product_name nvarchar length too short — corrected to nvarchar(max)
- days_since_prior_order stored as float — corrected to int as only whole day values exist in the data

### Null Handling

A null check across all key columns returned zero nulls, with one intentional exception:

days_since_prior_order contains NULLs representing a customer's first ever order — there is no prior order to measure from. These were deliberately left as NULL rather than defaulted to zero, as COALESCE to 0 would misrepresent first orders as same-day repeat orders.

A flag column was added via view to identify these rows:

```sql
CASE WHEN days_since_prior_order IS NULL THEN 'first_order'
     ELSE 'repeat_order'
END AS first_order_flag
```

### Columns Removed

eval_set was dropped from the orders table. This column was a remnant of the original Kaggle machine learning competition structure (train/test/prior split) and carries no analytical value for this project.

## Views

Five views were created to support analysis and Power BI connectivity. Two housekeeping views were built during the cleaning phase, with additional analytical views created as analysis progressed.

### v_orders_flagged
Adds a first_order_flag column to the orders table to identify a customer's first ever order without modifying the raw data.

### v_day_names
Translates the numeric order_dow column (0–6) into readable day names for stakeholder clarity. A day_sort_order column was also added after discovering that Power BI sorts text fields alphabetically by default — without this numeric sort key, days would display as Friday, Monday, Saturday rather than Monday through Sunday.

```sql
CREATE VIEW v_day_names AS
SELECT *,
    CASE WHEN order_dow = 0 THEN 'Monday'
         WHEN order_dow = 1 THEN 'Tuesday'
         WHEN order_dow = 2 THEN 'Wednesday'
         WHEN order_dow = 3 THEN 'Thursday'
         WHEN order_dow = 4 THEN 'Friday'
         WHEN order_dow = 5 THEN 'Saturday'
         WHEN order_dow = 6 THEN 'Sunday'
    END AS day_names,
    CASE WHEN order_dow = 0 THEN 1
         WHEN order_dow = 1 THEN 2
         WHEN order_dow = 2 THEN 3
         WHEN order_dow = 3 THEN 4
         WHEN order_dow = 4 THEN 5
         WHEN order_dow = 5 THEN 6
         WHEN order_dow = 6 THEN 7
    END AS day_sort_order
FROM orders;
```

### v_order_size_diversity
The most complex view — uses two CTEs to calculate products per order and distinct aisle count per order, joined on order_id. A window function calculates the overall average across all orders without collapsing row-level detail. Order size categories were added for Power BI visualisation, with bins defined based on data distribution (average 10 products, maximum 146).

```sql
CREATE VIEW v_order_size_diversity AS
    WITH Product_Counts_CTE AS
        (SELECT order_id,
                COUNT(product_id) AS products_per_order
        FROM order_products_prior
        GROUP BY order_id),
    Aisles_Counts_CTE AS
        (SELECT order_id,
                COUNT(DISTINCT aisle_id) AS aisle_counts
        FROM order_products_prior opp
        JOIN products p ON opp.product_id = p.product_id
        GROUP BY order_id)
    SELECT pc.order_id,
            products_per_order,
            AVG(products_per_order) OVER() AS avg_product_counts,
            aisle_counts,
            CASE WHEN products_per_order BETWEEN 1 AND 5 THEN 'Small (1-5)'
                 WHEN products_per_order BETWEEN 6 AND 15 THEN 'Medium (6-15)'
                 WHEN products_per_order BETWEEN 16 AND 30 THEN 'Large (16-30)'
                 WHEN products_per_order BETWEEN 31 AND 50 THEN 'Extra Large (31-50)'
                 WHEN products_per_order > 50 THEN 'Bulk (50+)'
            END AS order_size_category
    FROM Product_Counts_CTE pc
    JOIN Aisles_Counts_CTE ac ON pc.order_id = ac.order_id;
```

### v_reordering_data
Calculates per-user order count and average days between orders, then segments customers into Casual, Regular and Loyal categories based on order frequency, and Weekly, Fortnightly and Monthly+ categories based on reorder gap. Thresholds were defined by first exploring the data distribution — average 16 orders, maximum 100, average 15 days between orders.

## Analysis & Key Findings

### Most Reordered Products by Aisle

Fresh produce dominates reordering behaviour — the top 10 most reordered aisles are overwhelmingly fresh fruit and vegetables, with fresh fruits alone accounting for the highest reorder volume. This has direct implications for stock prioritisation: these aisles require consistent availability and frequent replenishment cycles.

### Peak Ordering Times

Order volume peaks between 10am and 4pm, with 10–11am representing the busiest window. Volume drops sharply after 6pm. This pattern suggests that stock availability and fulfilment capacity should be prioritised during morning and early afternoon hours.

### Busiest Days of the Week

Monday is the busiest ordering day, followed by Tuesday and Wednesday. Thursday and Friday are the quietest. Saturday maintains a secondary peak, likely reflecting weekend planning behaviour. This weekly rhythm has implications for delivery scheduling and staffing.

### Order Size & Diversity

The average order contains 10 products. The majority of orders fall into the Medium category (6–15 products). Order aisle diversity ranges from 1 to 46 distinct aisles per order — indicating significant variation between focused, habitual shoppers and broad, diverse weekly shops.

### Customer Loyalty Segments

Customers were segmented based on total orders placed. Thresholds were defined by first exploring the distribution (average 16 orders, maximum 100) rather than applying arbitrary values:

- Casual: 1–5 orders
- Regular: 6–25 orders  
- Loyal: 25+ orders

A reorder frequency flag (Weekly/Fortnightly/Monthly+) was also calculated per customer based on average days between orders and is available in the underlying data for future analysis.

## Limitations

- **No fulfilment timestamps** — the dataset captures when orders were placed but not when they were picked, packed or dispatched. This limits operational analysis to demand patterns only. Understanding the gap between order placement and fulfilment would be significantly more valuable for warehouse and workforce planning.

- **No pricing data** — product value cannot be assessed in monetary terms. All volume analysis is based on order counts rather than revenue or margin, which limits commercial conclusions.

- **Anonymised product and customer data** — while this is expected for a public dataset, it prevents any supplier-level or demographic analysis.

- **Dataset originally designed for machine learning** — the Instacart dataset was released as part of a Kaggle basket prediction competition. The train/test split structure and the absence of traditional date columns (replaced with day-of-week and hour-of-day fields) reflect this origin and impose some analytical constraints.

- **Days since prior order capped at 30** — reorder frequency analysis is limited by this ceiling. Customers who reorder less frequently than once a month cannot be accurately distinguished from each other.

- **No date range confirmed** — the dataset does not clearly document the time period it covers, making it impossible to contextualise order volumes against seasonal trends or specific time frames.

## Conclusions & Recommendations

The analysis reveals clear and actionable patterns in Instacart customer reordering behaviour:

- **Stock prioritisation** — fresh produce, particularly fresh fruits and vegetables, should be treated as highest priority inventory. Consistent availability in these aisles directly impacts reorder satisfaction.

- **Demand timing** — ordering peaks Monday to Wednesday, with the busiest window between 10am and 4pm. Fulfilment operations, delivery scheduling and staffing should be weighted toward these windows.

- **Customer base** — the presence of distinct loyalty segments suggests differentiated engagement strategies may be valuable. Loyal customers ordering every few days represent a high-dependency segment where stock outages would have disproportionate impact.

- **Order diversity** — the wide range in order size and aisle diversity (1 to 46 aisles per order) suggests the customer base spans both focused habitual shoppers and broad weekly planners. These two groups likely have different stock sensitivity profiles.

## Future Analysis

- Incorporating fulfilment timestamp data to measure operational performance end-to-end
- Geographical analysis if location data becomes available
- Deeper customer cohort analysis using the reorder frequency segmentation already present in the underlying data

## Files

- `1.Cleaning and nulls.sql` — data type corrections, column removal, null checks and duplicate checks
- `2.Views.sql` — all views created for analysis and Power BI connectivity
- `3.Analysis.sql` — core analysis queries covering reorder patterns, ordering times, order size and customer segmentation
- `Instacart Full.png` — Power BI dashboard screenshot

*This project is an independent analysis using Instacart's publicly available dataset. It is not affiliated with or endorsed by Instacart.*
