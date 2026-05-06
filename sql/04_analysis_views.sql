-- =========================================================================
-- 04_analysis_views.sql
-- Project: Olist Brazilian E-Commerce Analysis
-- Purpose: Build 11 analytical views that answer the project's core
--          business questions. These views are the data layer that the
--          Power BI dashboard imports from.
-- Run order: This file should be executed LAST.
-- 
-- View categories:
--   - Revenue & sales: monthly trend, by category, by state
--   - Customer behavior: payment distribution, review scores by category
--   - Operational: delivery time, order status, top sellers
--   - Cross-cutting: late delivery impact, raw views for proper DAX averaging
-- 
-- Design notes:
--   - Pre-aggregated views are preferred where Power BI doesn't need raw rows
--   - Two "raw" views (review_by_delivery_status_raw, delivery_time_per_order)
--     are exposed without aggregation so DAX can compute weighted averages
--     correctly (avoiding the average-of-averages bias)
-- =========================================================================

USE olist;

-- =========================================================================
-- 1. Monthly revenue trend
-- Question: How did Olist's revenue evolve month over month?
-- =========================================================================
CREATE VIEW analysis_monthly_revenue AS
SELECT 
    DATE_FORMAT(o.order_purchase_timestamp, '%Y-%m') AS month, 
    SUM(oi.price) AS total_revenue, 
    COUNT(DISTINCT o.order_id) AS order_count
FROM orders o
INNER JOIN order_items oi
    ON oi.order_id = o.order_id
GROUP BY month
ORDER BY month;

-- =========================================================================
-- 2. Top categories by revenue
-- Question: Which product categories drive the most revenue?
-- Excludes canceled and unavailable orders to reflect realized revenue.
-- =========================================================================
CREATE VIEW analysis_top_categories AS
SELECT pcnt.product_category_name_english, 
    SUM(oi.price) AS total_revenue, 
    COUNT(DISTINCT oi.order_id) AS number_of_orders
FROM product_category_name_translation pcnt
INNER JOIN products p
    ON p.product_category_name = pcnt.product_category_name
INNER JOIN order_items oi
    ON p.product_id = oi.product_id
INNER JOIN orders o
    ON oi.order_id = o.order_id
WHERE o.order_status NOT IN ('canceled', 'unavailable')
GROUP BY pcnt.product_category_name_english
ORDER BY total_revenue DESC;

-- =========================================================================
-- 3. Revenue and orders by state
-- Question: Where in Brazil is revenue concentrated?
-- =========================================================================
CREATE VIEW analysis_revenue_orders_by_state AS
SELECT c.customer_state, 
    SUM(oi.price) AS total_revenue, 
    COUNT(DISTINCT oi.order_id) AS number_of_orders
FROM customers c
INNER JOIN orders o
    ON c.customer_id = o.customer_id
INNER JOIN order_items oi
    ON o.order_id = oi.order_id
WHERE o.order_status NOT IN ('canceled', 'unavailable')
GROUP BY c.customer_state
ORDER BY total_revenue DESC;

-- =========================================================================
-- 4. Average review score by category
-- Question: Which categories have the happiest / unhappiest customers?
-- review_count is included so categories with very few reviews can be
-- evaluated cautiously in the dashboard.
-- =========================================================================
CREATE VIEW analysis_average_review_by_category AS
SELECT pcnt.product_category_name_english, 
    COUNT(orc.review_score) AS review_count,
    ROUND(AVG(orc.review_score), 2) AS average_review_score
FROM product_category_name_translation pcnt
INNER JOIN products p
    ON p.product_category_name = pcnt.product_category_name
INNER JOIN order_items oi
    ON p.product_id = oi.product_id
INNER JOIN order_reviews_clean orc
    ON oi.order_id = orc.order_id
INNER JOIN orders o
    ON orc.order_id = o.order_id
WHERE o.order_status NOT IN ('canceled', 'unavailable')
GROUP BY pcnt.product_category_name_english
ORDER BY average_review_score DESC;

-- =========================================================================
-- 5. Payment method distribution
-- Question: How do Brazilian customers pay, and what value flows through
-- each method?
-- =========================================================================
CREATE VIEW analysis_payment_distribution AS
SELECT op.payment_type, 
    SUM(op.payment_value) AS total_value,
    COUNT(DISTINCT o.order_id) AS number_of_orders
FROM order_payments op
INNER JOIN orders o
    ON op.order_id = o.order_id
WHERE o.order_status NOT IN ('canceled', 'unavailable')
GROUP BY op.payment_type;

-- =========================================================================
-- 6. Average delivery time by state (actual vs estimated)
-- Question: How long does Olist actually take to deliver, and how does
-- that compare to what they promise customers?
-- =========================================================================
CREATE VIEW analysis_avg_delivery_time AS
SELECT c.customer_state,
    COUNT(DISTINCT odc.order_id) AS orders_numbers,
    ROUND(AVG(TIMESTAMPDIFF(DAY, order_purchase_timestamp, order_delivered_customer_date)), 2) AS Actual_delivery_days,
    ROUND(AVG(TIMESTAMPDIFF(DAY, order_purchase_timestamp, order_estimated_delivery_date)), 2) AS Estimated_delivery_days
FROM customers c
INNER JOIN orders_delivered_clean odc
    ON c.customer_id = odc.customer_id
GROUP BY c.customer_state
ORDER BY Actual_delivery_days DESC;

-- =========================================================================
-- 7. Late delivery impact on review scores (THE HEADLINE INSIGHT)
-- Question: Do late deliveries actually hurt customer satisfaction?
-- Answer: Yes — by ~1.7 stars on average.
-- =========================================================================
CREATE VIEW analysis_late_delivery_impact AS
SELECT 
    CASE 
        WHEN order_delivered_customer_date > order_estimated_delivery_date THEN 'Late'
        ELSE 'On Time'
    END AS delivery_status,
    COUNT(DISTINCT odc.order_id) AS number_of_orders,
    ROUND(AVG(orc.review_score), 2) AS average_review_score
FROM orders_delivered_clean odc
INNER JOIN order_reviews_clean orc
    ON odc.order_id = orc.order_id
GROUP BY delivery_status;

-- =========================================================================
-- 8. Order status breakdown
-- Question: What does the order pipeline look like? How many succeed
-- vs fail at each stage?
-- =========================================================================
CREATE VIEW analysis_order_status_breakdown AS
SELECT 
    order_status,
    COUNT(*) AS order_count,
    ROUND(COUNT(*) * 100.0 / (SELECT COUNT(*) FROM orders), 2) AS percentage
FROM orders
GROUP BY order_status;

-- =========================================================================
-- 9. Top sellers by revenue with delivery performance
-- Question: Who are the top earners on the platform, and how reliable
-- are they on delivery?
-- 
-- Implementation note: The on_time_orders / late_orders counts use
-- COUNT(DISTINCT CASE WHEN ... THEN order_id END) rather than 
-- SUM(CASE WHEN ... THEN 1 ELSE 0 END), because the latter would 
-- double-count orders that contain multiple items. This was caught 
-- during QA when on_time + late summed to more than total_orders.
-- =========================================================================
CREATE VIEW analysis_top_sellers AS
SELECT s.seller_id, 
    SUM(oi.price) AS total_revenue, 
    COUNT(DISTINCT odc.order_id) AS total_orders,
    COUNT(DISTINCT CASE WHEN odc.order_delivered_customer_date <= odc.order_estimated_delivery_date THEN odc.order_id END) AS on_time_orders,
    COUNT(DISTINCT CASE WHEN odc.order_estimated_delivery_date < odc.order_delivered_customer_date THEN odc.order_id END) AS late_orders,
    ROUND(
        COUNT(DISTINCT CASE WHEN odc.order_delivered_customer_date <= odc.order_estimated_delivery_date 
                            THEN odc.order_id END) * 100.0
        / COUNT(DISTINCT odc.order_id)
    , 2) AS on_time_rate_pct
FROM sellers s
INNER JOIN order_items oi
    ON s.seller_id = oi.seller_id
INNER JOIN orders_delivered_clean odc
    ON oi.order_id = odc.order_id
GROUP BY s.seller_id
ORDER BY total_revenue DESC;

-- =========================================================================
-- 10. Reviews by delivery status (RAW — for proper DAX averaging)
-- One row per delivered order with review. No aggregation. This view
-- exists so Power BI's AVERAGE function computes a true overall mean
-- weighted by the number of reviews, not an average-of-averages.
-- =========================================================================
CREATE VIEW analysis_review_by_delivery_status_raw AS
SELECT c.customer_state, 
    odc.order_id, 
    orc.review_score,
    CASE 
        WHEN odc.order_delivered_customer_date > odc.order_estimated_delivery_date THEN 'Late'
        ELSE 'On Time'
    END AS delivery_status
FROM orders_delivered_clean odc
INNER JOIN order_reviews_clean orc
    ON odc.order_id = orc.order_id
INNER JOIN customers c
    ON c.customer_id = odc.customer_id;

-- =========================================================================
-- 11. Delivery time per order (RAW — for proper DAX averaging)
-- One row per delivered order with actual and estimated delivery days.
-- Same purpose as the previous raw view: gives DAX the per-order data
-- needed for correct weighted averages.
-- =========================================================================
CREATE VIEW analysis_delivery_time_per_order AS
SELECT odc.order_id, 
    c.customer_state,
    TIMESTAMPDIFF(DAY, odc.order_purchase_timestamp, odc.order_delivered_customer_date) AS Actual_delivery_days,
    TIMESTAMPDIFF(DAY, odc.order_purchase_timestamp, odc.order_estimated_delivery_date) AS Estimated_delivery_days
FROM orders_delivered_clean odc
INNER JOIN customers c
    ON c.customer_id = odc.customer_id;
