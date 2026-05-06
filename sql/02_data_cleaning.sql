-- =========================================================================
-- 02_data_cleaning.sql
-- Project: Olist Brazilian E-Commerce Analysis
-- Purpose: Audit and clean the imported data. Identify duplicates, NULLs,
--          corrupt date placeholders, and logical inconsistencies, then
--          create cleaning views that downstream analysis depends on.
-- Run order: This file should be executed SECOND, after 01_setup_and_import.
-- 
-- Approach: Raw tables are NOT modified destructively where possible.
--           Instead, cleaning logic is layered as views on top. Only
--           UPDATE statements that fix corrupt zero-date placeholders touch
--           the underlying tables, and those changes are reversible
--           conceptually (zero-date -> NULL is a normalization, not a loss).
-- =========================================================================

USE olist;

-- =========================================================================
-- DUPLICATE AUDIT
-- Verify primary key uniqueness assumptions for each table.
-- =========================================================================

-- Orders: confirmed unique by order_id (returns 0 rows)
SELECT order_id, COUNT(*) AS orders_count
FROM orders
GROUP BY order_id
HAVING orders_count > 1;

-- Customers: confirmed unique by customer_id (returns 0 rows)
SELECT customer_id, COUNT(*) AS customers_count
FROM customers
GROUP BY customer_id
HAVING customers_count > 1;

-- Order_items: expected to have multiple rows per order_id (one per product)
SELECT order_id, COUNT(*) AS orders_count
FROM order_items
GROUP BY order_id
HAVING orders_count > 1;

-- Order_payments: expected to have multiple rows for split payments / installments
SELECT order_id, COUNT(*) AS orders_count
FROM order_payments
GROUP BY order_id
HAVING orders_count > 1;

-- Order_reviews: expected to be one-per-order, but found 553 duplicates.
-- Investigation showed these are real customer resubmissions (different review_id,
-- same order_id, slightly different timestamps and scores).
SELECT order_id, COUNT(*) AS orders_count
FROM order_reviews
GROUP BY order_id
HAVING orders_count > 1
ORDER BY orders_count DESC
LIMIT 5;

-- Sample inspection of a duplicated order
SELECT * FROM order_reviews
WHERE order_id = 'c88b1d1b157a9999ce368f218a407141';

-- -------------------------------------------------------------------------
-- CLEANING VIEW: order_reviews_clean
-- Resolution: keep only the LATEST review per order_id, using a window
-- function. The latest submission represents the customer's final opinion.
-- -------------------------------------------------------------------------
CREATE VIEW order_reviews_clean AS
SELECT review_id, 
       order_id, 
       review_score, 
       review_comment_title, 
       review_comment_message,
       review_creation_date, 
       review_answer_timestamp
FROM (
    SELECT *,
        ROW_NUMBER() OVER (PARTITION BY order_id ORDER BY review_creation_date DESC) AS rn
    FROM order_reviews
) t
WHERE rn = 1;

-- =========================================================================
-- ZERO-DATE FIX
-- Several DATETIME columns contain '0000-00-00 00:00:00' placeholders
-- where the source CSV had empty cells. These are not detected by IS NULL
-- and would corrupt date arithmetic. Convert them to true NULLs.
-- =========================================================================

-- Orders table
UPDATE orders
SET order_approved_at = NULL
WHERE order_approved_at = '0000-00-00 00:00:00';

UPDATE orders
SET order_delivered_carrier_date = NULL
WHERE order_delivered_carrier_date = '0000-00-00 00:00:00';

UPDATE orders
SET order_delivered_customer_date = NULL
WHERE order_delivered_customer_date = '0000-00-00 00:00:00';

-- Order_reviews table
UPDATE order_reviews
SET review_creation_date = NULL
WHERE review_creation_date = '0000-00-00 00:00:00';

UPDATE order_reviews
SET review_answer_timestamp = NULL
WHERE review_answer_timestamp = '0000-00-00 00:00:00';

-- =========================================================================
-- NULL AUDIT (post-fix)
-- Verify NULLs are now properly recognized and check distribution by status.
-- Findings: NULL date columns correlate logically with order_status
-- (e.g., 'unavailable' orders have NULL delivery dates because they were
-- never shipped). NULLs are business-meaningful, not data errors.
-- =========================================================================

SELECT COUNT(*) AS total_orders,
    SUM(CASE WHEN order_approved_at IS NULL THEN 1 ELSE 0 END) AS null_approved,
    SUM(CASE WHEN order_delivered_carrier_date IS NULL THEN 1 ELSE 0 END) AS null_carrier,
    SUM(CASE WHEN order_delivered_customer_date IS NULL THEN 1 ELSE 0 END) AS null_delivered
FROM orders;

-- NULLs broken down by order status
SELECT order_status, 
    SUM(CASE WHEN order_approved_at IS NULL THEN 1 ELSE 0 END) AS null_approved,
    SUM(CASE WHEN order_delivered_carrier_date IS NULL THEN 1 ELSE 0 END) AS null_carrier,
    SUM(CASE WHEN order_delivered_customer_date IS NULL THEN 1 ELSE 0 END) AS null_delivered
FROM orders
GROUP BY order_status;

-- Among orders marked as 'delivered', confirm timestamp completeness
-- (only ~24 delivered orders have any missing timestamps)
SELECT order_status,
    SUM(CASE WHEN order_purchase_timestamp IS NULL THEN 1 ELSE 0 END) AS null_purchase,
    SUM(CASE WHEN order_approved_at IS NULL THEN 1 ELSE 0 END) AS null_approved_at,
    SUM(CASE WHEN order_delivered_carrier_date IS NULL THEN 1 ELSE 0 END) AS null_delivered_carrier_date,
    SUM(CASE WHEN order_delivered_customer_date IS NULL THEN 1 ELSE 0 END) AS null_delivered_customer_date,
    SUM(CASE WHEN order_estimated_delivery_date IS NULL THEN 1 ELSE 0 END) AS null_estimated_delivery_date
FROM orders
WHERE order_status = 'delivered';

-- -------------------------------------------------------------------------
-- CLEANING VIEW: orders_delivered_clean
-- Filtered to delivered orders only, with all four key timestamps present.
-- This is the foundation for any delivery time analysis.
-- -------------------------------------------------------------------------
CREATE VIEW orders_delivered_clean AS
SELECT order_id,
       customer_id,
       order_status,
       order_purchase_timestamp,
       order_approved_at,
       order_delivered_carrier_date,
       order_delivered_customer_date,
       order_estimated_delivery_date
FROM orders
WHERE order_status = 'delivered'
  AND order_approved_at IS NOT NULL
  AND order_delivered_carrier_date IS NOT NULL
  AND order_delivered_customer_date IS NOT NULL;

-- =========================================================================
-- LOGICAL INCONSISTENCY CHECK
-- Verify that timestamps progress in the expected order.
-- Findings:
--   - 0 orders had approval before purchase (clean)
--   - 1,359 orders had carrier date before approval date — likely a real
--     business pipeline quirk (sellers shipping before formal approval)
--   - 23 orders had delivered date before carrier date — likely logging
--     errors (very small fraction, retained for analysis)
-- =========================================================================
SELECT
    SUM(CASE WHEN order_approved_at < order_purchase_timestamp THEN 1 ELSE 0 END) AS wrong_purchase_timestamp,
    SUM(CASE WHEN order_delivered_carrier_date < order_approved_at THEN 1 ELSE 0 END) AS wrong_approval,
    SUM(CASE WHEN order_delivered_customer_date < order_delivered_carrier_date THEN 1 ELSE 0 END) AS wrong_delivered_carrier_date
FROM orders;

-- Investigate the magnitude of the carrier-before-approval gap
SELECT 
    AVG(TIMESTAMPDIFF(MINUTE, order_approved_at, order_delivered_carrier_date)) AS avg_gap_minutes,
    MIN(TIMESTAMPDIFF(MINUTE, order_approved_at, order_delivered_carrier_date)) AS min_gap_minutes
FROM orders_delivered_clean
WHERE order_delivered_carrier_date < order_approved_at;
