-- =========================================================================
-- 01_setup_and_import.sql
-- Project: Olist Brazilian E-Commerce Analysis
-- Purpose: Initial database schema creation, CSV imports, and data type fixes.
-- Run order: This file should be executed FIRST.
-- 
-- Notes:
--   - LOAD DATA LOCAL INFILE is used for fast bulk import. Requires
--     local_infile=1 on both server and client side (set in Workbench
--     connection: Advanced -> Others -> OPT_LOCAL_INFILE=1).
--   - File paths assume CSVs are stored at D:/study/Portfolio/04- Brazilian
--     E-Commerce/. Adjust paths to match your local environment.
--   - The geolocation table was intentionally excluded from the analysis
--     because customer_state and seller_state provide sufficient state-level
--     granularity without the overhead of 1M+ rows.
--   - Initial ALTER TABLE statements at the bottom convert columns from
--     VARCHAR to INT where numeric operations are needed.
-- =========================================================================

USE olist;

-- -------------------------------------------------------------------------
-- Customers table
-- -------------------------------------------------------------------------
CREATE TABLE customers (
    customer_id VARCHAR(50),
    customer_unique_id VARCHAR(50),
    customer_zip_code_prefix VARCHAR(10),
    customer_city VARCHAR(100),
    customer_state VARCHAR(5)
);

LOAD DATA LOCAL INFILE 'D:/study/Portfolio/04- Brazilian E-Commerce/olist_customers_dataset.csv'
INTO TABLE customers
FIELDS TERMINATED BY ','
ENCLOSED BY '"'
LINES TERMINATED BY '\n'
IGNORE 1 ROWS;

-- -------------------------------------------------------------------------
-- Order items table
-- -------------------------------------------------------------------------
CREATE TABLE order_items (
    order_id VARCHAR(100),
    order_item_id VARCHAR(10),
    product_id VARCHAR(100), 
    seller_id VARCHAR(100),
    shipping_limit_date DATETIME,
    price DECIMAL(10,2),
    freight_value DECIMAL(10,2)
);

LOAD DATA LOCAL INFILE 'D:/study/Portfolio/04- Brazilian E-Commerce/olist_order_items_dataset.csv'
INTO TABLE order_items
FIELDS TERMINATED BY ','
ENCLOSED BY '"'
LINES TERMINATED BY '\n'
IGNORE 1 ROWS;

-- -------------------------------------------------------------------------
-- Order payments table
-- -------------------------------------------------------------------------
CREATE TABLE order_payments (
    order_id VARCHAR(100),
    payment_sequential VARCHAR(10),
    payment_type VARCHAR(50),
    payment_installments VARCHAR(20),
    payment_value DECIMAL(10,2)
);

LOAD DATA LOCAL INFILE 'D:/study/Portfolio/04- Brazilian E-Commerce/olist_order_payments_dataset.csv'
INTO TABLE order_payments
FIELDS TERMINATED BY ','
ENCLOSED BY '"'
LINES TERMINATED BY '\n'
IGNORE 1 ROWS;

-- -------------------------------------------------------------------------
-- Order reviews table
-- -------------------------------------------------------------------------
CREATE TABLE order_reviews (
    review_id VARCHAR(100),
    order_id VARCHAR(100),
    review_score VARCHAR(2),
    review_comment_title VARCHAR(300),
    review_comment_message VARCHAR(500),
    review_creation_date DATETIME,
    review_answer_timestamp DATETIME
);

LOAD DATA LOCAL INFILE 'D:/study/Portfolio/04- Brazilian E-Commerce/olist_order_reviews_dataset.csv'
INTO TABLE order_reviews
FIELDS TERMINATED BY ','
ENCLOSED BY '"'
LINES TERMINATED BY '\n'
IGNORE 1 ROWS;

-- -------------------------------------------------------------------------
-- Orders table (the central fact table)
-- -------------------------------------------------------------------------
CREATE TABLE orders (
    order_id VARCHAR(100),
    customer_id VARCHAR(50),
    order_status VARCHAR(50),
    order_purchase_timestamp DATETIME,
    order_approved_at DATETIME,
    order_delivered_carrier_date DATETIME,
    order_delivered_customer_date DATETIME,
    order_estimated_delivery_date DATETIME
);

LOAD DATA LOCAL INFILE 'D:/study/Portfolio/04- Brazilian E-Commerce/olist_orders_dataset.csv'
INTO TABLE orders
FIELDS TERMINATED BY ','
ENCLOSED BY '"'
LINES TERMINATED BY '\n'
IGNORE 1 ROWS;

-- -------------------------------------------------------------------------
-- Products table
-- -------------------------------------------------------------------------
CREATE TABLE products (
    product_id VARCHAR(100),
    product_category_name VARCHAR(100),
    product_name_lenght VARCHAR(20),
    product_description_lenght VARCHAR(20),
    product_photos_qty VARCHAR(5),
    product_weight_g INT,
    product_length_cm INT,
    product_height_cm INT,
    product_width_cm INT
);

LOAD DATA LOCAL INFILE 'D:/study/Portfolio/04- Brazilian E-Commerce/olist_products_dataset.csv'
INTO TABLE products
FIELDS TERMINATED BY ','
ENCLOSED BY '"'
LINES TERMINATED BY '\n'
IGNORE 1 ROWS;

-- -------------------------------------------------------------------------
-- Sellers table
-- -------------------------------------------------------------------------
CREATE TABLE sellers (
    seller_id VARCHAR(100),
    seller_zip_code_prefix VARCHAR(20),
    seller_city VARCHAR(100),
    seller_state VARCHAR(20)
);

LOAD DATA LOCAL INFILE 'D:/study/Portfolio/04- Brazilian E-Commerce/olist_sellers_dataset.csv'
INTO TABLE sellers
FIELDS TERMINATED BY ','
ENCLOSED BY '"'
LINES TERMINATED BY '\n'
IGNORE 1 ROWS;

-- -------------------------------------------------------------------------
-- Product category name translation table (Portuguese -> English lookup)
-- -------------------------------------------------------------------------
CREATE TABLE product_category_name_translation (
    product_category_name TEXT,
    product_category_name_english TEXT
);

LOAD DATA LOCAL INFILE 'D:/study/Portfolio/04- Brazilian E-Commerce/product_category_name_translation.csv'
INTO TABLE product_category_name_translation
FIELDS TERMINATED BY ','
ENCLOSED BY '"'
LINES TERMINATED BY '\n'
IGNORE 1 ROWS;

-- =========================================================================
-- Data type adjustments
-- These columns were imported as VARCHAR by default but represent numeric
-- values that need to support aggregation (AVG, SUM, etc.).
-- =========================================================================

ALTER TABLE order_items
    MODIFY order_item_id INT;

ALTER TABLE order_payments
    MODIFY payment_sequential INT,
    MODIFY payment_installments INT;

ALTER TABLE order_reviews
    MODIFY review_score INT,
    MODIFY review_comment_title TEXT,
    MODIFY review_comment_message TEXT;

ALTER TABLE products
    MODIFY product_name_lenght INT,
    MODIFY product_description_lenght INT,
    MODIFY product_photos_qty INT;
