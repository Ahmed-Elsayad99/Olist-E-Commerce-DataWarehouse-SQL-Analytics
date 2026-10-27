/*
===============================================================================
DDL Script: Create Gold Tables
===============================================================================
Script Purpose:
    This script creates Tables for the Gold layer in the data warehouse. 
    The Gold layer represents the final dimension and fact tables (Galaxy Schema)

    Each Table performs transformations and combines data from the Silver layer 
    to produce a clean, enriched, and business-ready dataset.

Usage:
    - These Tables can be queried directly for analytics and reporting.
===============================================================================
*/

-- =============================================================================
-- Create Dimension: olist_dwh.gold.dim_location
-- =============================================================================

CREATE TABLE olist_dwh.gold.dim_geo_location (
    geo_location_sk BIGINT IDENTITY(1,1) PRIMARY KEY,
    zip_code_prefix BIGINT,
    state VARCHAR(50) NOT NULL,
    city VARCHAR(50) NOT NULL,
    latitude decimal(10,6),
    longitude decimal(10,6),
    create_date DATETIME
);


-- =============================================================================
-- Create Dimension: olist_dwh.gold.dim_customers
-- =============================================================================

CREATE TABLE olist_dwh.gold.dim_customers (
    customer_sk BIGINT IDENTITY(1,1) PRIMARY KEY,
    customer_unique_id VARCHAR(50),
    geo_location_sk BIGINT,
    create_date DATETIME
);


-- =============================================================================
-- Create Dimension: olist_dwh.gold.dim_sellers
-- =============================================================================

CREATE TABLE olist_dwh.gold.dim_sellers (
    seller_sk BIGINT IDENTITY(1,1) PRIMARY KEY,
    seller_id VARCHAR(50),
    geo_location_sk BIGINT,
    create_date DATETIME
);



-- =============================================================================
-- Create Dimension: olist_dwh.gold.dim_product_categories
-- =============================================================================

CREATE TABLE olist_dwh.gold.dim_product_categories (
    product_category_id BIGINT PRIMARY KEY,
    product_category_name VARCHAR(50),
    product_category_name_engilsh VARCHAR(50),
    create_date DATETIME
);


-- =============================================================================
-- Create Dimension: olist_dwh.gold.dim_products
-- =============================================================================

CREATE TABLE olist_dwh.gold.dim_products (
    product_sk BIGINT IDENTITY(1,1) PRIMARY KEY,
    product_id VARCHAR(50) NOT NULL,
    product_category_id BIGINT,
    weight_g INT,
    length_cm INT,
    height_cm INT,
    width_cm INT,
    create_date DATETIME
);

-- =============================================================================
-- Create Dimension: olist_dwh.gold.dim_orders
-- =============================================================================


CREATE TABLE olist_dwh.gold.dim_orders (
	order_sk BIGINT IDENTITY(1,1) PRIMARY KEY,
    order_id VARCHAR(50) NOT NULL,
	customer_sk BIGINT NOT NULL,
	order_status VARCHAR(50),
	purchase_date DATE,
	approved_date DATE,
	shipping_date DATE,
	expected_delivery_date DATE,
	delivered_customer_date DATE,
	create_date datetime
);



-- =============================================================================
-- Create Dimension: olist_dwh.gold.dim_order_reviews
-- =============================================================================

CREATE TABLE olist_dwh.gold.dim_order_reviews (
    order_review_sk BIGINT IDENTITY(1,1) PRIMARY KEY,
    review_id VARCHAR(50) NOT NULL,
    order_sk BIGINT NOT NULL,
    review_score INT,
    review_creation_date DATE,
    review_answer_date DATE,
    create_date DATETIME
);


-- =============================================================================
-- Create Fact: olist_dwh.gold.fact_order_items
-- =============================================================================

CREATE TABLE olist_dwh.gold.fact_order_items (
    order_item_sk BIGINT IDENTITY(1,1) PRIMARY KEY,
    order_sk BIGINT NOT NULL,
    order_item_id INT NOT NULL,
    product_sk BIGINT NOT NULL,
    seller_sk BIGINT NOT NULL,
    shipping_limit_date DATE,
    price DECIMAL(10,2),
    freight_value DECIMAL(10,2),
    revenue DECIMAL(10,2),
    create_date DATETIME
);


-- =============================================================================
-- Create Fact: olist_dwh.gold.fact_order_payments
-- =============================================================================

CREATE TABLE olist_dwh.gold.fact_order_payments (
    order_payment_sk BIGINT IDENTITY(1,1) PRIMARY KEY,
    order_sk BIGINT NOT NULL,
    payment_sequential INT,
    payment_type VARCHAR(50),
    payment_installments INT,
    payment_value DECIMAL(10,2),
    create_date DATETIME
);


-- =============================================================================
-- Create olist_dwh.gold.Customers_RFM
-- =============================================================================

CREATE TABLE olist_dwh.gold.customers_rfm (
    customer_unique_id VARCHAR(50) Primary Key,
    last_order_date DATE,
    recency INT,
    frequency INT,
    monetary DECIMAL(18,2) NULL,
    r_score INT,
    f_score INT,
    m_score INT,
    rfm_score CHAR(3),
    customer_segment VARCHAR(20),
);


