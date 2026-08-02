-- Bright Coffee Shop Sales and Product Analysis
 
-- Check columns on data
SELECT *
FROM workspace.default.bright_coffee_shop_sales
LIMIT 10;

-- Check the bumber of rows (149116)
SELECT  COUNT(*) as number_of_rows,
        COUNT (DISTINCT transaction_id) AS user_id
FROM workspace.default.bright_coffee_shop_sales;

-- Create clean table 

CREATE OR REPLACE TABLE workspace.default.bright_coffee_shop_sales_clean AS
SELECT
    transaction_id,
    CAST(transaction_date AS DATE)                                   AS transaction_date,
    CAST(transaction_time AS TIMESTAMP)                               AS transaction_time,
    CAST(transaction_qty AS INT)                                      AS transaction_qty,
    store_id,
    store_location,
    product_id,
    -- fix comma decimals like '3,1' -> 3.1, then cast to decimal
    CAST(REPLACE(unit_price, ',', '.') AS DECIMAL(10,2))              AS unit_price,
    product_category,
    product_type,
    product_detail,

    -- total_amount = unit_price * transaction_qty
    CAST(REPLACE(unit_price, ',', '.') AS DECIMAL(10,2))
        * CAST(transaction_qty AS INT)                                AS total_amount,

    -- 30-minute time bucket, e.g. "07:00-07:30"
    CONCAT(
        LPAD(HOUR(CAST(transaction_time AS TIMESTAMP)), 2, '0'), ':',
        CASE WHEN MINUTE(CAST(transaction_time AS TIMESTAMP)) < 30 THEN '00' ELSE '30' END,
        '-',
        LPAD(HOUR(CAST(transaction_time AS TIMESTAMP)), 2, '0'), ':',
        CASE WHEN MINUTE(CAST(transaction_time AS TIMESTAMP)) < 30 THEN '30' ELSE '00 (next hr)' END
    )                                                                  AS transaction_time_bucket_30min,

    -- 3-hour daypart bucket for a simpler CEO-level view
    CASE
        WHEN HOUR(CAST(transaction_time AS TIMESTAMP)) BETWEEN 6  AND 8  THEN '06:00-09:00 (Early Morning)'
        WHEN HOUR(CAST(transaction_time AS TIMESTAMP)) BETWEEN 9  AND 11 THEN '09:00-12:00 (Late Morning)'
        WHEN HOUR(CAST(transaction_time AS TIMESTAMP)) BETWEEN 12 AND 14 THEN '12:00-15:00 (Early Afternoon)'
        WHEN HOUR(CAST(transaction_time AS TIMESTAMP)) BETWEEN 15 AND 17 THEN '15:00-18:00 (Late Afternoon)'
        WHEN HOUR(CAST(transaction_time AS TIMESTAMP)) BETWEEN 18 AND 20 THEN '18:00-21:00 (Evening)'
        ELSE 'Other'
    END                                                                AS transaction_time_bucket_3hr,

    -- date parts
    DATE_FORMAT(CAST(transaction_date AS DATE), 'EEEE')                AS day_of_week,
    CASE WHEN DAYOFWEEK(CAST(transaction_date AS DATE)) IN (1,7)
         THEN 'Weekend' ELSE 'Weekday' END                             AS day_type,
    DATE_FORMAT(CAST(transaction_date AS DATE), 'yyyy-MM')             AS year_month
FROM workspace.default.bright_coffee_shop_sales;


-- check newly created table
SELECT * 
FROM workspace.default.bright_coffee_shop_sales_clean LIMIT 20;

-- Section 2--
-- 2.1 TOTAL REVENUE PER PRODUCT CATEGORY (which products generate the most revenue)
SELECT
    product_category,
    ROUND(SUM(total_amount), 2)              AS total_revenue,
    SUM(transaction_qty)                      AS total_units_sold,
    COUNT(DISTINCT transaction_id)            AS total_transactions,
    ROUND(SUM(total_amount) / COUNT(DISTINCT transaction_id), 2) AS avg_revenue_per_transaction
FROM workspace.default.bright_coffee_shop_sales_clean
GROUP BY product_category
ORDER BY total_revenue DESC;

-- 2.2 TOP 10 BEST-SELLING PRODUCTS BY REVENUE
SELECT
    product_category,
    product_type,
    product_detail,
    ROUND(SUM(total_amount), 2) AS total_revenue,
    SUM(transaction_qty)         AS total_units_sold
FROM workspace.default.bright_coffee_shop_sales_clean
GROUP BY product_category, product_type, product_detail
ORDER BY total_revenue DESC
LIMIT 10;


-- 2.3 BOTTOM 10 UNDERPERFORMING PRODUCTS BY REVENUE
SELECT
    product_category,
    product_type,
    product_detail,
    ROUND(SUM(total_amount), 2) AS total_revenue,
    SUM(transaction_qty)         AS total_units_sold
FROM workspace.default.bright_coffee_shop_sales_clean
GROUP BY product_category, product_type, product_detail
ORDER BY total_revenue ASC
LIMIT 10;


-- 2.4 REVENUE & TRANSACTIONS BY 3-HOUR DAYPART (what time of day the store performs best)
SELECT
    transaction_time_bucket_3hr,
    ROUND(SUM(total_amount), 2)   AS total_revenue,
    COUNT(DISTINCT transaction_id) AS total_transactions,
    SUM(transaction_qty)           AS total_units_sold,
    ROUND(SUM(total_amount) / COUNT(DISTINCT transaction_id), 2) AS avg_revenue_per_transaction
FROM workspace.default.bright_coffee_shop_sales_clean
GROUP BY transaction_time_bucket_3hr
ORDER BY total_revenue DESC;


-- 2.5 REVENUE BY 30-MINUTE INTERVAL (granular peak-time view)
SELECT
    transaction_time_bucket_30min,
    ROUND(SUM(total_amount), 2)    AS total_revenue,
    COUNT(DISTINCT transaction_id)  AS total_transactions,
    SUM(transaction_qty)            AS total_units_sold
FROM workspace.default.bright_coffee_shop_sales_clean
GROUP BY transaction_time_bucket_30min
ORDER BY total_revenue DESC;


-- 2.6 SALES TREND OVER TIME (monthly revenue trend, Jan-Jun 2023)
SELECT
    year_month,
    ROUND(SUM(total_amount), 2)   AS total_revenue,
    SUM(transaction_qty)           AS total_units_sold,
    COUNT(DISTINCT transaction_id) AS total_transactions
FROM workspace.default.bright_coffee_shop_sales_clean
GROUP BY year_month
ORDER BY year_month;


-- 2.7 SALES TREND BY PRODUCT CATEGORY OVER TIME (which categories are growing/declining)
SELECT
    year_month,
    product_category,
    ROUND(SUM(total_amount), 2) AS total_revenue
FROM workspace.default.bright_coffee_shop_sales_clean
GROUP BY year_month, product_category
ORDER BY product_category, year_month;


-- 2.8 TOTAL UNITS SOLD BY PRODUCT TYPE (quantity view, complements revenue view)
SELECT
    product_type,
    product_category,
    SUM(transaction_qty)          AS total_units_sold,
    ROUND(SUM(total_amount), 2)   AS total_revenue
FROM workspace.default.bright_coffee_shop_sales_clean
GROUP BY product_type, product_category
ORDER BY total_units_sold DESC;


-- Section 3--
-- 3.1 STORE LOCATION PERFORMANCE (which location drives most revenue)

SELECT
    store_location,
    ROUND(SUM(total_amount), 2)   AS total_revenue,
    COUNT(DISTINCT transaction_id) AS total_transactions,
    ROUND(SUM(total_amount) / COUNT(DISTINCT transaction_id), 2) AS avg_revenue_per_transaction
FROM workspace.default.bright_coffee_shop_sales_clean
GROUP BY store_location
ORDER BY total_revenue DESC;


-- 3.2 STORE PERFORMANCE BY DAYPART (does the best time of day differ by store?)
SELECT
    store_location,
    transaction_time_bucket_3hr,
    ROUND(SUM(total_amount), 2)   AS total_revenue,
    COUNT(DISTINCT transaction_id) AS total_transactions
FROM workspace.default.bright_coffee_shop_sales_clean
GROUP BY store_location, transaction_time_bucket_3hr
ORDER BY store_location, total_revenue DESC;


-- 3.3 WEEKDAY VS WEEKEND PERFORMANCE (guides staffing / marketing timing)
SELECT
    day_type,
    ROUND(SUM(total_amount), 2)   AS total_revenue,
    COUNT(DISTINCT transaction_id) AS total_transactions,
    ROUND(SUM(total_amount) / COUNT(DISTINCT transaction_id), 2) AS avg_revenue_per_transaction
FROM workspace.default.bright_coffee_shop_sales_clean
GROUP BY day_type
ORDER BY total_revenue DESC;


-- 3.4 REVENUE BY DAY OF WEEK (identify best/worst days for promos or staffing)
SELECT
    day_of_week,
    ROUND(SUM(total_amount), 2)   AS total_revenue,
    COUNT(DISTINCT transaction_id) AS total_transactions
FROM workspace.default.bright_coffee_shop_sales_clean
GROUP BY day_of_week
ORDER BY total_revenue DESC;


-- 3.5 AVERAGE ORDER VALUE (AOV) BY PRODUCT CATEGORY
-- (categories with high AOV but low transaction count = upsell/bundle opportunity)
SELECT
    product_category,
    COUNT(DISTINCT transaction_id) AS total_transactions,
    ROUND(SUM(total_amount), 2)    AS total_revenue,
    ROUND(AVG(total_amount), 2)    AS avg_order_value
FROM workspace.default.bright_coffee_shop_sales_clean
GROUP BY product_category
ORDER BY avg_order_value DESC;


-- 3.6 PRICE POINT ANALYSIS: which product types have the highest average unit price
-- (candidates for premium positioning / bundling with cheaper items)
SELECT
    product_category,
    product_type,
    ROUND(AVG(unit_price), 2)     AS avg_unit_price,
    SUM(transaction_qty)          AS total_units_sold,
    ROUND(SUM(total_amount), 2)   AS total_revenue
FROM workspace.default.bright_coffee_shop_sales_clean
GROUP BY product_category, product_type
ORDER BY avg_unit_price DESC;


-- 3.7 REVENUE CONTRIBUTION % BY CATEGORY (Pareto view - which categories drive 80% of revenue)
WITH cat_rev AS (
    SELECT product_category, SUM(total_amount) AS total_revenue
    FROM workspace.default.bright_coffee_shop_sales_clean
    GROUP BY product_category
)
SELECT
    product_category,
    ROUND(total_revenue, 2)                                         AS total_revenue,
    ROUND(100 * total_revenue / SUM(total_revenue) OVER (), 2)      AS pct_of_total_revenue,
    ROUND(100 * SUM(total_revenue) OVER (ORDER BY total_revenue DESC
          ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW)
          / SUM(total_revenue) OVER (), 2)                          AS cumulative_pct_revenue
FROM cat_rev
ORDER BY total_revenue DESC;


-- 3.8 SLOWEST TIME SLOTS PER STORE (target for marketing campaigns / promos)
-- Ranks each store's dayparts from lowest to highest revenue
SELECT store_location, transaction_time_bucket_3hr, total_revenue, revenue_rank
FROM (
    SELECT
        store_location,
        transaction_time_bucket_3hr,
        ROUND(SUM(total_amount), 2) AS total_revenue,
        RANK() OVER (PARTITION BY store_location ORDER BY SUM(total_amount) ASC) AS revenue_rank
    FROM workspace.default.bright_coffee_shop_sales_clean
    GROUP BY store_location, transaction_time_bucket_3hr
)
WHERE revenue_rank <= 2   -- 2 slowest dayparts per store
ORDER BY store_location, revenue_rank;


-- 3.9 TOP PRODUCT PER STORE (localize stocking decisions)
SELECT store_location, product_detail, total_revenue, revenue_rank
FROM (
    SELECT
        store_location,
        product_detail,
        ROUND(SUM(total_amount), 2) AS total_revenue,
        RANK() OVER (PARTITION BY store_location ORDER BY SUM(total_amount) DESC) AS revenue_rank
    FROM workspace.default.bright_coffee_shop_sales_clean
    GROUP BY store_location, product_detail
)
WHERE revenue_rank <= 5   -- top 5 products per store
ORDER BY store_location, revenue_rank;


-- 3.10 MONTH-OVER-MONTH REVENUE GROWTH RATE (is the business growing?)
WITH monthly AS (
    SELECT year_month, SUM(total_amount) AS total_revenue
    FROM workspace.default.bright_coffee_shop_sales_clean
    GROUP BY year_month
)
SELECT
    year_month,
    ROUND(total_revenue, 2) AS total_revenue,
    ROUND(total_revenue - LAG(total_revenue) OVER (ORDER BY year_month), 2) AS mom_change,
    ROUND(100 * (total_revenue - LAG(total_revenue) OVER (ORDER BY year_month))
          / LAG(total_revenue) OVER (ORDER BY year_month), 2)               AS mom_pct_change
FROM monthly
ORDER BY year_month;


-- 3.11 UNDERPERFORMING PRODUCTS THAT COULD BENEFIT FROM PROMOTION
-- (low revenue AND low units sold, but still actively selling -> not dead stock, needs a push)
SELECT
    product_category,
    product_type,
    product_detail,
    SUM(transaction_qty)          AS total_units_sold,
    ROUND(SUM(total_amount), 2)   AS total_revenue,
    COUNT(DISTINCT transaction_id) AS total_transactions
FROM workspace.default.bright_coffee_shop_sales_clean
GROUP BY product_category, product_type, product_detail
HAVING total_transactions > 0
ORDER BY total_revenue ASC
LIMIT 15;


