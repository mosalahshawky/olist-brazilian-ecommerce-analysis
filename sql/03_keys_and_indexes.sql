-- =========================================================================
-- 03_keys_and_indexes.sql
-- Project: Olist Brazilian E-Commerce Analysis
-- Purpose: Apply primary keys, composite keys, and indexes to enforce
--          relational structure and accelerate JOINs.
-- Run order: This file should be executed THIRD, after data cleaning.
-- 
-- Why apply keys after import:
--   - LOAD DATA INFILE is faster without constraint checking enabled
--   - Allows the cleaning phase to fix data issues before constraints
--     are enforced (e.g., the duplicate review_id discovery led to a
--     composite key on order_reviews instead of a single-column key)
-- 
-- Indexing strategy:
--   - Primary keys are automatically indexed
--   - Foreign-key-style columns get explicit secondary indexes for
--     JOIN performance
-- =========================================================================

USE olist;

-- =========================================================================
-- PRIMARY KEYS
-- Composite keys are used where the natural unique identifier requires
-- multiple columns (order_items, order_payments, order_reviews).
-- =========================================================================

ALTER TABLE customers
    ADD PRIMARY KEY (customer_id);

ALTER TABLE orders
    ADD PRIMARY KEY (order_id);

-- Composite: an order has multiple items, each with its own order_item_id (1, 2, 3...)
ALTER TABLE order_items
    ADD PRIMARY KEY (order_id, order_item_id);

-- Composite: an order can have multiple payment installments, sequenced 1, 2, 3...
ALTER TABLE order_payments
    ADD PRIMARY KEY (order_id, payment_sequential);

-- Composite: discovered during cleaning that review_id alone is NOT unique
-- (the same review_id can appear linked to multiple order_ids in the source data).
-- Applying composite key on (review_id, order_id) reflects the actual data structure.
ALTER TABLE order_reviews
    ADD PRIMARY KEY (review_id, order_id);

ALTER TABLE products
    ADD PRIMARY KEY (product_id);

ALTER TABLE sellers
    ADD PRIMARY KEY (seller_id);

-- The translation table's product_category_name was imported as TEXT, which
-- MySQL cannot index without a key length specification. Convert to VARCHAR
-- before applying the primary key.
ALTER TABLE product_category_name_translation 
    MODIFY product_category_name VARCHAR(300);

ALTER TABLE product_category_name_translation
    ADD PRIMARY KEY (product_category_name);

-- =========================================================================
-- FOREIGN-KEY-STYLE INDEXES
-- These columns are heavily used in JOINs but are not part of any primary key.
-- Indexing them dramatically speeds up the analysis queries downstream.
-- =========================================================================

-- orders.customer_id (joins to customers)
ALTER TABLE orders
    ADD INDEX idx_orders_customer_id (customer_id);

-- order_items.product_id (joins to products)
ALTER TABLE order_items
    ADD INDEX idx_order_items_product_id (product_id);

-- order_items.seller_id (joins to sellers)
ALTER TABLE order_items
    ADD INDEX idx_order_items_seller_id (seller_id);

-- order_reviews.order_id (joins to orders) — order_id is part of the
-- composite PK but listed second, so an explicit index on it alone helps
ALTER TABLE order_reviews
    ADD INDEX idx_order_reviews_order_id (order_id);

-- products.product_category_name (joins to translation table)
ALTER TABLE products 
    ADD INDEX idx_products_product_category_name (product_category_name);
