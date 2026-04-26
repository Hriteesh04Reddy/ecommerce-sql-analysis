-- ======================================================================================================================================
-- e-COMMERCE end-to-end Data Analysis Project using SQL
-- Author: Telkala Hriteesh Reddy
-- Dataset: Brazilian Ecommerce (Olist), 2016–2018
-- Database: PostgreSQL (hosted on Supabase)
-- Tool: DBeaver
-- ======================================================================================================================================

-- WHAT THIS PROJECT COVERS:
-- Phase 1: Data Exploration     (blocks 1.1 – 1.6)
-- Phase 2: Business Metrics     (blocks 2.1 – 2.6)
-- Phase 3: Advanced Analytics   (blocks 3.1 – 3.3)

-- =======================================================================================================================================
-- PHASE 1: DATA EXPLORATION
-- ======================================================================================================================================

-- 1.1 Row counts across all tables
-- Purpose: Verify data loaded correctly and understand dataset size

SELECT 'customers'    AS table_name, COUNT(*) AS total_rows FROM customers
UNION ALL
SELECT 'sellers',     COUNT(*) FROM sellers
UNION ALL
SELECT 'products',    COUNT(*) FROM products
UNION ALL
SELECT 'orders',      COUNT(*) FROM orders
UNION ALL
SELECT 'order_items', COUNT(*) FROM order_items
UNION ALL
SELECT 'payments',    COUNT(*) FROM payments
UNION ALL
SELECT 'reviews',     COUNT(*) FROM reviews;

/*
FINDINGS 1.1:
- Dataset contains 99,441 customers and 99,441 orders — a 1:1 ratio,
  meaning each customer placed exactly one order in this dataset.
- order_items (112,650) > orders (99,441), confirming some orders
  contain multiple items.
- payments (103,886) > orders, meaning some orders have multiple
  payment entries (e.g. part card, part voucher).
- reviews (3,038) is very low — only ~3% of orders have a review.
- sellers (3,095) and products (32,951) show a diverse marketplace.
*/
-- ==================================================================================

-- 1.2 Date range of orders
-- Purpose: Understand the time period this data covers

SELECT
    MIN(order_purchase_timestamp) AS earliest_order,
    MAX(order_purchase_timestamp) AS latest_order,
    COUNT(DISTINCT DATE_TRUNC('month', order_purchase_timestamp)) AS total_months
FROM orders;

/*
FINDINGS 1.2:
- Data spans September 2016 to October 2018 — approximately 25 months.
- This gives us enough time to observe seasonal trends and month-over-month
  growth patterns in Phase 3.
*/
--=====================================================================================

-- 1.3 Order status distribution
-- Purpose: See what proportion of orders are delivered, cancelled, etc.

select order_status,
    COUNT(*) AS total_orders,
    ROUND(COUNT(*) * 100.0 / SUM(COUNT(*)) OVER (), 2) AS percentage
FROM orders
GROUP BY order_status
ORDER BY total_orders DESC;

/*
- 97.02% of orders are delivered — indicating a highly reliable
  fulfillment pipeline.
- Only 0.63% of orders were cancelled — a healthy cancellation rate
  for an ecommerce platform.
- 1.11% are still in "shipped" status, likely orders placed close
  to the dataset cutoff date (Oct 2018).
*/
--====================================================================================

-- 1.4 Null value check on orders table
-- Purpose: Identify missing data that could affect analysis

SELECT
    COUNT(*) AS total_rows,
    COUNT(*) - COUNT(order_approved_at)               AS nulls_in_orders_approved_at,
    COUNT(*) - COUNT(order_delivered_carrier_date)    AS nulls_in_carrier_date,
    COUNT(*) - COUNT(order_delivered_customer_date)   AS nulls_in_customer_date
FROM orders;
--======================================================================================

-- 1.5 Payment method breakdown
-- Purpose: Understand how customers prefer to pay

SELECT
    payment_type,
    COUNT(*) AS total_payments,
    ROUND(AVG(payment_value), 2) AS avg_payment_value,
    ROUND(AVG(payment_installments), 1) AS avg_installments
FROM payments
GROUP BY payment_type
ORDER BY total_payments DESC;

/*
FINDINGS:
- Credit card is the dominant payment method (76,795 transactions)
  accounting for ~74% of all payments.
- Credit card users spend the most on average ($163.32) and use
  3.5 installments on average, indicating customers use installment
  plans for larger purchases.
- Boleto (a Brazilian bank slip payment) is second with 19,784
  transactions at $145.03 average, popular for customers without
  credit access.
- Vouchers have the lowest average value ($65.70)
*/
--========================================================================================
-- 1.6 Review score distribution
-- Purpose: Understand overall customer satisfaction

SELECT
    review_score,
    COUNT(*) AS total_reviews,
    ROUND(COUNT(*) * 100.0 / SUM(COUNT(*)) OVER (), 2) AS percentage
FROM reviews
GROUP BY review_score
ORDER BY review_score DESC;

/*
- Customer satisfaction is strongly positive. 59.55% gave a 5-star
  review and 18.2% gave 4 stars - nearly 78% of reviewers are satisfied.
- 10.8% gave a 1-star review, the second largest group, suggesting
  a polarised experience: customers either love it or are very unhappy.
- Very few customers rated 2 or 3 stars (combined ~11.5%), which is
  typical of ecommerce platforms where customers tend to rate at extremes.
- NOTE: Only 3,038 out of 99,441 orders have reviews (~3%).
  Findings here represent a small sample and may not reflect the full customer base.
*/

-- ==================================================================================================================================
-- PHASE 2: BUSINESS METRICS
-- ===================================================================================================================================

-- 2.1 Revenue by customer state
-- Purpose: Identify which states drive the most revenue
--=======================================================================================
SELECT
    c.customer_state,
    COUNT(DISTINCT o.order_id)   AS total_orders,
    ROUND(SUM(p.payment_value)::NUMERIC, 2) AS total_revenue,
    ROUND(AVG(p.payment_value)::NUMERIC, 2) AS avg_order_value
FROM orders o
JOIN customers c  ON o.customer_id  = c.customer_id
JOIN payments  p  ON o.order_id     = p.order_id
WHERE o.order_status = 'delivered'
GROUP BY c.customer_state
ORDER BY total_revenue DESC;
/*
FINDINGS 2.1 — Revenue by customer state:
- SP (São Paulo) alone generates R$5.77M from 40,500 orders — 
  more than the next 4 states combined. Clear demand concentration.
- RJ has the highest avg order value (R$158) among top states,
  suggesting a higher-spending customer base despite fewer orders than SP.
- Top 3 states (SP, RJ, MG) account for the majority of platform revenue —
  logistics and marketing investment here has the highest ROI.
*/
-- ======================================================================================
-- 2.2 Revenue by product category
-- Purpose: Find which product categories generate the most sales
-- ======================================================================================

select product_category_name,
    COUNT(DISTINCT oi.order_id)             AS total_orders,
    ROUND(SUM(oi.price)::NUMERIC, 2)        AS total_revenue,
    ROUND(AVG(oi.price)::NUMERIC, 2)        AS avg_item_price
FROM order_items oi
JOIN products pr ON oi.product_id = pr.product_id
JOIN orders   o  ON oi.order_id   = o.order_id
WHERE o.order_status = 'delivered'
GROUP BY pr.product_category_name
ORDER BY total_revenue DESC
LIMIT 10;

/*
FINDINGS 2.2 — Revenue by product category:
- beleza_saude (beauty & health) leads with R$1.23M across 8,647 orders —
  high volume, mid-range pricing (R$130 avg).
- The second category (likely health/perfumery) has only 199 avg item price
  but R$1.16M revenue — fewer but more expensive items.
- cama_mesa_banho (bed/bath) is third with the lowest avg price (R$93),
  succeeding purely on volume (9,272 orders).
- Categories like cool_stuff command R$164 avg price, suggesting niche
  but premium demand.
*/

--======================================================================================
-- 2.3 Top 10 sellers by revenue and order volume
-- Purpose: Identify best performing sellers on the platform
-- Concepts used: JOIN, GROUP BY, LIMIT
--=======================================================================================

SELECT
    s.seller_id,
    s.seller_city,
    s.seller_state,
    COUNT(DISTINCT oi.order_id)         AS total_orders,
    SUM(oi.price)::NUMERIC::INT         AS total_revenue,
    ROUND(AVG(oi.price)::NUMERIC, 2)    AS avg_item_price
FROM order_items oi
JOIN sellers s ON oi.seller_id = s.seller_id
JOIN orders  o ON oi.order_id  = o.order_id
WHERE o.order_status = 'delivered'
GROUP BY s.seller_id, s.seller_city, s.seller_state
ORDER BY total_revenue DESC
LIMIT 10;
/*
FINDINGS 2.3 — Top 10 sellers by revenue:
- Top seller (Guariba, SP) leads with R$226,988 from 1,124 orders
  at R$197 avg — strong volume with healthy margins.
- The seller from Lauro de Freitas (BA) ranks 2nd in revenue with
  only 348 orders at R$544 avg — high-value, low-volume model.
  Likely selling premium or expensive products.
- 8 out of 9 visible top sellers are from SP — confirms São Paulo
  as the dominant seller hub on the platform.
*/


-- =====================================================================
-- 2.4 On-time vs late delivery breakdown by customer state
-- Purpose: Find which states have the worst delivery experience
-- =====================================================================

SELECT
    c.customer_state,
    COUNT(*)                                            AS total_orders,

    COUNT(CASE WHEN o.order_delivered_customer_date 
               <= o.order_estimated_delivery_date 
               THEN 1 END)                             AS on_time,

    COUNT(CASE WHEN o.order_delivered_customer_date 
               > o.order_estimated_delivery_date 
               THEN 1 END)                             AS late,

    ROUND(COUNT(CASE WHEN o.order_delivered_customer_date 
                     > o.order_estimated_delivery_date 
                     THEN 1 END) * 100.0 / COUNT(*), 2) AS late_rate_percent

FROM orders o
JOIN customers c ON o.customer_id = c.customer_id
WHERE o.order_status = 'delivered'
  AND o.order_delivered_customer_date IS NOT NULL
GROUP BY c.customer_state
ORDER BY late_rate_percent DESC
LIMIT 10;

/*
FINDINGS 2.4 — Late delivery rate by state:
- AL (Alagoas) has the worst late rate at 21.41% — 1 in 5 orders
  arrives late. Remote northeastern states dominate the top of this list.
- RJ appears at rank 8 with 12.11% late rate despite being the 2nd
  largest market — a scale problem worth flagging.
- Pattern is clear: northern and northeastern states (AL, MA, SE, PI, CE)
  consistently underperform on delivery — likely due to infrastructure
  and distance from SP-based seller hubs.
*/

-- ==============================================================
-- 2.5 Payment behaviour by method
-- Purpose: Understand how payment method relates to order size
-- =============================================================

SELECT
    payment_type,
    COUNT(*)                                    AS total_transactions,
    ROUND(SUM(payment_value)::NUMERIC, 2)       AS total_revenue,
    ROUND(AVG(payment_value)::NUMERIC, 2)       AS avg_payment_value,
    ROUND(AVG(payment_installments)::NUMERIC,1) AS avg_installments,
    MAX(payment_installments)                   AS max_installments
FROM payments
WHERE payment_type != 'not_defined'
GROUP BY payment_type
ORDER BY total_revenue DESC;

/*
FINDINGS 2.5 — Payment behaviour:
- Credit card drives 74% of transactions and 78% of total revenue (R$12.54M).
  Avg 3.5 installments indicates customers rely on splitting large purchases.
- Boleto is a strong second (19,784 transactions) — relevant for customers
  without credit access, a significant demographic in Brazil.
- Vouchers average only R$65.70 — used primarily as discount top-ups,
  not standalone payment.
- Debit card barely registers (1,529 transactions) — near-irrelevant channel.
*/

-- =======================================================================
-- 2.6 Does faster delivery lead to better reviews?
-- Purpose: Finding relationship between delivery speed and satisfaction
-- This is one of the most insight-rich queries in the project
-- =======================================================================

SELECT
    r.review_score,
    COUNT(*)                                        AS total_orders,

    ROUND(AVG(
        EXTRACT(EPOCH FROM (
            o.order_delivered_customer_date - 
            o.order_purchase_timestamp
        )) / 86400
    )::NUMERIC, 1)                                  AS avg_delivery_days,

    ROUND(AVG(
        EXTRACT(EPOCH FROM (
            o.order_estimated_delivery_date - 
            o.order_delivered_customer_date
        )) / 86400
    )::NUMERIC, 1)                                  AS no_of_days_arrived_earlier
    -- positive = delivered early relative to estimate

FROM orders o
JOIN reviews r ON o.order_id = r.order_id
WHERE o.order_status = 'delivered'
  AND o.order_delivered_customer_date IS NOT NULL
GROUP BY r.review_score
ORDER BY r.review_score DESC;

/*
FINDINGS 2.6 — Delivery speed vs review score:
- A clear, consistent inverse relationship between delivery time and satisfaction.
- 5-star orders: delivered in 10.7 days, arrived 13.1 days early.
- 1-star orders: delivered in 20.2 days, arrived only 5.1 days early.
- Customers who rated 1-star waited nearly twice as long as 5-star customers.
*/

-- ==================================================================================================================================
-- PHASE 3: ADVANCED ANALYTICS
-- ==================================================================================================================================

-- 3.1 Monthly revenue trend over time
-- Purpose: Identify platform growth trajectory and seasonal patterns
-- Concepts: DATE_TRUNC, window functions, LAG()
-- LAG() looks at the previous row's value — here used to calculate
-- month-over-month revenue growth rate
--======================================================================

WITH monthly_revenue AS (
    SELECT
        DATE_TRUNC('month', o.order_purchase_timestamp) AS order_month,
        COUNT(DISTINCT o.order_id)                       AS total_orders,
        ROUND(SUM(p.payment_value)::NUMERIC, 2)          AS revenue
    FROM orders o
    JOIN payments p ON o.order_id = p.order_id
    WHERE o.order_status = 'delivered'
    GROUP BY DATE_TRUNC('month', o.order_purchase_timestamp)
)
SELECT
    TO_CHAR(order_month, 'YYYY-MM')       AS month,
    total_orders,
    revenue,
    LAG(revenue) OVER (ORDER BY order_month) AS prev_month_revenue,
    ROUND(
        (revenue - LAG(revenue) OVER (ORDER BY order_month))
        * 100.0
        / NULLIF(LAG(revenue) OVER (ORDER BY order_month), 0)
    , 1)                                  AS mom_growth_percent
    -- mom = month over month
    -- NULLIF prevents division by zero on the first row
FROM monthly_revenue
ORDER BY order_month;

/*
FINDINGS 3.1 — Monthly revenue trend:
- Clear growth trajectory from R$46K (Oct 2016) to ~R$1M+ per month by 2018 —
  platform scaled roughly 20x in under 2 years.
- Nov 2017 is the standout spike (R$1.15M, +53.6% MoM). Immediately followed by a -26.9% drop in Dec,
  confirming it was a demand pull-forward, not sustained growth.
- Platform hit a revenue ceiling around R$1M–R$1.13M from Jan–Aug 2018,
  with growth fluctuating between -10% and +16% — signs of market maturation.
- Overall trend: rapid hyper-growth phase (late 2016 – mid 2017),
  followed by stabilisation (2018). A healthy pattern for a scaling marketplace.
*/

--===================================================================
-- 3.2 Seller performance ranking
-- Purpose: Tier all sellers by revenue and compare to their peers
-- Concepts: RANK(), DENSE_RANK(), NTILE(), CTEs
--
-- RANK()       — gives rank 1,2,3 but skips numbers on ties (1,2,2,4)
-- DENSE_RANK() — gives rank 1,2,3 without skipping (1,2,2,3)
-- NTILE(4)     — splits sellers into 4 equal buckets (quartiles)
--                quartile 1 = top 25%, quartile 4 = bottom 25%
--====================================================================

WITH seller_metrics AS (
    SELECT
        s.seller_id,
        s.seller_city,
        s.seller_state,
        COUNT(DISTINCT oi.order_id)           AS total_orders,
        ROUND(SUM(oi.price)::NUMERIC, 2)      AS total_revenue,
        ROUND(AVG(oi.price)::NUMERIC, 2)      AS avg_item_price,
        ROUND(AVG(r.review_score)::NUMERIC, 2) AS avg_review_score
    FROM order_items oi
    JOIN sellers  s ON oi.seller_id = s.seller_id
    JOIN orders   o ON oi.order_id  = o.order_id
    LEFT JOIN reviews r ON o.order_id = r.order_id
    WHERE o.order_status = 'delivered'
    GROUP BY s.seller_id, s.seller_city, s.seller_state
)
SELECT
    seller_id,
    seller_city,
    seller_state,
    total_orders,
    total_revenue,
    avg_item_price,
    avg_review_score,
    RANK()       OVER (ORDER BY total_revenue DESC) AS revenue_rank,
    DENSE_RANK() OVER (ORDER BY total_revenue DESC) AS revenue_dense_rank,
    NTILE(4)     OVER (ORDER BY total_revenue DESC) AS revenue_quartile
    -- quartile 1 = top performers, quartile 4 = weakest sellers
FROM seller_metrics
ORDER BY revenue_rank
LIMIT 20;

/*
FINDINGS 3.2 — Seller performance ranking:
- SP dominates: 16 of the top 20 sellers are from São Paulo state,
  reinforcing it as the platform's operational and commercial hub.
- High revenue doesn't always mean high volume — the Lauro de Freitas (BA)
  seller ranks 2nd with only 348 orders at R$544 avg item price, nearly
  3x the avg of the top seller (R$197). Two distinct winning strategies:
  high volume vs high ticket size.
*/
--===================================================================
-- 3.3 Delivery time analysis — estimated vs actual
-- Purpose: Categorise every order by how early/late it arrived
--          and measure impact on review scores
-- Concepts: CASE WHEN bucketing, CTEs, EXTRACT(EPOCH)
--===================================================================

WITH delivery_analysis AS (
    SELECT
        o.order_id,
        o.customer_id,
        o.order_status,

        ROUND(EXTRACT(EPOCH FROM (
            o.order_delivered_customer_date -
            o.order_purchase_timestamp
        )) / 86400::NUMERIC, 1)              AS actual_delivery_days,

        ROUND(EXTRACT(EPOCH FROM (
            o.order_estimated_delivery_date -
            o.order_purchase_timestamp
        )) / 86400::NUMERIC, 1)              AS estimated_delivery_days,

        ROUND(EXTRACT(EPOCH FROM (
            o.order_estimated_delivery_date -
            o.order_delivered_customer_date
        )) / 86400::NUMERIC, 1)              AS days_early_or_late,
        -- positive = early, negative = late

        r.review_score

    FROM orders o
    LEFT JOIN reviews r ON o.order_id = r.order_id
    WHERE o.order_status = 'delivered'
      AND o.order_delivered_customer_date IS NOT NULL
      AND o.order_estimated_delivery_date IS NOT NULL
),
categorised AS (
    SELECT *,
        CASE
            WHEN days_early_or_late >= 7  THEN '1. Very early (7+ days)'
            WHEN days_early_or_late >= 1  THEN '2. Early (1-6 days)'
            WHEN days_early_or_late >= -3 THEN '3. On time (0 to -3 days)'
            ELSE                               '4. Late (3+ days late)'
        END AS delivery_category
    FROM delivery_analysis
)
SELECT
    delivery_category,
    COUNT(*)                                    AS total_orders,
    ROUND(COUNT(*) * 100.0 /
          SUM(COUNT(*)) OVER (), 2)             AS pct_of_orders,
    ROUND(AVG(actual_delivery_days)::NUMERIC,1) AS avg_actual_days,
    ROUND(AVG(review_score)::NUMERIC, 2)        AS avg_review_score
FROM categorised
GROUP BY delivery_category
ORDER BY delivery_category;

/*
FINDINGS 3.3 — Delivery time analysis (estimated vs actual):
- 78.93% of orders arrived 7+ days early with a 4.31 avg review score —
  the platform systematically over-estimates delivery time, which works
  heavily in its favour for customer satisfaction.
- The satisfaction cliff is stark: on-time orders (0 to -3 days) score
  only 3.54, and late orders collapse to 2.03 — nearly half the score
  of very early deliveries. Being just slightly late is severely punished.
 - Key insight: the platform's strategy of conservative delivery estimates
  is a deliberate satisfaction driver. When that buffer fails, customer
  experience deteriorates sharply.
*/
