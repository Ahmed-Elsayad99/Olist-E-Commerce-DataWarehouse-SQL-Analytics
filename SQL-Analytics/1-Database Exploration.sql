
USE olist_dwh
-- ======================================================== --
/* EDA for Olist DWH */

-- ** Database Exploration ** --
-- Explore All Objects in the Database
SELECT * FROM INFORMATION_SCHEMA.TABLES
WHERE TABLE_SCHEMA = 'gold';

-- Explore All Columns in the Database
SELECT * FROM INFORMATION_SCHEMA.COLUMNS
WHERE TABLE_SCHEMA = 'gold';

-- -------------------------------------------------------- --
-- ** Dimensions Exploration ** --
-- Dim_Customers
SELECT COUNT(customer_sk) AS Total_Customers FROM olist_dwh.gold.dim_customers; -- 99441

SELECT COUNT(DISTINCT customer_unique_id) AS Total_Unique_Customers FROM olist_dwh.gold.dim_customers; -- 96096


-- Dim_Sellers
SELECT COUNT(seller_sk) AS Total_Sellers FROM olist_dwh.gold.dim_sellers; -- 3095


-- Dim_Products
SELECT COUNT(product_id) AS Total_Products FROM olist_dwh.gold.dim_products; -- 32951

SELECT COUNT(product_id) AS Total_Products_have_Category
FROM olist_dwh.gold.dim_products
WHERE product_category_id IS NOT NULL;   -- 32328

SELECT COUNT(product_id) AS Total_Products_have_no_Category
FROM olist_dwh.gold.dim_products
WHERE product_category_id IS NULL;     -- 623

-- Dim_Product_Categories
SELECT COUNT(product_category_id) AS Total_Product_Categories FROM olist_dwh.gold.dim_product_categories;  -- 71

-- dim_geo_locations
SELECT COUNT(geo_location_sk) AS Total_Locations FROM olist_dwh.gold.dim_geo_location; -- 1000163

SELECT COUNT(DISTINCT city) AS Total_Cities FROM olist_dwh.gold.dim_geo_location; -- 5966

SELECT COUNT(DISTINCT state) AS Total_States FROM olist_dwh.gold.dim_geo_location; -- 27


-- -------------------------------------------------------- --
-- ** Date Exploration ** --

SELECT 
	MIN(purchase_date) AS First_Order,
	MAX(purchase_date) AS Last_Order,
	DATEDIFF(MONTH, MIN(purchase_date),MAX(purchase_date)) AS Duration_by_Months
FROM olist_dwh.gold.dim_orders;
/*
First_Order		Last_Order		Duration_by_Months
2016-09-04		2018-10-17		25
*/

-- -------------------------------------------------------- --
-- ** Measures Exploration ** --


SELECT 'Total Orders' AS 'Measure_Name', COUNT(order_sk) AS Measure_Value FROM olist_dwh.gold.dim_orders
UNION ALL 
SELECT 'Total Revenue' AS 'Measure_Name', SUM(payment_value) AS Measure_Value FROM olist_dwh.gold.fact_order_payments
UNION ALL 
SELECT 'Total Quantity' AS 'Measure_Name', COUNT(*) AS Measure_Value FROM olist_dwh.gold.fact_order_items
UNION ALL 
SELECT 'Avg Price' AS 'Measure_Name', AVG(price) AS Measure_Value FROM olist_dwh.gold.fact_order_items
UNION ALL 
SELECT 'Max Price' AS 'Measure_Name', MAX(price) AS Measure_Value FROM olist_dwh.gold.fact_order_items
UNION ALL 
SELECT 'Min Price' AS 'Measure_Name', MIN(price) AS Measure_Value FROM olist_dwh.gold.fact_order_items
UNION ALL 
SELECT 'Total Customers' AS 'Measure_Name', COUNT(customer_sk) AS Measure_Value FROM olist_dwh.gold.dim_customers
UNION ALL 
SELECT 'Total Unique Customers' AS 'Measure_Name', COUNT(DISTINCT customer_unique_id) AS Measure_Value FROM olist_dwh.gold.dim_customers
UNION ALL 
SELECT 'Total Sellers' AS 'Measure_Name', COUNT(seller_sk) AS Measure_Value FROM olist_dwh.gold.dim_sellers
UNION ALL 
SELECT 'Total Products' AS 'Measure_Name', COUNT(product_sk) AS Measure_Value FROM olist_dwh.gold.dim_products
UNION ALL 
SELECT 'Total Categoies' AS 'Measure_Name', COUNT(product_category_id) AS Measure_Value FROM olist_dwh.gold.dim_product_categories




/*
Measure_Name				Measure_Value  
Total Orders	   			99441
Total Revenue				16008872.12
AOV							161.00
Total Quantity				112650
Avg Price					120.65
Max Price					6735.00
Min Price					0.85
Total Customers			-	99441   <--
Total Unique Customers	-	96096   <== 
Total Sellers				3095
Total Products				32951
Total Categoies				71
*/


-- -------------------------------------------------------- --
-- ** Magnitude / Ranking Analysis ** --
-- Total Ordrs by order status
SELECT 
	order_status,
	COUNT(*) As Total_Orders,
	DENSE_RANK() OVER(ORDER BY COUNT(*) DESC) AS Rank
FROM olist_dwh.gold.dim_orders
GROUP BY order_status
ORDER BY Total_Orders DESC;

-- payment type Status 
SELECT 
	payment_type,
	COUNT(Distinct order_sk) as Total_Orders,
	COUNT(payment_sequential) as Payment_Count,
	SUM(payment_installments) as Installments_Count,
	SUM(payment_value) as Total_Amount,
	DENSE_RANK() OVER(ORDER BY COUNT(payment_sequential) DESC) AS Rank
FROM olist_dwh.gold.fact_order_payments
GROUP BY payment_type
ORDER BY Payment_Count DESC;

-- Total Customers and Sellers by State

WITH CustomersByState AS (
	SELECT
		COALESCE(l.state, 'N/A') AS State,
		COUNT( c.customer_sk) AS Customer_Count
	FROM olist_dwh.gold.dim_customers c
	LEFT JOIN olist_dwh.gold.dim_geo_location l
		ON l.geo_location_sk = c.geo_location_sk 
	GROUP BY COALESCE(l.state, 'N/A')
),

SellersByState AS (
	SELECT
		COALESCE(l.state, 'N/A') AS State,
		COUNT( s.seller_sk) AS Seller_Count
	FROM olist_dwh.gold.dim_sellers s 
	LEFT JOIN olist_dwh.gold.dim_geo_location l 
        ON l.geo_location_sk = s.geo_location_sk
	GROUP BY COALESCE(l.state, 'N/A')
)
SELECT 
	COALESCE(c.State,s.State) AS State,
	COALESCE(c.Customer_Count, 0) AS Customer_Count,
	COALESCE(s.Seller_Count, 0) AS Seller_Count,
	DENSE_RANK() OVER(ORDER BY c.Customer_Count DESC,s.Seller_Count DESC) AS Rank
FROM CustomersByState c
FULL OUTER JOIN SellersByState s
	ON c.state = s.state
ORDER BY c.Customer_Count DESC,s.Seller_Count DESC;


-- Total Customers and Sellers by City
WITH CustomersByCity AS (
	SELECT
		COALESCE(l.city, 'N/A') AS city,
		COUNT(c.customer_sk) AS Customer_Count
	FROM olist_dwh.gold.dim_customers c
	LEFT JOIN olist_dwh.gold.dim_geo_location l
		ON l.geo_location_sk = c.geo_location_sk 
	GROUP BY COALESCE(l.city, 'N/A')
),

SellersByCity AS (
	SELECT
		COALESCE(l.city, 'N/A') AS city,
		COUNT( s.seller_sk) AS Seller_Count
	FROM olist_dwh.gold.dim_sellers s 
	LEFT JOIN olist_dwh.gold.dim_geo_location l 
        ON l.geo_location_sk = s.geo_location_sk
	GROUP BY COALESCE(l.city, 'N/A')
)
SELECT 
	COALESCE(c.city,s.city) AS City,
	COALESCE(c.Customer_Count, 0) AS Customer_Count,
	COALESCE(s.Seller_Count, 0) AS Seller_Count,
	DENSE_RANK() OVER(ORDER BY COALESCE(c.Customer_Count, 0) DESC,COALESCE(s.Seller_Count, 0) DESC) AS Rank
FROM CustomersByCity c
FULL OUTER JOIN SellersByCity s
	ON c.city = s.city
ORDER BY c.Customer_Count DESC,s.Seller_Count DESC;

select * from olist_dwh.gold.fact_order_items
select * from olist_dwh.gold.fact_order_payments


-- ======================================================== --
/* Advanced Analysis for Olist DWH */
-- ** Change over time trends ** --
SELECT
	DATETRUNC(MONTH,o.purchase_date) AS Date_Month,
	COUNT(DISTINCT o.order_sk) As Total_Orders,
	COAlESCE(SUM(op.payment_value), 0) As Revenue,
	COAlESCE(CAST(SUM(op.payment_value) / COUNT(DISTINCT o.order_sk) AS decimal(10,2)), 0) AS AOV
FROM olist_dwh.gold.dim_orders o
LEFT JOIN olist_dwh.gold.fact_order_payments op
	ON o.order_sk = op.order_sk
GROUP BY DATETRUNC(MONTH,o.purchase_date)
ORDER BY DATETRUNC(MONTH,o.purchase_date);


-- -------------------------------------------------------- --
-- ** Cumulative Analysis ** --
WITH Monthly_Status AS (
	SELECT
		DATETRUNC(MONTH,o.purchase_date) AS Date_Month,
		COUNT(DISTINCT o.order_sk) As Total_Orders,
		COAlESCE(SUM(op.payment_value), 0) As Revenue
	FROM olist_dwh.gold.dim_orders o
	LEFT JOIN olist_dwh.gold.fact_order_payments op 
		ON o.order_sk = op.order_sk
	GROUP BY DATETRUNC(MONTH,o.purchase_date)
)
SELECT
	Date_Month,
	Total_Orders,
	SUM(Total_Orders) OVER(ORDER BY Date_Month) AS Running_Total_Orders,
	Revenue,
	SUM(Revenue) OVER(ORDER BY Date_Month) AS Running_Revenue
FROM Monthly_Status

-- -------------------------------------------------------- --
-- ** Performance Analysis ** --

-- Yearly Sales YOY% 
WITH Yearly_Sales AS (
	SELECT
		YEAR(o.purchase_date) AS YEAR,
		COUNT(DISTINCT o.order_sk) As Total_Orders,
		SUM(op.payment_value) As Revenue,
		CAST(SUM(op.payment_value) / COUNT(DISTINCT o.order_sk) AS decimal(10,2)) AS AOV
	FROM olist_dwh.gold.dim_orders o
	LEFT JOIN olist_dwh.gold.fact_order_payments op
		ON o.order_sk = op.order_sk
	GROUP BY YEAR(o.purchase_date)
)
SELECT
	YEAR,
	Total_Orders,
	COAlESCE(CAST((Total_Orders - LAG(Total_Orders) OVER(ORDER BY YEAR)) * 100.00 / LAG(Total_Orders) OVER(ORDER BY YEAR)  AS decimal(10,2)), 0) AS Ord_YOY,
	Revenue,
	COAlESCE(CAST((Revenue - LAG(Revenue) OVER(ORDER BY YEAR)) / LAG(Revenue) OVER(ORDER BY YEAR) * 100  AS decimal(10,2)), 0) AS REV_YOY,
	AOV,
	COAlESCE(CAST((AOV - LAG(AOV) OVER(ORDER BY YEAR)) / LAG(AOV) OVER(ORDER BY YEAR) * 100  AS decimal(10,2)), 0) AS AOV_YOY
FROM Yearly_Sales
ORDER BY YEAR;

---------

WITH pro_category_Status AS (
	SELECT
		YEAR(o.purchase_date) As Year,
		COALESCE(p.product_category_id, 0) As product_category_id,
		SUM(i.revenue) AS Revenue
	FROM olist_dwh.gold.dim_orders o
	LEFT JOIN olist_dwh.gold.fact_order_items i
		ON o.order_sk = i.order_sk
	LEFT JOIN olist_dwh.gold.dim_products p
		ON p.product_sk = i.product_sk
	GROUP BY YEAR(o.purchase_date), p.product_category_id
),
pro_category_Status2 AS (
	SELECT
		Year,
		product_category_id,
		Revenue,
		CAST(AVG(Revenue) OVER(PARTITION BY product_category_id) AS decimal(10,2)) AS Avg_Revenue,
		Revenue - CAST(AVG(Revenue) OVER(PARTITION BY product_category_id) AS decimal(10,2)) AS Diff_Avg,
		CASE WHEN Revenue - CAST(AVG(Revenue) OVER(PARTITION BY product_category_id) AS decimal(10,2)) > 0 THEN 'Above Avg'
			 WHEN Revenue - CAST(AVG(Revenue) OVER(PARTITION BY product_category_id) AS decimal(10,2)) < 0 THEN 'Below Avg'
			 ELSE 'Avg'
		END AS Avg_Change
	FROM pro_category_Status
	--ORDER BY product_category_id, Year; 
)
SELECT 
	Avg_Change,
	COUNT(*) AS Total_Categories
FROM pro_category_Status2
GROUP BY Avg_Change
ORDER BY Total_Categories DESC;


-- -------------------------------------------------------- --
-- ** Part to Whole Analysis ** --
WITH category_sales AS (
	SELECT
		COALESCE(p.product_category_id, 0) AS product_category_id,
		SUM(i.revenue) AS Revenue
	FROM olist_dwh.gold.fact_order_items i
	LEFT JOIN olist_dwh.gold.dim_products p
		ON p.product_sk = i.product_sk
	GROUP BY p.product_category_id
)
SELECT 
	product_category_id,
	Revenue,
	SUM(Revenue) OVER() AS Overall_REV,
	CONCAT(CAST((Revenue * 100.00 / SUM(Revenue) OVER()) AS decimal(10,2)) ,'%') As Percentage_of_Total
FROM category_sales
ORDER BY Percentage_of_Total DESC;


-- -------------------------------------------------------- --
-- ** Data Segmentation ** --

WITH Product_Segment AS (
	SELECT
		p.product_sk,
		SUM(i.revenue) AS Revenue,
		CASE WHEN SUM(i.revenue) < 100 THEN 'Low Revenue'
			 WHEN SUM(i.revenue) < 500 THEN 'Regular Revenue'
			 WHEN SUM(i.revenue) < 1000 THEN 'High Revenue'
			 ELSE 'Top Revenue'
		END AS Revenue_Range
	FROM olist_dwh.gold.fact_order_items i
	LEFT JOIN olist_dwh.gold.dim_products p
		ON p.product_sk = i.product_sk
	GROUP BY p.product_sk
)
SELECT 
	Revenue_Range,
	COUNT(*) AS Total_Product
FROM Product_Segment
GROUP BY Revenue_Range
ORDER BY Total_Product DESC;








-- •••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••
-- •••••••••••• Check orders here not here •••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••


select 
* 
from olist_dwh.gold.dim_orders o
where  not exists (
select
* 
FROM olist_dwh.gold.fact_order_payments op
    WHERE o.order_sk = op.order_sk
) ;
--1




select 
* 
from olist_dwh.gold.dim_orders o
where  not exists (
select
* 
FROM olist_dwh.gold.fact_order_items oi
    WHERE o.order_sk = oi.order_sk
) ;
-- 775



select 
* 
from olist_dwh.gold.fact_order_payments op
where  not exists (
select
* 
FROM olist_dwh.gold.fact_order_items oi
    WHERE oi.order_sk = op.order_sk
) ;-- 830



select 
* 
from olist_dwh.gold.fact_order_items oi
where  not exists (
select
* 
FROM olist_dwh.gold.fact_order_payments op
    WHERE oi.order_sk = op.order_sk
) ;-- 3

------------------------------------------------------------------------



SELECT
    o.order_status,
    COUNT(*) AS Orders_Count
FROM olist_dwh.gold.dim_orders o
WHERE NOT EXISTS (
    SELECT 1
    FROM olist_dwh.gold.fact_order_items oi
    WHERE oi.order_sk = o.order_sk
)
GROUP BY o.order_status
ORDER BY Orders_Count DESC;



SELECT
    o.order_id,
    o.order_status
FROM olist_dwh.gold.dim_orders o
WHERE o.order_status = 'DELIVERED'
    AND NOT EXISTS (
        SELECT 1
        FROM olist_dwh.gold.fact_order_items oi
        WHERE oi.order_sk = o.order_sk
    )
    AND NOT EXISTS (
        SELECT 1
        FROM erp_source.dbo.order_items si
        WHERE si.order_id = o.order_id
    );


-- ••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••

