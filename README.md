# Olist Brazilian E-Commerce | SQL & Power BI Analysis

![SQL](https://img.shields.io/badge/SQL-MySQL-4479A1?style=for-the-badge&logo=mysql&logoColor=white)
![Power BI](https://img.shields.io/badge/Power%20BI-F2C811?style=for-the-badge&logo=powerbi&logoColor=black)
![Status](https://img.shields.io/badge/Status-Complete-brightgreen?style=for-the-badge)

End-to-end analysis of 100,000 Brazilian e-commerce orders — from raw CSVs through cleaned MySQL views to a 3-page Power BI dashboard. Investigates how delivery performance drives customer satisfaction across Brazil.

-------------------------------------------------------------------------------------------

## 🎯 Project Overview

This project analyzes a public dataset of 100,000+ orders from **Olist**, the largest department store on Brazilian marketplaces, covering the period from September 2016 to September 2018. The goal was to build a complete analytical pipeline from raw transactional data to executive-ready insights, demonstrating both technical depth in SQL and storytelling capability through Power BI.

The work is structured around a central business question:

> **What drives customer satisfaction in Olist's marketplace, and where is performance breaking down?**

The analysis combines nine raw CSV tables into a relational MySQL database, applies systematic data cleaning, and surfaces patterns through 11 analytical views that feed a 3-page Power BI dashboard.

-------------------------------------------------------------------------------------------

## 🛠 Tech Stack

| Tool | Purpose |
|------|---------|
| **MySQL 8.0** | Database for storing, cleaning, and modeling the dataset |
| **MySQL Workbench** | SQL development and query testing environment |
| **Power BI Desktop** | Dashboard development with DAX measures |
| **Git / GitHub** | Version control and project publishing |

**Key SQL techniques applied:** multi-table JOINs, window functions (`ROW_NUMBER OVER PARTITION BY`), CASE WHEN aggregation, subqueries, conditional `COUNT DISTINCT`, date arithmetic with `TIMESTAMPDIFF`, view-based data layering, primary key and index design.

**Key DAX measures built:** Total Revenue, Total Orders, Average Review Score, On-Time Delivery Rate, % Late Deliveries, Avg Actual / Estimated Delivery Days, Delivery Performance Gap, and Review Score Gap (Late vs. On Time).
Why this format works:

Table layout — quick visual scan, no fluff

-------------------------------------------------------------------------------------------

## 📂 Dataset

**Source:** [Brazilian E-Commerce Public Dataset by Olist](https://www.kaggle.com/datasets/olistbr/brazilian-ecommerce) (Kaggle)

**Period covered:** September 2016 – September 2018

**Volume:** ~100,000 orders across 9 relational tables, totaling ~1.5 million rows

**Schema overview:** The dataset is structured around the `orders` table as the central fact, with related dimensions for customers, products, sellers, payments, reviews, and a Portuguese-to-English category translation lookup. The `geolocation` table was excluded from this analysis as `customer_state` and `seller_state` columns provided sufficient granularity for state-level analysis without the overhead of 1M+ geolocation rows.

**Key data quality findings during cleaning:**
- 553 duplicate reviews per `order_id` (resolved via window function — kept latest review per order)
- Duplicate `review_id` values across different orders (resolved with composite primary key)
- Corrupt `0000-00-00 00:00:00` placeholders in 5 datetime columns (converted to NULL)
- 24 delivered orders with missing intermediate timestamps (excluded from delivery analysis)
- 1,359 orders with carrier date logged before approval date (flagged as a documented business pipeline quirk, not a data error)

-------------------------------------------------------------------------------------------

## 📁 Project Structure

```
olist-brazilian-ecommerce-analysis/
├── README.md
├── images/
│   ├── page1_overview.png
│   ├── page2_sales.png
│   └── page3_delivery.png
├── sql/
│   ├── 01_setup_and_import.sql      # CREATE TABLE, LOAD DATA, ALTER for type fixes
│   ├── 02_data_cleaning.sql          # Duplicate audit, NULL audit, zero-date fixes, cleaning views
│   ├── 03_keys_and_indexes.sql       # Primary keys, composite keys, foreign key indexes
│   └── 04_analysis_views.sql         # 11 analytical views for Power BI consumption
└── powerbi/
    └── olist_dashboard.pbix          # Power BI Desktop file (3-page dashboard)
```

-------------------------------------------------------------------------------------------

## 🔍 Methodology

The project followed a four-phase pipeline: data preparation, exploratory cleaning, business-question analysis, and dashboard storytelling. Each phase produced a concrete artifact (cleaned tables, views, dashboard pages) that the next phase built on.

---

### Phase 1 — Data Preparation

The 9 source CSVs were loaded into a MySQL database using `LOAD DATA LOCAL INFILE`, chosen over the GUI Import Wizard for performance — bulk-loading 100,000 rows in seconds rather than hours. Each table was created with explicit column types based on the schema, with deliberate choices:

- **`VARCHAR` for IDs** rather than INT, since they are random hashes never used in math
- **`DECIMAL(10,2)` for monetary columns** to avoid floating-point rounding errors
- **`DATETIME` for timestamps**, with corruption fixes applied later (see Phase 2)

After import, several columns required type adjustments — some numeric values had been imported as `VARCHAR` and were converted to `INT` to enable aggregation.

The `geolocation` table was deliberately excluded. With over 1 million rows of redundant zip-code-to-coordinate mappings, it would have slowed every query without adding value, since `customer_state` and `seller_state` provided sufficient granularity for state-level analysis.

---

### Phase 2 — Data Cleaning & Validation

Rather than blindly trust the imported data, a systematic audit was performed across five dimensions:

**Duplicate detection** — Primary key uniqueness was verified for each table using `GROUP BY ... HAVING COUNT(*) > 1`. Two findings:
- `order_reviews` had 553 duplicate `order_id` entries — investigation showed these were genuine customer resubmissions (different `review_id`, same order). Resolved by creating a `order_reviews_clean` view that uses a `ROW_NUMBER() OVER (PARTITION BY order_id)` window function to retain only the most recent review per order.
- When applying a primary key on `order_reviews(review_id)`, MySQL revealed that `review_id` is not actually unique in the source data — the same `review_id` can be linked to multiple `order_id` values. This led to a composite primary key on `(review_id, order_id)`, reflecting the actual data structure.

**NULL audit** — A blanket NULL count returned all zeros, which seemed impossible. Investigation revealed that empty datetime cells in the source CSV had been imported as `0000-00-00 00:00:00` placeholders rather than true NULLs. These were converted to NULL across 5 datetime columns, then NULL distribution was re-audited by `order_status`. The remaining NULLs correlated logically with order status (e.g., `unavailable` orders never have delivery dates), confirming they are business-meaningful, not data errors.

**Logical inconsistency check** — Date columns were tested for chronological validity:
- 0 orders had approval before purchase (clean)
- 1,359 orders had carrier date before approval — investigation showed these likely reflect a real Olist business process where some sellers ship before formal payment approval. Retained and documented rather than removed.
- 23 orders had delivery date before carrier date — likely logging errors. Too small a fraction to materially affect aggregates, retained and documented.

**Cleaning views** — Two views were created to layer cleaning logic on top of raw tables without modifying them destructively:
- `order_reviews_clean` — deduplicated reviews
- `orders_delivered_clean` — delivered orders with all four key timestamps populated, providing a clean foundation for delivery time analysis

---

### Phase 3 — Database Design

Primary keys, composite keys, and foreign-key-style indexes were applied across all 8 tables. This wasn't strictly necessary for analytical queries — but it served two purposes:

1. **Performance** — Primary keys are auto-indexed, and explicit indexes on JOIN columns dramatically accelerated multi-table queries
2. **Documentation** — Keys make the relational structure self-documenting and demonstrate understanding of database design beyond just querying

---

### Phase 4 — Analytical Views

Eleven analytical views were built to answer the project's core business questions. Each view is purpose-built for a specific dashboard visual:

| View | Purpose |
|------|---------|
| `analysis_monthly_revenue` | Time-series revenue trend |
| `analysis_top_categories` | Category-level revenue ranking |
| `analysis_revenue_orders_by_state` | Geographic revenue distribution |
| `analysis_average_review_by_category` | Customer satisfaction by product category |
| `analysis_payment_distribution` | Payment method breakdown |
| `analysis_avg_delivery_time` | Actual vs estimated delivery, by state |
| `analysis_late_delivery_impact` | The headline insight: late vs on-time review scores |
| `analysis_order_status_breakdown` | Order pipeline funnel |
| `analysis_top_sellers` | Top sellers with delivery performance |
| `analysis_review_by_delivery_status_raw` | Per-order data for proper DAX averaging |
| `analysis_delivery_time_per_order` | Per-order data for proper DAX averaging |

A subtle but important design decision: the last two views are **deliberately unaggregated**. When initial Power BI measures averaged the per-state averages from the aggregated views, they returned biased numbers (the average-of-averages problem — small states like Roraima with extreme values were weighted equally with São Paulo's millions of orders). The raw views give DAX the per-order grain needed to compute properly weighted overall averages.

A bug was caught during quality assurance on the `analysis_top_sellers` view: an initial `SUM(CASE WHEN ... THEN 1 ELSE 0 END)` pattern was double-counting orders that contained multiple items. Refactored to `COUNT(DISTINCT CASE WHEN ... THEN order_id END)` which deduplicates within each conditional bucket. This was caught by sanity-checking that `on_time_orders + late_orders` should equal `total_orders` per seller.

---

### Phase 5 — Power BI Dashboard

The dashboard was built as a 3-page narrative:
- **Page 1 (Executive Overview)** — top-line KPIs and the high-level pipeline view
- **Page 2 (Sales & Categories)** — what's selling, who's selling it, and how customers pay  
- **Page 3 (Delivery & Satisfaction)** — the core analytical story showing how delivery performance drives satisfaction

A dedicated `_Measures` table (Power BI best practice) holds 9 DAX measures separated from the data tables. Measures range from simple aggregates (`Total Revenue = SUM(...)`) to filtered calculations using `CALCULATE` and conditional measure composition (`% Late Deliveries = 1 - [On-Time Delivery Rate]`).

Visual storytelling decisions were deliberate:
- **Green/red color encoding** on the headline late-vs-on-time chart, to make the satisfaction gap immediately emotionally clear
- **Top-N filtering** applied at the visual level rather than baked into views, keeping views reusable across different dashboard contexts
- **Aligned sorting** on Page 3's bottom charts — slowest delivery states on the left, lowest review states on the right — visually proving the headline insight at the geographic level
