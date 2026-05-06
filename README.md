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
