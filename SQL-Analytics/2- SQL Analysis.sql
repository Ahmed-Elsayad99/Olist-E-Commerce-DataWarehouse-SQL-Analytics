use olist_dwh

--••••••••••••••••••••• Customers 👥 •••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••

-- Q1• How many active customers do we have over time? 

select COUNT(distinct customer_sk) u from olist_dwh.gold.dim_orders --99441

-- Q2• How many unique customers are there? 

select COUNT(distinct customer_unique_id) As Total_Customers 
from olist_dwh.gold.dim_customers; -- 96096

-- Q3•	What percentage of customers are repeat customers vs. one-time buyers? 

With Customer_Orders As (
	select 
		c.customer_unique_id,
		count(o.order_sk) As total_orders,
		Case 
			When count(o.order_sk) = 1 Then 'One-Time Customer'
			Else 'Repeat Customer'
	End As Customer_Type
	from olist_dwh.gold.dim_orders o
	join olist_dwh.gold.dim_customers c
		on o.customer_sk = c.customer_sk
	group by c.customer_unique_id
),
Customer_Revenue As (
    select 
		c.customer_unique_id,
		Sum(op.payment_value) As Total_Revenue
	from olist_dwh.gold.dim_orders o
	join olist_dwh.gold.dim_customers c
		on o.customer_sk = c.customer_sk
	join olist_dwh.gold.fact_order_payments op
	    on o.order_sk = op.order_sk
	group by c.customer_unique_id
)
select 
	co.Customer_Type,
	Count(co.customer_unique_id) As Customer_Count,
	
	Concat(
		Cast(
			Count(co.customer_unique_id) * 100.00 
			/ Sum(Count(co.customer_unique_id)) over() 
			   As decimal(5,2))
			   , '%'
	) As Percentage_of_Customers,
	Sum(cr.Total_Revenue) As Total_Revenue,
	
	Concat(
		Cast(
			(Sum(cr.Total_Revenue) 
			/ Sum(Sum(cr.Total_Revenue)) over()) * 100 
			  As decimal(5,2))
			  , '%'
	) As Percentage_of_Revenue,

	Cast(
		Sum(cr.Total_Revenue) 
			/ Count(co.customer_unique_id) 
			   As decimal(5,2)
	) As Revenue_per_customer

From Customer_Orders co
join Customer_Revenue cr
    on co.customer_unique_id = cr.customer_unique_id
group by Customer_Type
order by Customer_Count desc;

--$$$ ==> Does the business rely more on acquisition or customer retention? (Business Question)
-----------------------------_----------


-- Q4• Who are the top customers in terms of revenue, Orders, Avg sales, AOV?  High-value customers / Regular-value customers / Low-value customers
select 
	Top 5
	c.customer_unique_id,
	Count(Distinct o.order_sk) As Total_Orders,
	Sum(op.payment_value) As Total_Revenue,
	CAST(AVG(op.payment_value) AS decimal(10,2)) As Avg_Revenue,
	CAST(Sum(op.payment_value) / Count(Distinct o.order_sk) As decimal(10,2)) AS AOV,
	CASE
		WHEN Sum(op.payment_value) > 3000 THEN 'High-value customers'
		WHEN Sum(op.payment_value) > 1000 THEN 'Regular-value customers'
		ELSE 'low-value customers'
	END As Customer_segment
from olist_dwh.gold.dim_orders o
join olist_dwh.gold.dim_customers c
	on o.customer_sk = c.customer_sk
join olist_dwh.gold.fact_order_payments op
	on o.order_sk = op.order_sk
group by c.customer_unique_id
order by Total_Orders desc;


-- Q5•	Which customer segments generate the highest revenue, what is the AOV by customer segment? 
WITH Customer_Status As (
	select 
		c.customer_unique_id,
		Count(Distinct o.order_sk) As Total_Orders,
		Sum(op.payment_value) As Total_Revenue,
		CAST(AVG(op.payment_value) AS decimal(10,2)) As Avg_Revenue,
		CASE
			WHEN Sum(op.payment_value) > 3000 THEN 'High-value customers'
			WHEN Sum(op.payment_value) > 1000 THEN 'Regular-value customers'
			ELSE 'low-value customers'
		END As Customer_segment
	from olist_dwh.gold.dim_orders o
	join olist_dwh.gold.dim_customers c
		on o.customer_sk = c.customer_sk
	join olist_dwh.gold.fact_order_payments op
		on o.order_sk = op.order_sk
	group by c.customer_unique_id
)
select
	Customer_segment,
	COUNT(customer_unique_id) As Total_Customers,
	CAST(
		COUNT(customer_unique_id) * 100.00
		/ 
		(select COUNT(*)
		from Customer_Status
		)
		As decimal(10,2)
	) As Percentage_of_Customers,
	SUM(Total_Orders) As Total_Orders,
	SUM(Total_Revenue) As Total_Revenue,
	CAST(Sum(Total_Revenue) / SUM(Total_Orders) As decimal(10,2)) AS AOV
FROM Customer_Status
GROUP BY Customer_segment
ORDER BY Total_Revenue DESC;


-- Q6• Are high-value customers concentrated in specific regions? 
WITH Customer_Status As (
	select 
		c.customer_unique_id,
		l.state,
		Count(Distinct o.order_sk) As Total_Orders,
		Sum(op.payment_value) As Total_Revenue,
		CASE
			WHEN Sum(op.payment_value) > 3000 THEN 'High-value customers'
			WHEN Sum(op.payment_value) > 1000 THEN 'Regular-value customers'
			ELSE 'low-value customers'
		END As Customer_segment
	from olist_dwh.gold.fact_order_payments op
	join olist_dwh.gold.dim_orders o
		on o.order_sk = op.order_sk
	join olist_dwh.gold.dim_customers c
		on o.customer_sk = c.customer_sk
	join olist_dwh.gold.dim_geo_location l
	    on c.geo_location_sk = l.geo_location_sk
	group by c.customer_unique_id, l.state
),
State_Summary As (
	select
		state,
		Count(*) As Total_Customers,
		SUM(
			CASE 
			   When Customer_segment = 'High-value customers' Then 1
			   Else 0
			End
		) As High_value_customers
	from Customer_Status
	group by state

)
select 
	state,
	Total_Customers,
	High_value_customers,
	CAST( 
		High_value_customers * 100.00 / Total_Customers
		As decimal(10,2)
	) As High_value_customers_Rate,
	dense_rank() over(order by CAST( 
		High_value_customers * 100.00 / Total_Customers
		As decimal(10,2)
	) Desc) As Rank
from State_Summary
where High_value_customers > 0
order by High_value_customers_Rate Desc;



-- Q7• Which states/cities have the highest customer concentration, and represent the largest customer markets? 

--> States
select
	TOP 5
	Coalesce(l.state, 'N/A') As State,
	Count(Distinct customer_unique_id) As Customers,
	Concat(
		Cast(
			Count(Distinct customer_unique_id) * 100.00 
			/ Sum(Count(Distinct customer_unique_id)) over() 
		  As decimal(5,2)),'%'
	) As Percentage_of_Customers
from olist_dwh.gold.dim_customers c
Left join olist_dwh.gold.dim_geo_location l
    On c.geo_location_sk = l.geo_location_sk
group by l.state
order by Customers desc;



--> Cities
select
	TOP 5
	Coalesce(l.city, 'N/A') As city,
	Count(Distinct customer_unique_id) As Customers,
	Concat(
		Cast(
			Count(Distinct customer_unique_id) * 100.00 
			/ Sum(Count(Distinct customer_unique_id)) over() 
		  As decimal(5,2)),'%'
	) As Percentage_of_Customers
from olist_dwh.gold.dim_customers c
Left join olist_dwh.gold.dim_geo_location l
    On c.geo_location_sk = l.geo_location_sk
group by l.city
order by Customers desc;

-- Q8• Which State generate the highest revenue per customer? 

select
	Top 5
	Coalesce(l.state, 'N/A') As State,
	SUM(op.payment_value) As Total_Revenue,
	Count(Distinct c.customer_unique_id) As Customers,
	Cast(
	    SUM(op.payment_value) / Count(Distinct customer_unique_id) 
		As decimal(5,2)
	) As Revenue_per_customer
from olist_dwh.gold.fact_order_payments op
JOIN olist_dwh.gold.dim_orders o
    ON op.order_sk = o.order_sk
JOIN olist_dwh.gold.dim_customers c
    ON o.customer_sk = c.customer_sk
JOIN olist_dwh.gold.dim_geo_location l
    ON c.geo_location_sk = l.geo_location_sk
group by l.state
order by Revenue_per_customer desc;


-- Q9• Are we growing because we are acquiring more customers, or because existing customers are buying more?
/*
QUARTER
New Customers
Repeat Customers
New Customer Revenue
Repeat Customer Revenue
New Customer Orders
Repeat Customer Orders
*/


with customer_first_order As (
	select 
		c.customer_unique_id,
		MIN(o.purchase_date) As First_order_date
	from olist_dwh.gold.dim_orders o
	left join olist_dwh.gold.dim_customers c
		on o.customer_sk = c.customer_sk
	group by c.customer_unique_id
),
customer_QUARTER As (
	select 
		DATETRUNC(QUARTER,o.purchase_date) as QUARTER,
		c.customer_unique_id,
		cfo.First_order_date,
		count(distinct o.order_sk) as Total_Orders,
		Sum(op.payment_value) As Total_Revenue
	from olist_dwh.gold.dim_orders o
	left join olist_dwh.gold.fact_order_payments op
		on o.order_sk = op.order_sk
	left join olist_dwh.gold.dim_customers c
		on o.customer_sk = c.customer_sk
	left join customer_first_order cfo
		on c.customer_unique_id = cfo.customer_unique_id
	group by 
		DATETRUNC(QUARTER,o.purchase_date),
		c.customer_unique_id,
		cfo.First_order_date
),
Customer_type as (
	select 
		QUARTER,
		customer_unique_id,
		Total_orders,
		Total_Revenue,
		case 
		   when DATETRUNC(QUARTER,First_order_date) = QUARTER then 'New Customer'
		   else 'Repeat Customer'
		end as Customer_type
	from customer_QUARTER
)

select 
	QUARTER, 
	count(distinct case 
		 when Customer_type = 'New Customer'
		 then customer_unique_id
		 End) As New_customers,
	Sum( case 
		 when Customer_type = 'New Customer'
		 then Total_Revenue
		 else 0
		 End) As New_Customers_Revenue,
	Sum( case 
		 when Customer_type = 'New Customer'
		 then Total_orders
		 else 0
		 End) As New_Customers_Orders,


    count(distinct case 
		 when Customer_type = 'Repeat Customer'
		 then customer_unique_id
		 End) As Repeat_customers,
	Sum( case 
		 when Customer_type = 'Repeat Customer'
		 then Total_Revenue
		 else 0
		 End) As Repeat_Customers_Revenue,
	Sum( case 
		 when Customer_type = 'Repeat Customer'
		 then Total_orders
		 else 0
		 End) As Repeat_Customers_Orders

from Customer_type
where QUARTER <> 2016
group by QUARTER
order by QUARTER;

/*
2016	326				59195.72				329						0					0.00						0
****************
QUARTER	New_customers	New_Customers_Revenue	New_Customers_Orders	Repeat_customers	Repeat_Customers_Revenue	Repeat_Customers_Orders

2017	43708			7158931.16				45096					5					1351.40						5
2018	52062			8501759.59				53246					687					122315.37					765
*/



-- Q10• Which customer segments generate the most revenue?
--• RFM Analysis - Recency, Frequency, Monetary ==> VIP, Loyal, Potential Loyalists, At Risk, Lost 

with customers_stutas As (
	select 
		c.customer_unique_id,
		MAX(o.purchase_date) As Last_order_date,
		(select MAX(purchase_date) from olist_dwh.gold.dim_orders) AS Last_Date,
		DATEDIFF(
			DAY, 
			MAX(o.purchase_date),
			(select MAX(purchase_date) from olist_dwh.gold.dim_orders)
			) As Recency,
		COUNT(Distinct o.order_sk) As Frequency,
		SUM(op.payment_value) As Monetary
	from olist_dwh.gold.dim_orders o
	left join olist_dwh.gold.fact_order_payments op
		on o.order_sk = op.order_sk
	left join olist_dwh.gold.dim_customers c
		on o.customer_sk = c.customer_sk
	group by c.customer_unique_id 
),

RFM_score As(
	select 
		customer_unique_id,
		Monetary,
		CASE
			WHEN Recency <= 60 THEN 5
			WHEN Recency <= 90 THEN 4
			WHEN Recency <= 150 THEN 3
			WHEN Recency <= 365 THEN 2
			ELSE 1
		END As R_score,

		CASE
			WHEN Frequency <= 1 THEN 1
			WHEN Frequency = 2 THEN 2
			WHEN Frequency = 3 THEN 3
			WHEN Frequency = 4 THEN 4
			ELSE 5
		END As F_score,

		CASE
			WHEN Monetary <= 100 THEN 1
			WHEN Monetary <= 200 THEN 2
			WHEN Monetary <= 500 THEN 3
			WHEN Monetary <= 1000 THEN 4
			ELSE 5
		END As M_score

	from customers_stutas
),

customers_segment As (
select 
	customer_unique_id,
	Monetary as Total_Revenue,
	CASE
		WHEN R_score = 5  AND( F_score >= 3 OR M_score >= 4 ) THEN 'VIP' 
		WHEN R_score >= 4 AND( F_score >= 2 OR M_score >= 3 ) THEN 'Loyal' 
		WHEN R_score >= 3 THEN 'Regular' 
		WHEN R_score = 2 THEN 'At Risk' 
		WHEN R_score = 1 THEN 'Lost' 
		ELSE 'Regular'
	END As customer_segment
from RFM_score
)

select 
	customer_segment,
	COUNT(*) As customer_count,
	CONCAT( CAST(
	    COUNT(*) * 100.00 / SUM(COUNT(*)) over()
		As decimal(10,2)
	), '%') As customer_percentage,
	SUM(Total_Revenue) As Total_Revenue
from customers_segment
group by customer_segment
order by customer_count DESC;


/*
customer_segment	customer_count		customer_percentage
At Risk				47278				49.20%
Lost				28437				29.59%
Regular				18064				18.80%
Loyal				2232				2.32%
VIP					85					0.09%
*/

-- •••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••
--••••••••••••••••••••• Products 📦 •••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••

--• Which product categories drive revenue? 

select 
	TOP 10
	COALESCE(pc.product_category_name_engilsh, 'Others') As Product_Category,
	SUM(oi.revenue) As Total_Revenue	
from olist_dwh.gold.fact_order_items oi
left join  olist_dwh.gold.dim_products p
	on oi.product_sk = p.product_sk
left join  olist_dwh.gold.dim_product_categories pc
    on p.product_category_id = pc.product_category_id
group by COALESCE(pc.product_category_name_engilsh, 'Others')
order by Total_Revenue desc;

 
--•	 Which categories generate the highest number of orders? 

select
	Top 10
	pc.product_category_name_engilsh As product_category,
	COUNT(Distinct o.order_sk) As Total_Orders
from olist_dwh.gold.fact_order_items oi
left join olist_dwh.gold.dim_orders o
    on oi.order_sk = o.order_sk
left join olist_dwh.gold.dim_products p
	on oi.product_sk = p.product_sk
left join olist_dwh.gold.dim_product_categories pc
	on p.product_category_id = pc.product_category_id
group by pc.product_category_name_engilsh
order by Total_Orders DESC;


/*
product_category		Total_Orders
bed bath table			9417
health beauty			8836
sports leisure			7720
computers accessories	6689
furniture decor			6449
*/



--•	 Which categories have the highest average order value? 

select
	Top 10
	pc.product_category_name_engilsh As product_category,
	COUNT(Distinct o.order_sk) As Total_Orders,
	SUM(oi.revenue) As Total_Revenue,
	CAST(SUM(oi.revenue) / COUNT(Distinct o.order_sk) As decimal(10,2)) As AOV
from olist_dwh.gold.fact_order_items oi
left join olist_dwh.gold.dim_orders o
    on oi.order_sk = o.order_sk
left join olist_dwh.gold.dim_products p
	on oi.product_sk = p.product_sk
left join olist_dwh.gold.dim_product_categories pc
	on p.product_category_id = pc.product_category_id
group by pc.product_category_name_engilsh
order by AOV DESC;

/*
product_category						Total_Orders		Total_Revenue		AOV
computers								181					232799.43			1286.18
small appliances home oven and coffee	75					50193.57			669.25
home appliances 2						234					123917.92			529.56
agro industry and commerce				182					78374.07			430.63
musical instruments						628					210137.37			334.61
*/




--•	 Which products have unusually high return/cancellation behavior? 

select
	Top 5
	pc.product_category_name_engilsh As product_category,
	COUNT(Distinct o.order_sk) As Total_Orders,
	SUM(
		CASE
			WHEN o.order_status = 'CANCELED' THEN 1
			ELSE 0
	END) As Canceled_orders
from olist_dwh.gold.fact_order_items oi
left join olist_dwh.gold.dim_orders o
    on oi.order_sk = o.order_sk
left join olist_dwh.gold.dim_products p
	on oi.product_sk = p.product_sk
left join olist_dwh.gold.dim_product_categories pc
	on p.product_category_id = pc.product_category_id
group by pc.product_category_name_engilsh
order by Total_Orders DESC;



--•	 Which products contribute the most to revenue growth? 

with product_QUARTERly_revenue As (
	select 
		DATETRUNC(QUARTER,o.purchase_date) As QUARTER,
		p.product_sk,
		COALESCE(pc.product_category_name_engilsh, 'Others')  As product_category,
		SUM(oi.revenue) As Total_Revenue
	from olist_dwh.gold.fact_order_items oi
	left join  olist_dwh.gold.dim_products p
	    on oi.product_sk = p.product_sk
	left join olist_dwh.gold.dim_product_categories pc
	    on p.product_category_id = pc.product_category_id
	left join olist_dwh.gold.dim_orders o
	    on oi.order_sk = o.order_sk
	group by 
		DATETRUNC(QUARTER,o.purchase_date),
		p.product_sk,
		pc.product_category_name_engilsh
),
product_growth As(
	select
		QUARTER,
		product_sk,
		product_category,
		Total_Revenue,
		Lag(Total_Revenue) over(
		   partition by product_sk
		   order by QUARTER
		) As Prev_QUARTER_Revenue
	from product_QUARTERly_revenue
)
select 
	TOP 5
	QUARTER,
	product_sk,
	product_category,
	Total_Revenue As Current_QUARTER_Revenue,
	Prev_QUARTER_Revenue,
	Total_Revenue - Prev_QUARTER_Revenue As Revenue_Growth,
	CAST(
	(Total_Revenue - Prev_QUARTER_Revenue)
	/ NULLIF(Prev_QUARTER_Revenue, 0) * 100
	As decimal(10,2)
	) As Revenue_Growth_percentage
from product_growth
where YEAR(QUARTER) <> 2016 And Prev_QUARTER_Revenue IS NOT NULL
order by Revenue_Growth DESC;




--•	 Which products generate high sales volume but low revenue? 


with products_performance As (
	select
		p.product_sk,
		COALESCE(pc.product_category_name_engilsh, 'Others')  As product_category,
		COUNT(oi.order_item_sk) As Total_Qty,
		SUM(oi.revenue) As Total_Revenue
	from olist_dwh.gold.fact_order_items oi
	left join  olist_dwh.gold.dim_products p
		on oi.product_sk = p.product_sk
	left join olist_dwh.gold.dim_product_categories pc
		on p.product_category_id = pc.product_category_id
	group by 
		p.product_sk,
		pc.product_category_name_engilsh
),
product_rank As (
	select 
		*,
		CAST(
		PERCENT_RANK() over(
		order by Total_Qty 	
		) As decimal(5,2))As Qty_percentage,
		CAST(
		PERCENT_RANK() over(
		order by Total_Revenue 	
		) As decimal(5,2)) As Revenue_percentage
	from products_performance
)
select 
	TOP 5
	product_sk,
	product_category,
	Total_Qty,
	Total_Revenue,
	Qty_percentage,
	Revenue_percentage
from product_rank
where Qty_percentage > 0.75 
  AND Revenue_percentage < 0.25
order by Total_Qty DESC;



--•	 Which categories are growing or declining over time? 
 
with product_category_QUARTERly_revenue As (
	select 
		DATETRUNC(QUARTER,o.purchase_date) As QUARTER,
		COALESCE(pc.product_category_name_engilsh, 'Others')  As product_category,
		SUM(oi.revenue) As Total_Revenue
	from olist_dwh.gold.fact_order_items oi
	left join  olist_dwh.gold.dim_products p
	    on oi.product_sk = p.product_sk
	left join olist_dwh.gold.dim_product_categories pc
	    on p.product_category_id = pc.product_category_id
	left join olist_dwh.gold.dim_orders o
	    on oi.order_sk = o.order_sk
	group by 
		DATETRUNC(QUARTER,o.purchase_date),
		pc.product_category_name_engilsh
),
product_category_growth As(
	select
		QUARTER,
		product_category,
		Total_Revenue,
		Lag(Total_Revenue) over(
		   partition by product_category
		   order by QUARTER
		) As Prev_QUARTER_Revenue
	from product_category_QUARTERly_revenue
),
product_category_YOY As (
	select 
		QUARTER,
		product_category,
		Total_Revenue As Current_QUARTER_Revenue,
		Prev_QUARTER_Revenue,
		Total_Revenue - Prev_QUARTER_Revenue As Revenue_Growth,
		CAST(
		(Total_Revenue - Prev_QUARTER_Revenue)
		/ NULLIF(Prev_QUARTER_Revenue, 0) * 100
		As decimal(10,2)
		) As Revenue_Growth_percentage
	from product_category_growth
	where YEAR(QUARTER) <> 2016 AND Prev_QUARTER_Revenue IS NOT NULL
),
final_performance As (
select 
	*,
	CASE 
		WHEN Revenue_Growth > 0 THEN 'Growing'
		WHEN Revenue_Growth < 0 THEN 'Declining'
		ELSE 'Stable'
	END AS Trend
from product_category_YOY
)
select TOP 5 * 
from final_performance
where Trend = 'Declining'  -- Declining / Stable
order by 
    --QUARTER,
	Revenue_Growth ;



--•	 Are there products with high demand but poor customer ratings? 


select 
	p.product_sk,
	COALESCE(pc.product_category_name_engilsh, 'Others')  As product_category,
	COUNT(distinct oi.order_sk) As Total_Orders,
	SUM(oi.revenue) As Total_Revenue,
	CAST(
	AVG(orv.review_score)
	As decimal(10,2)
	) As AVG_Review_Score
from olist_dwh.gold.fact_order_items oi
left join  olist_dwh.gold.dim_products p
	on oi.product_sk = p.product_sk
left join olist_dwh.gold.dim_product_categories pc
	on p.product_category_id = pc.product_category_id
left join olist_dwh.gold.dim_order_reviews orv
	on oi.order_sk = orv.order_sk
group by 
	p.product_sk,
	COALESCE(pc.product_category_name_engilsh, 'Others')
having 
	COUNT(distinct oi.order_sk) > 100
    AND AVG(orv.review_score) < 4.0
order by Total_Orders desc;


--•  Which products should Olist prioritize based on revenue, demand, customer satisfaction?

select 
	TOP 10
	p.product_sk,
	COALESCE(pc.product_category_name_engilsh, 'Others')  As product_category,
	COUNT(distinct oi.order_sk) As Total_Orders,
	SUM(oi.revenue) As Total_Revenue,
	CAST(
	AVG(orv.review_score)
	As decimal(10,2)
	) As AVG_Review_Score
from olist_dwh.gold.fact_order_items oi
left join  olist_dwh.gold.dim_products p
	on oi.product_sk = p.product_sk
left join olist_dwh.gold.dim_product_categories pc
	on p.product_category_id = pc.product_category_id
left join olist_dwh.gold.dim_order_reviews orv
	on oi.order_sk = orv.order_sk
group by 
	p.product_sk,
	COALESCE(pc.product_category_name_engilsh, 'Others')
having 
	COUNT(distinct oi.order_sk) >= 100
	AND SUM(oi.revenue) >= 10000
    AND AVG(orv.review_score) >= 4.0
order by Total_Orders desc;




-- •••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••
--••••••••••••••••••••• Sales & Revenue 💰 •••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••


--• What is the average order value? 

select 
	COUNT(distinct o.order_sk) As Total_Orders,
	SUM(op.payment_value) As Total_Revenue,
	CAST(
	SUM(op.payment_value) / COUNT(distinct o.order_sk)
	As decimal(10,2)
	) As AOV
from  olist_dwh.gold.dim_orders o
left join olist_dwh.gold.fact_order_payments op
	on o.order_sk = op.order_sk
/*
Total_Orders	Total_Revenue	AOV
99441			16008872.12		160.99
*/



--• How is revenue changing month over month?
WITH Monthly_Revenue As (
select 
	DATETRUNC(MONTH, o.purchase_date) As Month,
	SUM(op.payment_value) As Current_Month_Revenue,
	LAG(SUM(op.payment_value))
	OVER(order by DATETRUNC(MONTH, o.purchase_date) 
	) As Prev_Month_Revenue
from olist_dwh.gold.fact_order_payments op
left join olist_dwh.gold.dim_orders o
	on op.order_sk = o.order_sk
group by DATETRUNC(MONTH, o.purchase_date)
)
select 
	Month,
	Current_Month_Revenue,
	Prev_Month_Revenue,
	Current_Month_Revenue - Prev_Month_Revenue As MOM,
	CAST(
	(Current_Month_Revenue - Prev_Month_Revenue)
	/ NULLIF(Prev_Month_Revenue, 0) * 100
	AS decimal(10,2)
	) As MOM_Percentage,

	CASE 
		WHEN Current_Month_Revenue - Prev_Month_Revenue > 0 THEN 'Growing'
		WHEN Current_Month_Revenue - Prev_Month_Revenue < 0 THEN 'Delclining'
		ELSE 'Stable'
	END AS Status
from Monthly_Revenue
where Prev_Month_Revenue IS NOT NULL AND YEAR(month) <> 2016 AND Month <> '2018-10-01'
order by Month;


--• Are sales growth and customer growth moving together? 
with QUARTERly_performance as (
	select 
		DATETRUNC(QUARTER,o.purchase_date) as QUARTER,
		COUNT(distinct o.order_sk) As Total_Orders,
		SUM(op.payment_value) As Total_Revenue,
		COUNT(distinct c.customer_unique_id) Total_Customers
	from  olist_dwh.gold.dim_orders o
	left join olist_dwh.gold.fact_order_payments op
		on op.order_sk = o.order_sk
	left join olist_dwh.gold.dim_customers c 
		on o.customer_sk = c.customer_sk
	group by DATETRUNC(QUARTER,o.purchase_date) 
),
QUARTERly_growth As (
	select 
		QUARTER,
		Total_Revenue,
		Total_Customers,

		LAG(Total_Revenue) 
		OVER(order by QUARTER
		) As Prev_Revenue,

		LAG(Total_Customers) 
		OVER(order by QUARTER
		) As Prev_Customers
	from QUARTERly_performance
)
select 
	QUARTER,
	Total_Revenue,
	Total_Customers,
	Prev_Revenue,
	Prev_Customers,

	CAST(
        (Total_Revenue - Prev_Revenue)
        / NULLIF(Prev_Revenue, 0) * 100
        AS decimal(10,2)
    ) AS Revenue_Growth_Pct,

	CAST(
        (Total_Customers - Prev_Customers) * 100.00
        / NULLIF(Prev_Customers, 0)
        AS decimal(10,2)
    ) AS Customers_Growth_Pct,

	CASE
        WHEN
            (Total_Revenue - Prev_Revenue) > 0
            AND
            (Total_Customers - Prev_Customers) > 0
            THEN 'Both Growing'

        WHEN
            (Total_Revenue - Prev_Revenue) < 0
            AND
            (Total_Customers - Prev_Customers) < 0
            THEN 'Both Declining'

        WHEN
            (Total_Revenue - Prev_Revenue) > 0
            AND
            (Total_Customers - Prev_Customers) < 0
            THEN 'Revenue Up / Customers Down'

        WHEN
            (Total_Revenue - Prev_Revenue) < 0
            AND
            (Total_Customers - Prev_Customers) > 0
            THEN 'Revenue Down / Customers Up'

        ELSE 'Stable'
    END AS Growth_Relationship

from QUARTERly_growth
where Prev_Revenue IS NOT NULL;




--• Which months/seasons have the highest sales? 

select 
	Top 5
	DATETRUNC(MONTH, o.purchase_date) As Month,
	SUM(op.payment_value) As Total_Revenue
from olist_dwh.gold.fact_order_payments op
left join olist_dwh.gold.dim_orders o
	on op.order_sk = o.order_sk
group by DATETRUNC(MONTH, o.purchase_date)
order by Total_Revenue desc

/*
Month			Total_Revenue
2017-11-01		1226545.16
2018-01-01		1176530.63
2018-03-01		1162104.55
2018-05-01		1110872.80
2018-04-01		1104943.12
*/

--• What are the main drivers behind revenue changes? 

WITH Quarter_Performance AS (
select
	DATETRUNC(QUARTER, o.purchase_date) As Quarter,
	COUNT(distinct o.order_sk) As Total_Orders,
	COUNT(distinct oi.order_item_sk) As Total_Qty,
	SUM(op.payment_value) As Total_Revenue,

	LAG(COUNT(distinct o.order_sk)) 
	OVER(order by DATETRUNC(Quarter, o.purchase_date)
	) As Prev_Quarter_Orders,
	
	LAG(COUNT(distinct oi.order_item_sk)) 
	OVER(order by DATETRUNC(Quarter, o.purchase_date)
	) As Prev_Quarter_Qty,

	LAG(SUM(op.payment_value)) 
	OVER(order by DATETRUNC(Quarter, o.purchase_date)
	) As Prev_Quarter_Revenue

from olist_dwh.gold.fact_order_payments op
left join olist_dwh.gold.dim_orders o
	on op.order_sk = o.order_sk
left join  olist_dwh.gold.fact_order_items oi 
	on o.order_sk = oi.order_sk
group by DATETRUNC(Quarter, o.purchase_date)
),
Quarter_QOQ As (
select 
	Quarter,
	Total_Orders,
	Total_Qty,
	Total_Revenue,
	Prev_Quarter_Orders,
	Prev_Quarter_Qty,
	Prev_Quarter_Revenue,

	CAST(
	(Total_Orders - Prev_Quarter_Orders) * 100.00
	/ NULLIF(Prev_Quarter_Orders,0)
	AS decimal(10,2)
	) As Orders_QOQ_Pct,

	CAST(
	(Total_Qty - Prev_Quarter_Qty) * 100.00
	/ NULLIF(Prev_Quarter_Qty,0)
	AS decimal(10,2)
	) As Qty_QOQ_Pct,

	CAST(
	(Total_Revenue - Prev_Quarter_Revenue) 
	/ NULLIF(Prev_Quarter_Revenue,0) * 100
	AS decimal(10,2)
	) As Revenue_QOQ_Pct

from Quarter_Performance
where Prev_Quarter_Orders IS NOT NULL
)

Select 
	Quarter,
	Orders_QOQ_Pct,
	Qty_QOQ_Pct,
	Revenue_QOQ_Pct
from Quarter_QOQ
where  Quarter <> '2018-10-01'

/*
-- decline in Q2, Q3 2018

Quarter			Orders_QOQ_Pct	Qty_QOQ_Pct		Revenue_QOQ_Pct
2018-04-01		-5.80			-6.58			-6.28
2018-07-01		-35.84			-36.07			-38.32
*/

-- •••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••
--••••••••••••••••••••• Orders 🛒 •••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••

--• How many orders are placed over time?

select 
	DATETRUNC(MONTH, purchase_date) As Month,
	COUNT(order_sk) As orders,
	
	SUM(COUNT(order_sk)) 
	OVER(order by DATETRUNC(MONTH, purchase_date)
	) As orders_Running
from olist_dwh.gold.dim_orders
group by DATETRUNC(MONTH, purchase_date)
order by DATETRUNC(MONTH, purchase_date);



--• What percentage of orders are delivered successfully? 
WITH Monthly_Orders As (
select 
	order_status,
	COUNT(*) As Orders,
	SUM(COUNT(*)) OVER() as Orders_OverAll,
	CAST(
	(COUNT(*) * 100.00 / SUM(COUNT(*)) OVER())
	as decimal (10,2)
	) As Orders_Pct
from olist_dwh.gold.dim_orders
group by order_status
)
Select 
	*
from Monthly_Orders
where order_status = 'DELIVERED';


--• How many orders are canceled? 
WITH Monthly_Orders As (
select 
	order_status,
	COUNT(*) As Orders,
	SUM(COUNT(*)) OVER() as Orders_OverAll,
	CAST(
	(COUNT(*) * 100.00 / SUM(COUNT(*)) OVER())
	as decimal (10,2)
	) As Orders_Pct
from olist_dwh.gold.dim_orders
group by order_status
)
Select 
	*
from Monthly_Orders
where order_status = 'CANCELED';


--• What are the main order statuses? 
select 
	order_status,
	COUNT(*) As Orders,
	SUM(COUNT(*)) OVER() as Orders_OverAll,
	CAST(
	(COUNT(*) * 100.00 / SUM(COUNT(*)) OVER())
	as decimal (10,2)
	) As Orders_Pct
from olist_dwh.gold.dim_orders
group by order_status
order by Orders desc;


--• Which regions have the highest cancellation rates? 
select 
	TOP 1
	COALESCE(l.state, 'N/A') As State,
	COUNT(o.order_sk) As Orders
from olist_dwh.gold.dim_orders o
left join olist_dwh.gold.dim_customers c
    on o.customer_sk = c.customer_sk
left join olist_dwh.gold.dim_geo_location l
    on c.geo_location_sk = l.geo_location_sk
where o.order_status = 'CANCELED'
group by COALESCE(l.state, 'N/A')
order by Orders desc;  -- SAO PAULO	 327



--• Are cancellations concentrated in certain sellers/products? 
---  sellers --------
WITH Sellers_Orders As (
	select 
		COALESCE( 
		CAST(oi.seller_sk
		As varchar(50)
		)
		,'N/A'
		) As Seller_sk,
	
		COUNT(DISTINCT o.order_sk) As Total_Orders,
		COUNT(DISTINCT
		CASE
			WHEN o.order_status = 'CANCELED' THEN o.order_sk
		END) AS Canceled_Orders
	from olist_dwh.gold.dim_orders o
	left join olist_dwh.gold.fact_order_items oi
		on o.order_sk = oi.order_sk
	group by COALESCE( CAST(oi.seller_sk As varchar(50) ) ,'N/A')
)
select
	Seller_sk,
	Total_Orders,
	Canceled_Orders,

	CAST(
	Canceled_Orders * 100.00 
	/ NULLIF(Total_Orders, 0)	
	As decimal(10,2)
	) As Cancellation_Rate

from Sellers_Orders
order by Cancellation_Rate desc


--- products -----

WITH Products_Orders As (
	select 
		COALESCE( 
		CAST(oi.product_sk
		As varchar(50)
		)
		,'N/A'
		) As Product_sk,
	
		COUNT(DISTINCT o.order_sk) As Total_Orders,
		COUNT(DISTINCT
		CASE
			WHEN o.order_status = 'CANCELED' THEN o.order_sk
		END) AS Canceled_Orders
	from olist_dwh.gold.dim_orders o
	left join olist_dwh.gold.fact_order_items oi
		on o.order_sk = oi.order_sk
	group by COALESCE( CAST(oi.product_sk As varchar(50) ) ,'N/A')
)
select
	Product_sk,
	Total_Orders,
	Canceled_Orders,

	CAST(
	Canceled_Orders * 100.00 
	/ NULLIF(Total_Orders, 0)	
	As decimal(10,2)
	) As Cancellation_Rate

from Products_Orders
order by Cancellation_Rate desc



--• What is the average number of items per order? 
With order_items_count As (
select 
	o.order_sk,
	COUNT(oi.order_item_sk) As Items_Per_Order
from olist_dwh.gold.dim_orders o
left join olist_dwh.gold.fact_order_items oi
	on o.order_sk = oi.order_sk
group by o.order_sk
)
select
	order_sk,
	CAST(
	AVG(Items_Per_Order)
	As decimal(10,2)
	) As Avg_Items_Per_Order
from order_items_count
group by order_sk
order by Avg_Items_Per_Order DESC;



-- •••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••
--••••••••••••••••••••• Delivery & Logistics 🚚 •••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••

--• What is the average delivery time? 

select 
CAST( 
	AVG(
		DATEDIFF(
		DAY,
		purchase_date,
		delivered_customer_date
		) * 1.0
	) 
    As decimal(10,2)
) As Avg_Delivery_Days
from olist_dwh.gold.dim_orders
where delivered_customer_date is not null;


--• What percentage of orders are delivered late? 

select 
	COUNT(*) As Delivered_Orders,
	SUM(
		CASE
			WHEN delivered_customer_date > expected_delivery_date THEN 1
			ELSE 0
		END
	) As Late_Orders,

	CONCAT(
		CAST(
			SUM(
				CASE
					WHEN delivered_customer_date > expected_delivery_date THEN 1
					ELSE 0
				END
			) * 100.00
			/ COUNT(*)
			As decimal(10,2)
		)
		, '%'
	) As Late_Orders_Pct

from olist_dwh.gold.dim_orders
where 
	order_status = 'DELIVERED'
	AND delivered_customer_date IS NOT NULL
	AND expected_delivery_date IS NOT NULL;


/*
Delivered_Orders	Late_Orders		Late_Orders_Pct
96470				6519			6.76%
*/


--• Which states have the longest delivery times? 

select 
	TOP 10
	COALESCE(l.state, 'N/A') As State,
	COUNT(o.order_sk) As Delivered_Orders,
	CAST( 
		AVG(
			DATEDIFF(
			DAY,
			o.purchase_date,
			o.delivered_customer_date
			) * 1.0
		) 
		As decimal(10,2)
	) As Avg_Delivery_Days

from olist_dwh.gold.dim_orders o
left join olist_dwh.gold.dim_customers c
	on o.customer_sk = c.customer_sk
left join olist_dwh.gold.dim_geo_location l
	on c.geo_location_sk = l.geo_location_sk
where 
	o.order_status = 'DELIVERED'
	AND o.purchase_date IS NOT NULL
	AND o.delivered_customer_date IS NOT NULL
group by COALESCE(l.state, 'N/A')
order by Avg_Delivery_Days DESC;


--• Which sellers have the highest late-delivery rates? 

select 
	TOP 10
	s.seller_sk,
	COUNT(o.order_sk) As Delivered_Orders,
	CAST( 
		AVG(
			DATEDIFF(
			DAY,
			o.purchase_date,
			o.delivered_customer_date
			) * 1.0
		) 
		As decimal(10,2)
	) As Avg_Delivery_Days
from olist_dwh.gold.dim_orders o
left join olist_dwh.gold.fact_order_items oi
	on o.order_sk = oi.order_sk
left join olist_dwh.gold.dim_sellers s
	on oi.seller_sk = s.seller_sk 
where 
	o.order_status = 'DELIVERED'
	AND o.purchase_date IS NOT NULL
	AND o.delivered_customer_date IS NOT NULL
group by s.seller_sk
order by Avg_Delivery_Days DESC;


--• Is late delivery affecting customer review scores?

WITH Delivery_Reviews As (
	select 
		o.order_sk As Delivered_Orders,
		CASE
			WHEN o.delivered_customer_date > o.expected_delivery_date THEN 'Late'
			ELSE 'On Time'
		END As Delivery_Status,
		orv.review_score
	from olist_dwh.gold.dim_orders o
	join olist_dwh.gold.dim_order_reviews orv
		on o.order_sk = orv.order_sk
	where 
		o.order_status = 'DELIVERED'
		AND o.expected_delivery_date IS NOT NULL
		AND o.delivered_customer_date IS NOT NULL
)
SELECT
    Delivery_Status,
    review_score,
    COUNT(*) AS Orders,
	SUM(COUNT(*) ) OVER(Partition by Delivery_Status) As Orders_per_Delivery_Status,
	CAST(
		COUNT(*) *100.00 
		/ SUM(COUNT(*) ) OVER(Partition by Delivery_Status) 
		AS decimal(10,2)
	) As Percentage
FROM Delivery_Reviews
GROUP BY
    Delivery_Status,
    review_score
ORDER BY
    Delivery_Status,
    review_score;

/*
Delivery_Status		review_score	Orders	Orders_per_Delivery_Status	Percentage
Late				1				3430	6366						53.88
Late				5				1047	6366						16.45
------    -----------    ----------------    ----------------   --------  -----------
On Time				1				5921	89458						6.62
On Time				5				55700	89458						62.26

*/



--• Which product categories experience the most delivery delays? 

WITH Prod_Category_Orders As (
	select
		COALESCE(pc.product_category_id, 0) As product_category_id,
		COALESCE(pc.product_category_name, 'N/A') As Product_Category,
		COUNT(Distinct o.order_sk) As Total_Orders,
		CAST(
			AVG(--
				DATEDIFF(--
				DAY,
				o.purchase_date,
				o.delivered_customer_date
				)
			) As decimal(10,2)
		) As Avg_Delivery_Days

	from olist_dwh.gold.dim_orders o
	left join olist_dwh.gold.fact_order_items oi
		on o.order_sk = oi.order_sk
	left join olist_dwh.gold.dim_products p
		on oi.product_sk = p.product_sk
	left join olist_dwh.gold.dim_product_categories pc
		on p.product_category_id = pc.product_category_id
	group by 
		COALESCE(pc.product_category_id, 0),
		COALESCE(pc.product_category_name, 'N/A')
),

Prod_Category_Deleyed_Orders As (
	select 
		COALESCE(pc.product_category_id, 0) As product_category_id,
		COALESCE(pc.product_category_name, 'N/A') As Product_Category,
		COUNT(Distinct o.order_sk) As Delayed_Orders,
	
		CAST(
			AVG(--
				DATEDIFF(--
				DAY,
				o.expected_delivery_date,
				o.delivered_customer_date
				)
			) As decimal(10,2)
		) As Avg_Delay_Days

	from olist_dwh.gold.dim_orders o
	left join olist_dwh.gold.fact_order_items oi
		on o.order_sk = oi.order_sk
	left join olist_dwh.gold.dim_products p
		on oi.product_sk = p.product_sk
	left join olist_dwh.gold.dim_product_categories pc
		on p.product_category_id = pc.product_category_id
	where 
		o.delivered_customer_date > o.expected_delivery_date
	group by
		COALESCE(pc.product_category_id, 0),
		COALESCE(pc.product_category_name, 'N/A')
)

select
	TOP 10
	pco.product_category_id AS ID,
	pco.Product_Category,
	pco.Total_Orders,
	pcdo.Delayed_Orders,
	CAST(
		pcdo.Delayed_Orders * 100.00 
		/ pco.Total_Orders 
		As decimal(10,2)
	) As Delay_Rate,
	pcdo.Avg_Delay_Days

from Prod_Category_Orders pco
left join Prod_Category_Deleyed_Orders pcdo
	on pco.product_category_id = pcdo.product_category_id
where 
	pcdo.Delayed_Orders IS NOT NULL
	AND pco.Total_Orders >= 100
order by Delay_Rate desc;

/*
ID	Product_Category					Total_Orders	Delayed_Orders	Delay_Rate		Avg_Delay_Days
50	construcao ferramentas seguranca	167				16				9.58			12.00
49	livros interesse geral				512				43				8.40			13.00
43	moveis sala							422				34				8.06			12.00
20	consoles games						1062			85				8.00			11.00
11	alimentos bebidas					227				18				7.93			22.00
22	fashion calcados					240				19				7.92			7.00
16	telefonia fixa						217				17				7.83			13.00
55	artigos de natal					128				10				7.81			7.00
24	malas acessorios					1034			80				7.74			10.00
54	pcs									181				14				7.73			8.00
*/




--• How has delivery performance changed over time?

select 
	DATETRUNC(
		QUARTER, 
		purchase_date
	) As Quarter,

	COUNT(Distinct order_sk) As Delivered_Orders,

	CAST(
		AVG(--
			DATEDIFF(--
			DAY,
			purchase_date,
			delivered_customer_date
			)
		) As decimal(10,2)
	) As Avg_Delivery_Days,

	Count( 
		Distinct CASE 
			When delivered_customer_date > expected_delivery_date
			Then order_sk
		END ) As Delayed_Orders,

	CAST(
        COUNT(
            DISTINCT CASE
                WHEN delivered_customer_date > expected_delivery_date
                THEN order_sk
            END
        ) * 100.00
        / COUNT(DISTINCT order_sk)
        AS DECIMAL(10,2)
    ) AS Delay_Rate


from 
	olist_dwh.gold.dim_orders 
where
	order_status = 'DELIVERED'
group by 
	DATETRUNC(QUARTER, purchase_date)
order by 
	Quarter;




--• Does poor delivery performance lead to lower customer satisfaction 


WITH Orders_Delivery_Performance AS (
	select 
		o.order_sk,
		orv.review_score,
		CAST(
			DATEDIFF(
				DAY,
				o.expected_delivery_date,
				o.delivered_customer_date
			) As decimal(10,2)
		) As Delay_Days

	from olist_dwh.gold.dim_orders o
	join olist_dwh.gold.dim_order_reviews orv
		on o.order_sk = orv.order_sk
	where o.order_status = 'DELIVERED'
	AND o.expected_delivery_date IS NOT NULL
	AND o.delivered_customer_date IS NOT NULL
)

select 
	CASE
		WHEN Delay_Days = 0 THEN 'On Time'
		WHEN Delay_Days < 0 THEN 'Early'
		WHEN Delay_Days BETWEEN 1 AND 3 THEN '1-3 Days Late'
		WHEN Delay_Days BETWEEN 4 AND 7 THEN '4-7 Days Late'
		WHEN Delay_Days BETWEEN 8 AND 14 THEN '8-14 Days Late'
		WHEN Delay_Days BETWEEN 15 AND 30 THEN '15-30 Days Late'
		ELSE '30+ Days Late'
	END As Delay_Range,
	COUNT(order_sk) AS Total_Orders,
	CAST( 
		AVG(review_score)
		 As decimal(10,2)
	) As Avg_review_score
from Orders_Delivery_Performance
group by 
	CASE
		WHEN Delay_Days = 0 THEN 'On Time'
		WHEN Delay_Days < 0 THEN 'Early'
		WHEN Delay_Days BETWEEN 1 AND 3 THEN '1-3 Days Late'
		WHEN Delay_Days BETWEEN 4 AND 7 THEN '4-7 Days Late'
		WHEN Delay_Days BETWEEN 8 AND 14 THEN '8-14 Days Late'
		WHEN Delay_Days BETWEEN 15 AND 30 THEN '15-30 Days Late'
		ELSE '30+ Days Late'
	END
order by Avg_review_score;

/*
Delay_Range			Total_Orders	Avg_review_score
15-30 Days Late		967				1.00
8-14 Days Late		1403			1.00
30+ Days Late		309				2.00
4-7 Days Late		1737			2.00
1-3 Days Late		1950			3.00
Early				88163			4.00
On Time				1295			4.00
*/


--• Does delivery performance impact revenue? --> Revenue × Delivery

WITH Orders_Delivery_Performance AS (
    SELECT
        order_sk,
        order_status,
        CASE
            WHEN delivered_customer_date IS NULL OR expected_delivery_date IS NULL
                THEN 'Unknown'
            WHEN delivered_customer_date > expected_delivery_date
                THEN 'Late Delivery'
			WHEN delivered_customer_date < expected_delivery_date
                THEN 'Early Delivery'
            ELSE 'On Time'
        END AS Delivery_Performance
    FROM olist_dwh.gold.dim_orders
),
Order_Revenue AS (
    SELECT
        order_sk,
        SUM(payment_value) AS Order_Revenue
    FROM olist_dwh.gold.fact_order_payments
    GROUP BY order_sk
)
SELECT
    op.Delivery_Performance,
    COUNT(DISTINCT op.order_sk) AS Total_Orders,
    SUM(orv.Order_Revenue) AS Total_Revenue,
    CAST(
        100.0 * SUM(orv.Order_Revenue)
        / NULLIF(SUM(SUM(orv.Order_Revenue)) OVER (), 0)
        AS DECIMAL(10,2)
    ) AS Revenue_Percentage
FROM Orders_Delivery_Performance op
JOIN Order_Revenue orv
    ON op.order_sk = orv.order_sk
WHERE op.order_status = 'DELIVERED'
GROUP BY op.Delivery_Performance
ORDER BY Total_Revenue DESC;





-- •••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••
--••••••••••••••••••••• Sellers 🏪 ••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••

--• Which sellers have the highest order volume?

select 
	Top 10
	seller_sk,
	COUNT(DISTINCT order_sk) As Total_Orders,
	SUM(revenue) As Total_Revenue,
	CAST(
		SUM(revenue)
		/ COUNT(DISTINCT order_sk)
		As decimal(10,2)
	) AOV_per_Seller
from olist_dwh.gold.fact_order_items
group by seller_sk
having 
	COUNT(DISTINCT order_sk) > 100 
	AND SUM(revenue) > 10000
order by AOV_per_Seller DESC;



--• Which sellers have the best customer ratings? 

WITH Seller_Orders As (
	select DISTINCT
		seller_sk,
		order_sk
	from olist_dwh.gold.fact_order_items
)

select
	Top 5
	so.seller_sk,
	COUNT(DISTINCT so.order_sk) As Total_Orders,
	CAST(
		AVG(orv.review_score)
		  AS decimal(10,2)
	) As Avg_review_score
from Seller_Orders so
join olist_dwh.gold.dim_order_reviews orv
	on so.order_sk = orv.order_sk
group by so.seller_sk
having COUNT(DISTINCT so.order_sk) >= 100
order by Avg_review_score DESC;


--• Are high-revenue sellers also high-performing operationally?
With Seller_Orders As (
	select  
		oi.seller_sk,
		o.order_sk,
		SUM(oi.revenue) As Order_Revenue,
		CASE
			WHEN o.delivered_customer_date > o.expected_delivery_date THEN 'Delayed'
			WHEN o.delivered_customer_date < o.expected_delivery_date THEN 'Early'
			ELSE 'On Time'
		END As Order_Status
	from olist_dwh.gold.fact_order_items oi
	left join olist_dwh.gold.dim_orders o
		on oi.order_sk =o.order_sk
	where 
		o.order_status = 'DELIVERED'
		AND o.delivered_customer_date IS NOT NULL
		AND o.expected_delivery_date IS NOT NULL
	group by 
		oi.seller_sk,
		o.order_sk,
		o.delivered_customer_date,
		o.expected_delivery_date
)
select 
	Top 5
	seller_sk,
	COUNT(order_sk) As Total_Orders,
	SUM(Order_Revenue) As Total_Revenue,
	COUNT(
		CASE
			WHEN Order_Status = 'Delayed' THEN order_sk
		END
	) As Delayed_Orders,
	SUM(
		CASE
			WHEN Order_Status = 'Delayed' THEN Order_Revenue
			ELSE 0
		END
	) As Delayed_Revenue,
	CAST(
	COUNT(CASE
			WHEN Order_Status = 'Delayed' THEN order_sk
		END) * 100.00
		/ COUNT(order_sk)
		  AS decimal(10,2)
	) As Delayed_Delivery_Rate,
	CAST(
	SUM(CASE
			WHEN Order_Status = 'Delayed' THEN Order_Revenue
			ELSE 0
		END) * 100.00
		/ SUM(Order_Revenue)
		  AS decimal(10,2)
	) As Delayed_Revenue_Rate 
from Seller_Orders so
group by seller_sk
having COUNT(order_sk) >= 100
order by Total_Revenue DESC;



--• Which delivery performance have most sellers ?

With Seller_Orders As (
	select Distinct 
		oi.seller_sk,
		o.order_sk,
		CASE
			WHEN o.delivered_customer_date > o.expected_delivery_date 
				THEN 'Delayed'
			WHEN o.delivered_customer_date < o.expected_delivery_date 
				THEN 'Early'
			ELSE 'On Time'
		END As Delivery_Performance,
		orv.review_score
	from olist_dwh.gold.fact_order_items oi
	left join olist_dwh.gold.dim_orders o
		on oi.order_sk =o.order_sk
	join olist_dwh.gold.dim_order_reviews orv
		on o.order_sk = orv.order_sk
	where 
		o.order_status = 'DELIVERED'
		AND o.delivered_customer_date IS NOT NULL
		AND o.expected_delivery_date IS NOT NULL
)
select 
	Delivery_Performance,
	COUNT(seller_sk) As Total_Sellers,
	CAST(
		AVG(review_score * 1.0)
		  As decimal(10,2)
	) As Avg_review_score
from Seller_Orders
group by Delivery_Performance
order by Total_Sellers;




--• Which sellers have high sales but poor reviews?
	
WITH Sellers_Orders As (	
	select 
		oi.seller_sk,
		o.order_sk,
		SUM(oi.revenue) As Order_Revenue,
		orv.review_score

	from olist_dwh.gold.fact_order_items oi
	left join olist_dwh.gold.dim_orders o
		on oi.order_sk =o.order_sk
	join olist_dwh.gold.dim_order_reviews orv
		on o.order_sk = orv.order_sk
	where 
		o.order_status = 'DELIVERED'
		AND o.delivered_customer_date IS NOT NULL
		AND o.expected_delivery_date IS NOT NULL
	group by 
		oi.seller_sk,
		o.order_sk,
		orv.review_score
)
Select 
	Top 5
	seller_sk,
	COUNT(order_sk) As Total_Orders,
	SUM(Order_Revenue) As Total_Revenue,
	CAST(
		AVG(review_score)
		  As decimal(10,2)
	) As Avg_review_score 
from Sellers_Orders
group by seller_sk 
having 
	COUNT(order_sk) >= 100
	AND CAST(AVG(review_score) 
	As decimal(10,2)) < 4
order by 
	Total_Revenue DESC,
	Avg_review_score ASC;



--• Which sellers should receive operational attention? 


WITH Sellers_Orders As (	
	select 
		oi.seller_sk,
		o.order_sk,
		SUM(oi.revenue) As Order_Revenue,
		CASE
			WHEN o.delivered_customer_date > o.expected_delivery_date THEN 'Delayed'
			WHEN o.delivered_customer_date < o.expected_delivery_date THEN 'Early'
			ELSE 'On Time'
		END As Order_Status,
		orv.review_score
	from olist_dwh.gold.fact_order_items oi
	left join olist_dwh.gold.dim_orders o
		on oi.order_sk =o.order_sk
	join olist_dwh.gold.dim_order_reviews orv
		on o.order_sk = orv.order_sk
	where 
		o.order_status = 'DELIVERED'
		AND o.delivered_customer_date IS NOT NULL
		AND o.expected_delivery_date IS NOT NULL
	group by 
		oi.seller_sk,
		o.order_sk,
		orv.review_score,
		o.delivered_customer_date,
		o.expected_delivery_date
),
Seller_Orders_Status As (
	Select 
		seller_sk,
		COUNT(order_sk) As Total_Orders,
		SUM(Order_Revenue) As Total_Revenue,
		COUNT(
			CASE
				WHEN Order_Status = 'Delayed' THEN order_sk
			END
		) As Delayed_Orders,
		SUM(
			CASE
				WHEN Order_Status = 'Delayed' THEN Order_Revenue
				ELSE 0
			END
		) As Delayed_Revenue,
		CAST(
			COUNT(CASE
				WHEN Order_Status = 'Delayed' THEN order_sk
			END) * 100.00
			/ COUNT(order_sk)
			  AS decimal(10,2)
		) As Delayed_Delivery_Rate,
		CAST(
			SUM(CASE
				WHEN Order_Status = 'Delayed' THEN Order_Revenue
				ELSE 0
			END) * 100.00
			/ sUM(Order_Revenue)
			  AS decimal(10,2)
		) As Delayed_Revenue_Rate,
		CAST(
			AVG(review_score)
			  As decimal(10,2)
		) As Avg_review_score 
	from Sellers_Orders
	group by seller_sk 
)
select *
from Seller_Orders_Status
where Total_Orders >= 100
	  AND Delayed_Delivery_Rate > 10
	  AND  Delayed_Revenue_Rate > 10;

/*
seller_sk	Total_Orders	Total_Revenue	Delayed_Orders	Delayed_Revenue		Delayed_Delivery_Rate	Delayed_Revenue_Rate	Avg_review_score
277			128				16075.14		15				1740.60				11.72 %					10.83 %					3.00
453			141				15789.68		15				1755.24				10.64 %					11.12 %					3.00
665			113				21768.27		14				2914.50				12.39 %					13.39 %					4.00
2622		222				9132.80			24				1057.88				10.81 %					11.58 %					4.00
2497		172				14193.59		22				2058.48				12.79 %					14.50 %					3.00
*/




--• Are our top sellers actually our best-performing sellers?  


WITH Sellers_Orders As (
	select
		oi.seller_sk,
		o.order_sk,
		o.order_status,
		COALESCE(SUM(oi.revenue),0) As Order_Value,
		CASE
			WHEN o.order_status = 'DELIVERED'
				 AND o.delivered_customer_date > o.expected_delivery_date
				THEN 'Delayed'
			WHEN o.order_status = 'DELIVERED'
				 AND o.delivered_customer_date < o.expected_delivery_date
				THEN 'Early'
			WHEN o.order_status = 'DELIVERED'
				THEN 'On Time'
			ELSE 'N/A'
		END As Delivery_Performance,
		orv.review_score
	from olist_dwh.gold.fact_order_items oi
	left join olist_dwh.gold.dim_orders o
		on oi.order_sk =o.order_sk
	left join olist_dwh.gold.dim_order_reviews orv
		on o.order_sk = orv.order_sk
	group by 
		oi.seller_sk,
		o.order_sk,
		o.order_status,
		o.delivered_customer_date,
		o.expected_delivery_date,
		orv.review_score
)
Select
	Top 5
	seller_sk,
	COUNT(order_sk) As Total_Orders,
	SUM(Order_Value) As Total_Revenue,
	--------------------------------------------------
	-- Delivery Volume
	--------------------------------------------------
	COUNT(
		CASE
			WHEN Order_Status = 'DELIVERED' THEN order_sk
		END
	) As Delivered_Orders,
	COUNT(
		CASE
			WHEN Delivery_Performance = 'Delayed' THEN order_sk
		END
	) As Delayed_Orders,
	SUM(
		CASE
			WHEN Delivery_Performance = 'Delayed' THEN Order_Value
			ELSE 0
		END
	) As Delayed_Revenue,
	--------------------------------------------------
    -- Delivery Performance
    --------------------------------------------------
	CAST(
		COUNT(CASE
			WHEN Delivery_Performance = 'Delayed' THEN order_sk
		END) * 100.00
		/ 
		NULLIF(
            COUNT(
                CASE
                    WHEN Order_Status = 'DELIVERED' THEN order_sk
                END
            ), 0
		) 
		  AS decimal(10,2)
	) As Delayed_Delivery_Rate,
	CAST(
		SUM(CASE
			WHEN Delivery_Performance = 'Delayed' THEN Order_Value
			ELSE 0
		END) * 100.00
		/ 
		NULLIF(
            SUM(
                CASE
                    WHEN Order_Status = 'DELIVERED' THEN Order_Value
					ELSE 0
                END
            ), 0
		) 
		  AS decimal(10,2)
	) As Delayed_Revenue_Rate,
	 --------------------------------------------------
    -- Customer Satisfaction
    --------------------------------------------------
	CAST(
		AVG(review_score)
		  As decimal(10,2)
	) As Avg_review_score,
	--------------------------------------------------
    -- Other Order Statuses
    --------------------------------------------------
	COUNT(
		CASE
			WHEN Order_Status = 'INVOICED' THEN order_sk
		END
	) As Invoiced_Orders,
	COUNT(
		CASE
			WHEN Order_Status = 'PROCESSING' THEN order_sk
		END
	) As Processing_Orders,
	COUNT(
		CASE
			WHEN Order_Status = 'SHIPPED' THEN order_sk
		END
	) As Shipped_Orders,
	COUNT(
		CASE
			WHEN Order_Status = 'CANCELED' THEN order_sk
		END
	) As Canceled_Orders
from Sellers_Orders
group by seller_sk
having COUNT(order_sk) > = 100
order by Total_Revenue DESC;





-- •••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••
--••••••••••••••••••••• Customer Satisfaction ⭐ •••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••

--• What is the average review score?

select 
	CAST(
		AVG(review_score * 1.0)
		   As decimal(10,2)
	) As Avg_Score
from olist_dwh.gold.dim_order_reviews;


--• Which categories receive the best/worst reviews? 
-- best reviews
with Order_Category As (
select 
	DISTINCT
	oi.order_sk,
	pc.product_category_name_engilsh
from olist_dwh.gold.fact_order_items oi
join olist_dwh.gold.dim_products p
	on oi.product_sk = p.product_sk
join olist_dwh.gold.dim_product_categories pc
	on p.product_category_id = pc.product_category_id
)
select
	Top 5
	oc.product_category_name_engilsh,
	CAST(
		AVG(orv.review_score * 1.0)
		   As decimal(10,2)
	) As Avg_Score
from Order_Category oc
join olist_dwh.gold.dim_order_reviews orv
	on oc.order_sk = orv.order_sk
group by oc.product_category_name_engilsh
order by Avg_Score DESC;


-- worst reviews

with Order_Category As (
select 
	DISTINCT
	oi.order_sk,
	pc.product_category_name_engilsh
from olist_dwh.gold.fact_order_items oi
join olist_dwh.gold.dim_products p
	on oi.product_sk = p.product_sk
join olist_dwh.gold.dim_product_categories pc
	on p.product_category_id = pc.product_category_id
)
select
	Top 5
	oc.product_category_name_engilsh,
	CAST(
		AVG(orv.review_score * 1.0)
		   As decimal(10,2)
	) As Avg_Score
from Order_Category oc
join olist_dwh.gold.dim_order_reviews orv
	on oc.order_sk = orv.order_sk
group by oc.product_category_name_engilsh
order by Avg_Score ;


--• Does late delivery reduce review scores? 
WITH Orders_Status As (
	select 
		o.order_sk,
		CASE
			WHEN o.delivered_customer_date > o.expected_delivery_date THEN 'Late Delivery'
			WHEN o.delivered_customer_date < o.expected_delivery_date THEN 'Early Delivery'
			ELSE 'On Time'
		END AS Delivery_Status,
		orv.review_score
	from olist_dwh.gold.dim_orders o
	left join olist_dwh.gold.dim_order_reviews orv
		on o.order_sk = orv.order_sk
)
Select 
	Delivery_Status,
	COUNT(review_score) As Reviewed_Orders,

	CAST(
		AVG(review_score * 1.0)
		  As decimal(10,2)
	) As Avg_review_Score

from Orders_Status
group by Delivery_Status
order by Avg_review_Score DESC;



--• Which sellers have the highest/lowest ratings? 
-- highest ratings
with Orders_Review As (
	select
		o.order_sk,
		orv.review_score
	from olist_dwh.gold.dim_orders o
	left join olist_dwh.gold.dim_order_reviews orv
		on o.order_sk = orv.order_sk
),
Orders_by_Seller As (
	select Distinct 
		order_sk,
		seller_sk
	from olist_dwh.gold.fact_order_items
)
select
	TOP 5
	os.seller_sk,
	COUNT(orv.review_score) As Reviewed_Orders,

	CAST(
		AVG(orv.review_score * 1.0)
		As decimal(10,2)
	) As Avg_review_score
from Orders_Review orv
join Orders_by_Seller os
	on orv.order_sk = os.order_sk
group by os.seller_sk
having COUNT(orv.review_score) > 100
order by Avg_review_score desc;


-- lowest ratings
with Orders_Review As (
	select
		o.order_sk,
		orv.review_score
	from olist_dwh.gold.dim_orders o
	left join olist_dwh.gold.dim_order_reviews orv
		on o.order_sk = orv.order_sk
),
Orders_by_Seller As (
	select Distinct 
		order_sk,
		seller_sk
	from olist_dwh.gold.fact_order_items
)
select
	TOP 5
	os.seller_sk,
	COUNT(orv.review_score) As Reviewed_Orders,

	CAST(
		AVG(orv.review_score * 1.0)
		As decimal(10,2)
	) As Avg_review_score
from Orders_Review orv
join Orders_by_Seller os
	on orv.order_sk = os.order_sk
group by os.seller_sk
having COUNT(orv.review_score) > 100
order by Avg_review_score;

-- 102425 112650

--• Are expensive products rated differently from cheaper products?
WIth Product_Price_Range As (
select DISTINCT
	order_sk,
	product_sk,
	price,
	CASE 
		WHEN price BETWEEN 0 AND 50 THEN '0-50'
		WHEN price BETWEEN 51 AND 100 THEN '51-100'
		WHEN price BETWEEN 101 AND 500 THEN '101-500'
		WHEN price BETWEEN 501 AND 1000 THEN '501-1000'
		ELSE 'Above 1000'
	END Price_Range
from olist_dwh.gold.fact_order_items
),
Orders_Review As (
select 
	o.order_Sk,
	orv.review_score
from olist_dwh.gold.dim_orders o
left join olist_dwh.gold.dim_order_reviews orv
	on o.order_sk = orv.order_sk
)
select
	ppr.Price_Range,
	COUNT(ppr.product_sk) As Total_Order_Items,
	CAST(
		AVG(orv.review_score * 1.0)
		As decimal(10,2)
	) Avg_Review_Score
from Product_Price_Range ppr
join Orders_Review orv
	on ppr.order_sk = orv.order_sk
group by ppr.Price_Range;



--• Which States have lower customer satisfaction? 
with orders_Review_by_State As (
	select
		o.order_sk,
		l.state,
		orv.review_score
	from olist_dwh.gold.dim_orders o
	left join olist_dwh.gold.dim_order_reviews orv
		on o.order_sk = orv.order_sk
	left join olist_dwh.gold.dim_customers c
		on o.customer_sk = c.customer_sk
	left join olist_dwh.gold.dim_geo_location l
		on c.geo_location_sk = l.geo_location_sk
)
select
	Top 5
	state,
	COUNT(review_score) As Reviewed_Orders,
	CAST(
		AVG(review_score * 1.0)
		  As decimal(10,2)
	) Avg_Review_Score
from orders_Review_by_State
group by state
having COUNT(review_score) >= 100
order by Avg_Review_Score;


/*
state					Reviewed_Orders		Avg_Review_Score
AMAZONAS				145					3.98
PARAIBA					530					3.98
RIO GRANDE DO NORTE		482					4.00
MARANHAO				740					4.02
PARANA					4989				4.05
*/


--• What are the main operational factors associated with poor reviews? 
-- Delivery Delay

WITH Orders_by_Delivery_Performance As (
	select
		o.order_sk,
		orv.review_score,

		CASE
			WHEN o.delivered_customer_date IS NULL OR o.expected_delivery_date IS NULL 
				THEN 'UnKnown' 
			WHEN o.delivered_customer_date > o.expected_delivery_date THEN 'Late Delivery'
			WHEN o.delivered_customer_date < o.expected_delivery_date THEN 'Early Delivery'
			ELSE 'On Time'
		END As Delivery_Performance

	from olist_dwh.gold.dim_orders o
	left join olist_dwh.gold.dim_order_reviews orv
		on o.order_sk = orv.order_sk
	where o.order_status = 'DELIVERED'
)
select
	Delivery_Performance,
	COUNT(review_score) AS Reviewed_Orders,
	CAST(
		AVG(review_score * 1.0)
		  As decimal(10,2)
	) Avg_Review_Score,

	CAST(
		SUM(
			CASE
				WHEN review_score <= 2 THEN 1
				ELSE 0
			END) * 100.00
			/ NULLIF(COUNT(review_score) ,0)
		AS decimal(10,2)
	) As Poor_Review_Rate

from Orders_by_Delivery_Performance
group by Delivery_Performance
order by Poor_Review_Rate DESC;

/*
Delivery_Performance	Reviewed_Orders		Avg_Review_Score	Poor_Review_Rate
Late Delivery			6366				2.27				62.50
UnKnown					8					4.50				12.50
On Time					1295				4.04				12.43
Early Delivery			88163				4.29				9.22
*/



-- Delivery Duration

WITH Orders_by_Delivery_Duration As (
	select
		o.order_sk,
		DATEDIFF(
			DAY, o.purchase_date, o.delivered_customer_date
		) As Delivery_Duration,
		orv.review_score
	from olist_dwh.gold.dim_orders o
	left join olist_dwh.gold.dim_order_reviews orv
		on o.order_sk = orv.order_sk
	where o.order_status = 'DELIVERED'
)
select
	CASE
		WHEN Delivery_Duration BETWEEN 1 AND 3 THEN '1-3 Days'
		WHEN Delivery_Duration BETWEEN 4 AND 7 THEN '4-7 Days'
		WHEN Delivery_Duration BETWEEN 8 AND 14 THEN '8-14 Days'
		WHEN Delivery_Duration BETWEEN 15 AND 30 THEN '15-30 Days'
		ELSE 'Above 30 Days'
	END As Delivery_Duration_Range,
	COUNT(review_score) As Reviewed_Orders,
	CAST(
		AVG(review_score * 1.0)
		  As decimal(10,2)
	) Avg_Review_Score,

	CAST(
		SUM(
			CASE
				WHEN review_score <= 2 THEN 1
				ELSE 0
			END) * 100.00
			/ NULLIF(COUNT(review_score) ,0)
		AS decimal(10,2)
	) As Poor_Review_Rate

from Orders_by_Delivery_Duration
group by
	CASE
		WHEN Delivery_Duration BETWEEN 1 AND 3 THEN '1-3 Days'
		WHEN Delivery_Duration BETWEEN 4 AND 7 THEN '4-7 Days'
		WHEN Delivery_Duration BETWEEN 8 AND 14 THEN '8-14 Days'
		WHEN Delivery_Duration BETWEEN 15 AND 30 THEN '15-30 Days'
		ELSE 'Above 30 Days'
	END
order by MIN(Delivery_Duration)

/*
Delivery_Duration_Range		Reviewed_Orders		Avg_Review_Score	Poor_Review_Rate
Above 30 Days				4190				2.21				64.37
1-3 Days					6913				4.46				7.03
4-7 Days					23621				4.40				7.69
8-14 Days					37785				4.30				9.10
15-30 Days					23323				3.94				16.43
*/


-- Sellers Performance
with Orders_Reviews As (
	select DISTINCT
		o.order_sk,
		orv.review_score,
		oi.seller_sk
	from olist_dwh.gold.dim_orders o
	left join olist_dwh.gold.dim_order_reviews orv
		on o.order_sk = orv.order_sk
	left join olist_dwh.gold.fact_order_items oi
		on o.order_sk = oi.order_sk
	where o.order_status = 'DELIVERED'
),
Orders_Range As (
	select
		seller_sk,
		COUNT(order_sk) As Reviewed_Orders,
		CAST(
			AVG(review_score * 1.0)
			  As decimal(10,2)
		) As Avg_Review_Score,

		SUM(
			CASE
				WHEN review_score <= 2 THEN 1
				ELSE 0
			END
		) As Poor_Review,

		CASE
			WHEN COUNT(review_score) BETWEEN 1 AND 20 THEN '1-20 Orders'
			WHEN COUNT(review_score) BETWEEN 21 AND 50 THEN '21-50 Orders'
			WHEN COUNT(review_score) BETWEEN 51 AND 100 THEN '51-100 Orders'
			WHEN COUNT(review_score) BETWEEN 101 AND 500 THEN '101-500 Orders'
			WHEN COUNT(review_score) BETWEEN 501 AND 1000 THEN '501-1000 Orders'
			ELSE 'Above 1000 Orders' 
		END Orders_Range

	from Orders_Reviews
	group by seller_sk
)
select
	Orders_Range,
	COUNT(seller_sk) As Sellers,
	CAST(
		AVG(Avg_Review_Score * 1.0)
		  As decimal(10,2)
	) As Avg_Review_Score,

	CAST(
		SUM(Poor_Review) * 100.0 
		/ NULLIF(SUM(Reviewed_Orders), 0) 
	    AS DECIMAL(10,2) 
	) AS Poor_Review_Rate

from Orders_Range
group by Orders_Range
order by Poor_Review_Rate;

/*
Orders_Range		Sellers		Avg_Review_Score	Poor_Review_Rate
1-20 Orders			2282		4.16				12.44
51-100 Orders		203			4.15				12.53
21-50 Orders		377			4.16				12.75
101-500 Orders		179			4.15				12.79
Above 1000 Orders	17			4.15				12.81
501-1000 Orders		13			4.14				13.12
*/


-- Freight Cost
WITH Orders_Delivery_Value As (
	select DISTINCT
		oi.order_sk,
		oi.product_sk,
		oi.freight_value,
		orv.review_score,
		CASE 
			WHEN oi.freight_value BETWEEN 0 AND 10 THEN '0-10 $'
			WHEN oi.freight_value BETWEEN 11 AND 20 THEN '11-20 $'
			WHEN oi.freight_value BETWEEN 21 AND 50 THEN '21-50 $'
			WHEN oi.freight_value BETWEEN 51 AND 100 THEN '51-100 $'
			ELSE 'Above 100 $'
		END As freight_value_Range
	from olist_dwh.gold.fact_order_items oi
	left join olist_dwh.gold.dim_order_reviews orv
		on oi.order_sk = orv.order_sk
)
select
	freight_value_Range,
	COUNT(product_sk) As Products,
	CAST(
		AVG(review_score * 1.0)
		  As decimal(10,2)
	) As Avg_Review_Score,

	CAST(
		SUM(
			CASE
				WHEN review_score <= 2 THEN 1
				ELSE 0
			END) * 100.00
			/ NULLIF(COUNT(review_score) ,0)
		AS decimal(10,2)
	) As Poor_Review_Rate

from Orders_Delivery_Value
group by freight_value_Range
order by Poor_Review_Rate DESC;

/*
freight_value_Range		Products	Avg_Review_Score	Poor_Review_Rate
51-100 $				3438		4.08				15.36
21-50 $					22166		4.07				14.95
11-20 $					58239		4.09				14.60
Above 100 $				4484		4.08				14.57
0-10 $					14098		4.10				14.36
*/



-- •••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••
--••••••••••••••••••••• Payments 💳 ••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••

--• Which payment methods are most popular?

select 
	payment_type,
	COUNT(*) As Payment_Count,
	SUM(payment_value) As Total_Payment_Value
from olist_dwh.gold.fact_order_payments
group by payment_type
order by Total_Payment_Value desc;


--• What is the average Payment value by Payment Method and Which payment methods are associated with larger purchases?

select 
	payment_type,
	COUNT(*) As Payment_Count,
	SUM(payment_value) As Total_Payment_Value,
	CAST(
		SUM(payment_value) 
		/ NULLIF(COUNT(*), 0) 
		  As decimal(10,2)
	) As Avg_Payment_Method
from olist_dwh.gold.fact_order_payments
group by payment_type
order by Avg_Payment_Method desc;


--• How has payment-method usage changed over time? 

WITH Payments_Types_Performance As(
select 
	YEAR(o.purchase_date) As Year,
	op.payment_type,
	COUNT(op.payment_type) As Payment_Count,
	SUM(op.payment_value) As Total_Payment_Value
from olist_dwh.gold.fact_order_payments op
join olist_dwh.gold.dim_orders o
	on op.order_sk = o.order_sk
group by YEAR(o.purchase_date), op.payment_type
),
Performance_YOY as (
select
	Year,
	payment_type,
	Payment_Count,
	COALESCE(
		LAG(Payment_Count) OVER(
			PARTITION BY payment_type 
			ORDER BY Year ) ,0	
	) As Prev_Payment_Count,
	COALESCE(
		Payment_Count 
			- LAG(Payment_Count) OVER(
				PARTITION BY payment_type 
				ORDER BY Year) , 0
	) As Payment_Count_Change,
	Total_Payment_Value
from Payments_Types_Performance 
)
select *
from Performance_YOY
where Year = 2018;



--• Which State prefer which payment methods? 

WITH Orders_per_Payment_Type As (
select
	o.order_sk,
	l.state,
	op.payment_type
from olist_dwh.gold.fact_order_payments op
join olist_dwh.gold.dim_orders o
	on op.order_sk = o.order_sk
join olist_dwh.gold.dim_customers c
	on o.customer_sk = c.customer_sk
join olist_dwh.gold.dim_geo_location l
	on c.geo_location_sk = l.geo_location_sk
),
Payment_Count As(
select
	state,
	payment_type,
	COUNT(*) As Payment_Count,
	ROW_NUMBER() OVER(
		PARTITION BY state
		ORDER BY COUNT(*) DESC
	) As Payment_Rank
from Orders_per_Payment_Type
group by state,	payment_type
)
select 
	state,
	payment_type,
	Payment_Count
from Payment_Count
where Payment_Rank = 1
order by state;



--• How many installments are customers using? 

select
	Top 5
	payment_installments,
	COUNT(*) As Payment_Count
from olist_dwh.gold.fact_order_payments
group by payment_installments
order by Payment_Count DESC;



--• Does installment usage correlate with higher order values?

WITH Orders_Payment_Summary AS (
    SELECT
        order_sk,
        MAX(payment_installments) AS payment_installments,
        SUM(payment_value) AS Order_Payment_Value,
        COUNT(*) AS Payment_Records
    FROM olist_dwh.gold.fact_order_payments
    GROUP BY order_sk
)
SELECT
    TOP 10
	payment_installments,
    COUNT(*) AS Orders_Count,
    CAST(
        AVG(Order_Payment_Value) AS DECIMAL(12,2)
    ) AS Avg_Order_Payment_Value,
    CAST(
        SUM(Order_Payment_Value) AS DECIMAL(14,2)
    ) AS Total_Payment_Value
FROM Orders_Payment_Summary
WHERE Payment_Records = 1
GROUP BY payment_installments
ORDER BY Avg_Order_Payment_Value DESC;




-- •••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••
--••••••••••••••••••••• Geographic Analysis 🌎 •••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••

--• Which states generate the highest revenue?

select 
	Top 10
	COALESCE(l.state, 'N/A') As State,
	SUM(op.payment_value) As Total_Revenue
from olist_dwh.gold.fact_order_payments op
left join  olist_dwh.gold.dim_orders o
	on op.order_sk = o.order_sk
left join  olist_dwh.gold.dim_customers c
	on o.customer_sk = c.customer_sk
left join  olist_dwh.gold.dim_geo_location l
    on c.geo_location_sk = l.geo_location_sk
group by COALESCE(l.state, 'N/A')
order by Total_Revenue desc;



--• Which States have high order volume but low revenue? 
with States_Performance as (
select 
	COALESCE(l.state, 'N/A') As State,
	COUNT(DISTINCT c.customer_unique_id) As Customers,
	COUNT(distinct o.order_sk) As Total_Orders,
	SUM(op.payment_value) As Total_Revenue,
	CAST(
	SUM(op.payment_value) / COUNT(distinct o.order_sk)
	As decimal(10,2)
	) As AOV
from olist_dwh.gold.dim_orders o
left join olist_dwh.gold.fact_order_payments op
	on op.order_sk = o.order_sk
left join olist_dwh.gold.dim_customers c
    on o.customer_sk = c.customer_sk
left join olist_dwh.gold.dim_geo_location l
	on c.geo_location_sk = l.geo_location_sk
group by COALESCE(l.state, 'N/A')
)
select 
	*
from States_Performance 
where 
	Total_Orders > 1000
	AND Total_Revenue < 500000
order by Total_Orders DESC;


--• Which states have the highest number of customers?

select 
	Top 10
	l.city,
	COUNT(DISTINCT c.customer_unique_id) As Customers
from olist_dwh.gold.dim_customers c
join olist_dwh.gold.dim_geo_location l
	on c.geo_location_sk = l.geo_location_sk
group by l.city
order by Customers DESC;


--• Which regions have the longest delivery times? 

select
	Top 10
	l.state,
	CAST(
		AVG(
			DATEDIFF(
				DAY,
				o.purchase_date,
				o.delivered_customer_date
			) * 1.0 
		)
		AS Decimal(10,2) 
	) As Avg_Delivery_Days
from olist_dwh.gold.dim_orders o
join olist_dwh.gold.dim_customers c
	on o.customer_sk = c.customer_sk
join olist_dwh.gold.dim_geo_location l
	on c.geo_location_sk = l.geo_location_sk
group by l.state
order by Avg_Delivery_Days DESC;


--• Which States have the highest cancellation rates?

select
	Top 10
	l.state,
	COUNT(o.order_sk) As Total_Orders,
	COUNT(
		CASE 
			WHEN o.order_status = 'CANCELED' THEN o.order_sk
		END ) As Canceled_Orders,
	CAST(
		COUNT(CASE 
				WHEN o.order_status = 'CANCELED' THEN o.order_sk
			END ) * 100.00
		/ COUNT(o.order_sk)
		  As decimal(10,2)
	) As Canceled_Orders_Rate
from olist_dwh.gold.dim_orders o
join olist_dwh.gold.dim_customers c
	on o.customer_sk = c.customer_sk
join olist_dwh.gold.dim_geo_location l
	on c.geo_location_sk = l.geo_location_sk
group by l.state
order by Canceled_Orders_Rate DESC;


--• Are there underserved regions with high demand? 
/*
KPI						بيوضح إيه؟
Total_Orders			حجم الطلب في المنطقة
Late_Delivery_Rate		نسبة الطلبات المتأخرة
Cancellation_Rate		نسبة الطلبات الملغاة
Avg_Delivery_Days		متوسط مدة التوصيل
Avg_Review_Score		متوسط تقييمات العملاء	

DELIVERED
CANCELED
*/
WITH Orders_Performance As (
	select 
		o.order_sk,--
		l.state,--
		o.order_status,--
		DATEDIFF(DAY,
			o.purchase_date,
			o.delivered_customer_date
		) As Delivery_Days,
		DATEDIFF(DAY,
			o.expected_delivery_date,
			o.delivered_customer_date			
		) As Delayed_Delivery_Days,
		CASE 
			WHEN o.order_status = 'CANCELED' THEN 'Canceled'
			WHEN o.delivered_customer_date IS NULL OR o.expected_delivery_date IS NULL 
				THEN 'Unknown'
			WHEN o.order_status = 'DELIVERED' 
				AND o.delivered_customer_date > o.expected_delivery_date
				THEN 'Late Delivered'
			WHEN o.order_status = 'DELIVERED' 
				AND o.delivered_customer_date < o.expected_delivery_date
				THEN 'Early Delivered'
			ELSE 'On Time'
		END As Order_Performance,
		orv.review_score
	from olist_dwh.gold.dim_orders o
	join olist_dwh.gold.dim_customers c
		on o.customer_sk = c.customer_sk
	join olist_dwh.gold.dim_geo_location l
		on c.geo_location_sk = l.geo_location_sk
	left join olist_dwh.gold.dim_order_reviews orv
		on o.order_sk = orv.order_sk
	where o.order_status IN ('DELIVERED', 'CANCELED')
),
Orders_Performance_by_State As (
	select
		state,
		COUNT(order_sk) As Total_Orders,

		--******* Delivered Orders - Delivery Rate  *******
		CAST(
			SUM(CASE 
					WHEN order_status = 'DELIVERED' THEN 1
					ELSE 0
				END ) * 100.00
			/ COUNT(order_sk)
			  As decimal(10,2)
		) As Delivered_Orders_Rate,
		---------------------------------------------------
		-- ** Order_Performance breakedown 
		---------------------------------------------------
		CAST(
			SUM(
				CASE 
					WHEN Order_Performance = 'Late Delivered' THEN 1
					ELSE 0
				END) * 100.00
			/ SUM(
				CASE 
					WHEN order_status = 'DELIVERED' THEN 1
					ELSE 0
				END) 
			 As decimal(10,2)
		) As Late_Delivered_Rate,

		CAST(
			SUM(
				CASE 
					WHEN Order_Performance = 'Early Delivered' THEN 1
					ELSE 0
				END) * 100.00
			/ SUM(
				CASE 
					WHEN order_status = 'DELIVERED' THEN 1
					ELSE 0
				END) 
			 As decimal(10,2)
		) As Early_Delivered_Rate,

		CAST(
			SUM(
				CASE 
					WHEN Order_Performance = 'On Time' THEN 1
					ELSE 0
				END) * 100.00
			/ SUM(
				CASE 
					WHEN order_status = 'DELIVERED' THEN 1
					ELSE 0
				END) 
			 As decimal(10,2)
		) As OnTime_Delivered_Rate,
		---------------------------------------------------
		-- ** Canceled Orders - Delivery Rate
		---------------------------------------------------
		CAST(
			SUM(CASE 
					WHEN order_status = 'CANCELED' THEN 1
					ELSE 0
				END ) * 100.00
			/ COUNT(order_sk)
			  As decimal(10,2)
		) As Canceled_Orders_Rate,
		---------------------------------------------------
		-- ** Avg_review_score
		---------------------------------------------------
		CAST(
			AVG(review_score * 1.0)
			  As decimal(10,2)
		) As Avg_review_score

	from Orders_Performance
	group by state
)
select *
from Orders_Performance_by_State
where Total_Orders > 500 AND Late_Delivered_Rate < 6.5
order by Total_Orders DESC;


/*
state		Total_Orders	Delivered_Rate	Late_Rate	Early_Rate	OnTime_Rate		Canceled_Rate	Avg_review_score
GOIAS		1970			99.59			6.27		92.41		1.33			0.41			4.15
CEARA		1295			99.38			5.91		92.46		1.63			0.62			4.12
PARA		950				99.16			5.94		93.42		0.64			0.84			4.23
MARANHAO	724				98.62			5.60		92.72		1.68			1.38			4.09
*/


--• Is revenue concentrated in a small number of states? 
WITH Orders_Value As (
	select
		o.order_sk,
		SUM(op.payment_value) As Order_Value
	from olist_dwh.gold.fact_order_payments op
	join olist_dwh.gold.dim_orders o
		on op.order_sk = o.order_sk
	group by o.order_sk
),
Orders_with_States As (
	select
	o.order_sk,
	l.state
	from olist_dwh.gold.dim_orders o
	left join olist_dwh.gold.dim_customers c
		on o.customer_sk = c.customer_sk
	left join olist_dwh.gold.dim_geo_location l
		on c.geo_location_sk = l.geo_location_sk
)
select
	os.state,
	COUNT(ov.order_sk) As Total_Orders,
	SUM(ov.Order_Value) As Total_Revenue,
	CAST(
		SUM(ov.Order_Value) * 100.00
		/ SUM(SUM(ov.Order_Value)) OVER()
		As decimal(10,2)
	) As Revenue_Rate
from Orders_Value ov
join Orders_with_States os
	on ov.order_sk = os.order_sk
group by os.state
order by Revenue_Rate DESC;

/*
state			Total_Orders	Total_Revenue	Revenue_Rate
SAO PAULO		41727			6693100.71		41.81
RIO DE JANEIRO	12838			2085766.18		13.03
MINAS GERAIS	11623			1867835.70		11.67

----------------------------------------------------------------------

** Finding: Revenue is concentrated in three major states: São Paulo, Rio de Janeiro, and Minas Gerais.

** Key Insight:These three states collectively contribute 66.51% of total revenue, 
while all remaining states account for 33.49%.

** Business Implication: Revenue generation is geographically concentrated, particularly in São Paulo, which alone contributes 41.81% of total revenue. 
This highlights the importance of monitoring business performance and potential operational risks in the company's largest revenue-generating markets.

*/

















