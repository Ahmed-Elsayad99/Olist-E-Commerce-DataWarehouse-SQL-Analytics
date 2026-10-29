/*
===============================================================================
ETL Script: Create Automated ETL Pipelines Process
===============================================================================
Script Purpose:
    This script creates Automated ETL Pipelines Process in the 'Gold' schema
===============================================================================
*/

EXEC gold.load_gold;
GO

CREATE OR ALTER PROCEDURE gold.load_gold AS
BEGIN
Print '=====================================================';
Print 'Loading Gold Layer';
Print '=====================================================';

Print '-----------------------------------------------------';
Print 'Loading Dimension Tables';
Print '-----------------------------------------------------';


Print 'Truncating Table: olist_dwh.gold.dim_location';
Truncate Table olist_dwh.gold.dim_location;
Print 'Inserting Data Into: olist_dwh.gold.dim_location';

INSERT INTO olist_dwh.gold.dim_geo_location (
    zip_code_prefix,
    state,
    city,
    latitude,
    longitude,
    create_date
)

SELECT 
    geolocation_zip_code_prefix,
    geolocation_state,
    geolocation_city,
    geolocation_lat,
    geolocation_lng,
    dwh_create_date
FROM olist_dwh.silver.crm_geo_location;

/*
INSERT INTO olist_dwh.gold.dim_geo_location
( geo_location_sk, zip_code_prefix, state, city, latitude, longitude, create_date)
VALUES
( 0, 0, 'Unknown', 'Unknown', 0, 0, GETDATE() );
*/

-- ================================================================================================== --

Print 'Truncating Table: olist_dwh.gold.dim_customers';
Truncate Table olist_dwh.gold.dim_customers;
Print 'Inserting Data Into: olist_dwh.gold.dim_customers';


WITH Geo_Location As (
    select
        geo_location_sk,
        zip_code_prefix,
        state,
        city,
        ROW_NUMBER() OVER(
           PARTITION BY 
               zip_code_prefix,
               state,
               city
           ORDER BY
              geo_location_sk 
        ) As gn
    from olist_dwh.gold.dim_geo_location
),
Ranked_Customers As(
    select
        customer_unique_id,
        customer_zip_code_prefix,
        customer_city,
        customer_state,
        dwh_create_date,
        ROW_NUMBER() OVER(
            PARTITION BY customer_unique_id
            ORDER BY customer_id
        ) AS cn
    from olist_dwh.silver.crm_customers
    where customer_unique_id IS NOT NULL
)

INSERT INTO olist_dwh.gold.dim_customers (
    customer_unique_id,
    geo_location_sk,
    create_date
    )

SELECT
    c.customer_unique_id,
    COALESCE(l.geo_location_sk, 0) As geo_location_sk,
    c.dwh_create_date
FROM Ranked_Customers c
LEFT JOIN Geo_Location l
    ON c.customer_zip_code_prefix = l.zip_code_prefix
    AND c.customer_city = l.city
    AND c.customer_state = l.state
    AND l.gn = 1
where c.cn = 1;


-- ================================================================================================== --

Print 'Truncating Table: olist_dwh.gold.dim_sellers';
Truncate Table olist_dwh.gold.dim_sellers;
Print 'Inserting Data Into: olist_dwh.gold.dim_sellers';

WITH Geo_Location As (
    select
        geo_location_sk,
        zip_code_prefix,
        state,
        city,
        ROW_NUMBER() OVER(
           PARTITION BY 
               zip_code_prefix,
               state,
               city
           ORDER BY
              geo_location_sk 
        ) As n
    from olist_dwh.gold.dim_geo_location
)

INSERT INTO olist_dwh.gold.dim_sellers (
    seller_id,
    geo_location_sk,
    create_date 
    )

SELECT
    s.seller_id,
    COALESCE(l.geo_location_sk, 0) As geo_location_sk,
    s.dwh_create_date
FROM olist_dwh.silver.csv_sellers s
LEFT JOIN Geo_Location l
    ON s.seller_zip_code_prefix = l.zip_code_prefix
    AND s.seller_city = l.city
    AND s.seller_state = l.state
    AND l.n = 1;


-- ================================================================================================== --

Print 'Truncating Table: olist_dwh.gold.dim_product_categories';
Truncate Table olist_dwh.gold.dim_product_categories;
Print 'Inserting Data Into: olist_dwh.gold.dim_product_categories';

INSERT INTO olist_dwh.gold.dim_product_categories (
    product_category_id,
    product_category_name,
    product_category_name_engilsh,
    create_date 
    )

SELECT
    product_category_id,
    product_category_name,
    product_category_name_english,
    dwh_create_date
FROM olist_dwh.silver.csv_product_categories;

-- ================================================================================================== --

Print 'Truncating Table: olist_dwh.gold.dim_products';
Truncate Table olist_dwh.gold.dim_products;
Print 'Inserting Data Into: olist_dwh.gold.dim_products';

INSERT INTO olist_dwh.gold.dim_products (
    product_id,
    product_category_id,
    weight_g,
    length_cm,
    height_cm,
    width_cm,
    create_date 
    )

SELECT
    p.product_id,
    pc.product_category_id,
    p.product_weight_g,
    p.product_length_cm,
    p.product_height_cm,
    p.product_width_cm,
    p.dwh_create_date
FROM olist_dwh.silver.csv_products p
LEFT JOIN olist_dwh.gold.dim_product_categories pc
    ON  p.product_category_name = pc.product_category_name;

-- ================================================================================================== --


Print 'Truncating Table: olist_dwh.gold.dim_orders';
Truncate Table olist_dwh.gold.dim_orders;
Print 'Inserting Data Into: olist_dwh.gold.dim_orders';


INSERT INTO olist_dwh.gold.dim_orders (
    order_id,
	customer_sk,
	order_status,
	purchase_date,
	approved_date,
	shipping_date,
	expected_delivery_date,
	delivered_customer_date,
	create_date
	)
SELECT 
    o.order_id,
	c.customer_sk,
	o.order_status,
	CAST(o.order_purchase_timestamp AS DATE) AS purchase_date,
	CAST(o.order_approved_at AS DATE) AS approved_date,
	CAST(o.order_delivered_carrier_date AS DATE) AS shipping_date,
	CAST(o.order_estimated_delivery_date AS DATE) AS expected_delivery_date,
	CAST(o.order_delivered_customer_date AS DATE) AS delivered_customer_date,
    o.dwh_create_date
FROM olist_dwh.silver.erp_orders o
LEFT JOIN olist_dwh.silver.crm_customers sc
    on o.customer_id = sc.customer_id 
LEFT JOIN olist_dwh.gold.dim_customers c
    on sc.customer_unique_id = c.customer_unique_id;


-- ================================================================================================== --

Print 'Truncating Table: olist_dwh.gold.dim_order_reviews';
Truncate Table olist_dwh.gold.dim_order_reviews;
Print 'Inserting Data Into: olist_dwh.gold.dim_order_reviews';

INSERT INTO olist_dwh.gold.dim_order_reviews (
    review_id,
    order_sk,
    review_score,
    review_creation_date,
    review_answer_date,
    create_date 
    )

SELECT
    ov.review_id,
    o.order_sk,
    ov.review_score,
    CAST(ov.review_creation_date AS DATE) review_creation_date,
    CAST(ov.review_answer_timestamp AS DATE) review_answer_date,
    ov.dwh_create_date
FROM olist_dwh.silver.erp_order_reviews ov
LEFT JOIN olist_dwh.gold.dim_orders o
    ON  ov.order_id = o.order_id;


-- ================================================================================================== --

Print '-----------------------------------------------------';
Print 'Loading Fact Tables';
Print '-----------------------------------------------------';


Print 'Truncating Table: olist_dwh.gold.fact_order_items';
Truncate Table olist_dwh.gold.fact_order_items;
Print 'Inserting Data Into: olist_dwh.gold.fact_order_items';

INSERT INTO olist_dwh.gold.fact_order_items (
    order_sk,
    order_item_id,
    product_sk,
    seller_sk,
    shipping_limit_date,
    price,
    freight_value,
    revenue,
    create_date 
    )

SELECT
    o.order_sk,
    oi.order_item_id,
    p.product_sk,
    s.seller_sk,
    CAST(oi.shipping_limit_date AS DATE) AS shipping_limit_date,
    oi.price,
    oi.freight_value,
    oi.price + oi.freight_value AS revenue,
    oi.dwh_create_date
FROM olist_dwh.silver.erp_order_items oi
LEFT JOIN olist_dwh.gold.dim_orders o
    ON  oi.order_id = o.order_id
LEFT JOIN olist_dwh.gold.dim_products p
    ON oi.product_id = p.product_id
LEFT JOIN olist_dwh.gold.dim_sellers s
    ON oi.seller_id = s.seller_id;


-- ================================================================================================== --

Print 'Truncating Table: olist_dwh.gold.fact_order_payments';
Truncate Table olist_dwh.gold.fact_order_payments;
Print 'Inserting Data Into: olist_dwh.gold.fact_order_payments';

INSERT INTO olist_dwh.gold.fact_order_payments (
    order_sk,
    payment_sequential,
    payment_type,
    payment_installments,
    payment_value,
    create_date 
    )

SELECT
    o.order_sk,
    op.payment_sequential,
    op.payment_type,
    op.payment_installments,
    op.payment_value,
    op.dwh_create_date
FROM olist_dwh.silver.erp_order_payments op
LEFT JOIN olist_dwh.gold.dim_orders o
    ON  op.order_id = o.order_id;




-- ================================================================================================== --

Print '-----------------------------------------------------';
Print 'Loading Customers RFM Table';
Print '-----------------------------------------------------';


Print 'Truncating Table: olist_dwh.gold.customers_rfm';
Truncate Table olist_dwh.gold.customers_rfm;
Print 'Inserting Data Into: olist_dwh.gold.customers_rfm';

WITH Payment_Per_Order AS (
    SELECT
        order_sk,
        SUM(payment_value) AS Order_Monetary
    FROM olist_dwh.gold.fact_order_payments
    GROUP BY order_sk
),

Reference_Date AS (
    SELECT
        MAX(purchase_date) AS Last_Date
    FROM olist_dwh.gold.dim_orders
),

Customer_Status AS (
    SELECT
        c.customer_sk,
        MAX(o.purchase_date) AS Last_Order_Date,
        MAX(rd.Last_Date) AS Last_Date,

        DATEDIFF(
            DAY,
            MAX(o.purchase_date),
            MAX(rd.Last_Date)
        ) AS Recency,

        COUNT(DISTINCT o.order_sk) AS Frequency,

        SUM(ppo.Order_Monetary) AS Monetary

    FROM olist_dwh.gold.dim_orders AS o

    INNER JOIN olist_dwh.gold.dim_customers AS c
        ON o.customer_sk = c.customer_sk

    LEFT JOIN Payment_Per_Order AS ppo
        ON o.order_sk = ppo.order_sk

    CROSS JOIN Reference_Date AS rd

    GROUP BY
        c.customer_sk
),

RFM_Score AS (
    SELECT
        customer_sk,
        Last_Order_Date,
        Recency,
        Frequency,
        Monetary,

        CASE
            WHEN Recency <= 60 THEN 5
            WHEN Recency <= 90 THEN 4
            WHEN Recency <= 150 THEN 3
            WHEN Recency <= 365 THEN 2
            ELSE 1
        END AS R_Score,

        CASE
            WHEN Frequency <= 1 THEN 1
            WHEN Frequency = 2 THEN 2
            WHEN Frequency = 3 THEN 3
            WHEN Frequency = 4 THEN 4
            ELSE 5
        END AS F_Score,

        CASE
            WHEN Monetary <= 100 THEN 1
            WHEN Monetary <= 200 THEN 2
            WHEN Monetary <= 500 THEN 3
            WHEN Monetary <= 1000 THEN 4
            ELSE 5
        END AS M_Score

    FROM Customer_Status
),
Segmented_Customers As(
    SELECT
        customer_sk,
        Last_Order_Date,
        Recency,
        Frequency,
        Monetary,
        R_Score,
        F_Score,
        M_Score,

        CONCAT(
            R_Score,
            F_Score,
            M_Score
        ) AS RFM_Score,

        CASE
            WHEN R_Score = 5 AND F_Score = 1
                THEN 'New'

            WHEN R_Score = 5 AND (F_Score >= 3 OR M_Score >= 4)
                THEN 'VIP'

            WHEN R_Score >= 4 AND (F_Score >= 2 OR M_Score >= 3)
                THEN 'Loyal'

            WHEN R_Score >= 3
                THEN 'Regular'

            WHEN R_Score = 2
                THEN 'At Risk'

            WHEN R_Score = 1
                THEN 'Lost'

            ELSE 'Regular'
        END AS Customer_Segment,

        CASE
            WHEN Frequency > 1 THEN 'Repeat Customer'
            Else 'One Time Customer'
        END As Repeat_OneTime

    FROM RFM_Score
)

INSERT INTO olist_dwh.gold.customers_rfm (
            customer_sk,
            last_order_date,
            recency,
            frequency,
            monetary,
            r_score,
            f_score,
            m_score,
            rfm_score,
            customer_segment,
			Repeat_OneTime
        )
        SELECT
            customer_sk,
            CAST(last_order_date AS DATE),
            recency,
            frequency,
            monetary,
            r_score,
            f_score,
            m_score,
            RFM_Score,
            customer_segment,
			Repeat_OneTime

        FROM Segmented_Customers;


END;
