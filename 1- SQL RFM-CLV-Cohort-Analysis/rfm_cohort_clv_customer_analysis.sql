-- All Syntax

CREATE TABLE customers (
    customer_id        VARCHAR(20) PRIMARY KEY,
    first_name         VARCHAR(50),
    last_name          VARCHAR(50),
    full_name          VARCHAR(100),
    gender             VARCHAR(10),
    dob                DATE,
    age                INT,
    age_band           VARCHAR(20),
    country            VARCHAR(50),
    state              VARCHAR(50),
    city               VARCHAR(50),
    postal_code        VARCHAR(20),
    email              VARCHAR(100),
    phone              VARCHAR(20),
    signup_date        DATE,
    signup_channel     VARCHAR(30),
    device             VARCHAR(30),
    marketing_opt_in   BOOLEAN,
    referral_source    VARCHAR(50)
);

CREATE TABLE transactions (
    invoice_no        VARCHAR(20) PRIMARY KEY,
    invoice_date      DATE,
    customer_id       VARCHAR(20),
    product_category  VARCHAR(50),
    quantity          INT,
    unit_price        NUMERIC(10,2),
    discount_applied  NUMERIC(5,2),
    payment_method    VARCHAR(30),
    total_amount      NUMERIC(12,2),
    FOREIGN KEY (customer_id) REFERENCES customers(customer_id)
);

-- Phase 1: Data Preparation

-- Q1.Calculate Recency, Frequency, Monetary (RFM) values for each customer.

-- Latest Transaction Date
Select max(signup_date) as latest_date
from customers

-- RFM Values per Customer
select c.customer_id,
	(date '2024-12-30' - max(t.invoice_date)):: int as recency,
	count(distinct t.invoice_no) as frequency,
	sum(t.total_amount) as monetary
	from transactions t
	join customers c on c.customer_id = t.customer_id
	group by c.customer_id
	

-- Q2.Assign RFM scores (1–5) for each metric and create overall RFM segmentation.
with customer_metrics as (
select c.customer_id,
	(date '2024-12-30' - max(t.invoice_date)):: int as recency,
	count(distinct t.invoice_no) as frequency,
	sum(t.total_amount) as monetary
	from transactions t
	join customers c on c.customer_id = t.customer_id
	group by c.customer_id
),

rfm_scores as (
select customer_id,
recency,
frequency,
monetary,
NTILE(5) OVER (Order by recency asc) as r_score,
NTILE(5) OVER(order by frequency desc) as f_score,
NTILE(5) OVER (Order by monetary desc) as m_score
from customer_metrics)

select customer_id,
recency, frequency, monetary,
r_score, f_score, m_score,
(r_score + f_score + m_score) as rfm_total,
case
    WHEN r_score >= 4 AND f_score >= 4 AND m_score >= 4 THEN 'Champions'
    WHEN r_score >= 3 AND f_score >= 4 THEN 'Loyal Customers'
    WHEN r_score >= 4 AND f_score = 3 THEN 'Potential Loyalists'
    WHEN r_score = 5 AND f_score = 1 THEN 'New Customers'
    WHEN r_score = 4 AND f_score = 1 THEN 'Promising'
    WHEN r_score <= 2 AND f_score >= 4 THEN 'At Risk'
    WHEN r_score = 1 AND m_score >= 4 THEN 'Can’t Lose Them'
    WHEN r_score = 2 AND f_score = 2 AND m_score = 2 THEN 'Hibernating'
    ELSE 'Lost'
END AS segment
into customer_segments
from rfm_scores

select * from customer_segments


-- Q3.Join RFM segments with customer demographic data.
SELECT 
    c.customer_id,
    c.full_name,
    c.gender,
    c.age,
    c.age_band,
    c.country,
    c.state,
    c.signup_channel,
    c.device,
    s.r_score,
    s.f_score,
    s.m_score,
    s.rfm_total,
    s.segment
FROM customers c
JOIN customer_segments s ON c.customer_id = s.customer_id;



-- Phase 2: Customer Segmentation Insights

-- Q1.How many customers are in each RFM segment?
Select segment,
count(customer_id) as customer_count
from customer_segments
group by segment
order by customer_count desc


-- Q2.Which top 10 customers bring the highest revenue?
Select t.customer_id,
sum(t.total_amount) as total_revenue
from transactions t
group by t.customer_id
order by total_revenue desc
limit 10


-- Q3.What percentage of revenue comes from the top 20% customers? (Pareto)
With revenue_per_customer as (
select customer_id,
sum(total_amount) as total_revenue
from transactions
group by customer_id
), 

ranked_customers as (
select customer_id,
total_revenue,
ntile(5) over (order by total_revenue desc) as revenue_rank
from revenue_per_customer
)

Select round(sum(total_revenue)/(select sum(total_revenue) from revenue_per_customer) * 100.0,2)
from ranked_customers 
where revenue_rank = 1


-- Q4.Average order value per customer segment?
With order_values as (
select customer_id,
avg(total_amount) as avg_order_value
from transactions 
group by customer_id
)

select s.segment,
avg(o.avg_order_value) as avg_order_value_per_segment
from customer_segments s
join order_values o on s.customer_id = o.customer_id
group by 1
order by 2 desc



-- Phase 3: Demographic Analysis

-- Q1.Revenue by age band?
Select
    c.age_band,
    sum(t.total_amount) AS total_revenue
From transactions t
Join customers c on t.customer_id = c.customer_id
group by  c.age_band
order by total_revenue desc

-- Q2.Revenue by gender?
Select c.gender,
sum(total_amount) as total_revenue
from customers c 
join transactions t on c.customer_id = t.customer_id
group by 1

-- Q3.Revenue by State
Select c.state,
sum(total_amount) as total_revenue
from customers c 
join transactions t on c.customer_id = t.customer_id
group by 1

-- Q4.Revenue by city
Select c.city,
sum(total_amount) as total_revenue
from customers c 
join transactions t on c.customer_id = t.customer_id
group by 1
order by 2 desc 
limit 10

-- Q5.Average number of transactions per customer by signup channel?
SELECT signup_channel,
avg(invoice_no) as avg_transactions
from customers c
join transactions t on c.customer_id = t.customer_id



-- Phase 4: Product & Payment Insights

-- Q1.Top-selling product categories (by quantity)?
Select product_category,
sum(quantity) as total_quantity
from transactions
group by product_category
order by sum(quantity) desc
limit 5

-- Q2.Which product category generates the highest revenue?
Select product_category,
sum(total_amount) as total_quantity
from transactions
group by product_category
order by sum(total_amount) desc
limit 1

-- Q3.Average discount percentage by product category 
Select product_category,
round(avg(discount_applied),2) as avg_discount_percentage
from transactions
group by product_category

-- Q4.Preferred payment method by revenue?
Select payment_method,
sum(total_amount) as total_revenue
from transactions
group by payment_method
order by total_revenue desc
limit 1

-- Q5.Product category analysis by customer segment (Segment vs Category revenue).
SELECT 
    s.segment,
    sum(t.total_amount) FILTER (where t.product_category = 'Electronics') AS electronics_revenue,
    sum(t.total_amount) FILTER (where t.product_category = 'Grocery') AS grocery_revenue,
    sum(t.total_amount) FILTER (where t.product_category = 'Home & Kitchen') AS home_kitchen_revenue,
    sum(t.total_amount) FILTER (where t.product_category = 'Beauty & Personal Care') AS beauty_personal_revenue
from transactions t
join customer_segments s ON t.customer_id = s.customer_id
group by s.segment
order by s.segment;



-- Phase 5: Time & Retention Analysis

-- Q1.Monthly revenue trend (overall)?
Select extract(month from invoice_date ) as month,
sum(total_amount) as total_revenue
from transactions
group by 1
order by 1

-- Q2.Seasonality – Which month had the highest revenue?
Select 
to_char(invoice_date, 'Month') as Month,
sum(total_amount) as total_revenue
from transactions 
group by 1
order by 2 desc
limit 1

-- Q3.Cohort analysis (retention by signup month)?
with first_purchase as (
select customer_id,
min(date_trunc('month', invoice_date)) as first_month_purchase
from transactions
where date_trunc('month', invoice_date) >= '2024-01-01'
group by 1
),

cohort_orders as(
select fp.customer_id,
first_month_purchase as cohort_month,
date_trunc('month', t.invoice_date) as order_month
from first_purchase fp
join transactions t on t.customer_id = fp.customer_id
),

cohort_size as (
select first_month_purchase as cohort_month,
count(distinct customer_id) as cohort_size
from first_purchase 
group by 1
),

retention_cte as (
select 
cohort_month,
(extract(year from order_month)*12 + extract(month from order_month)) -
(extract(year from cohort_month)* 12 + extract(month from cohort_month)) as month_offset,
count(distinct customer_id) as retained_customers
from cohort_orders
group by 1,2
)

select
r.cohort_month,
round(100.0 * max(case when month_offset = 0 then retained_customers end)/cs.cohort_size,2) as month0,
round(100.0 * max(case when month_offset = 1 then retained_customers end)/cs.cohort_size,2) as month1,
round(100.0 * max(case when month_offset = 2 then retained_customers end)/cs.cohort_size,2) as month2,
round(100.0 * max(case when month_offset = 3 then retained_customers end)/cs.cohort_size,2) as month3
from retention_cte r
join cohort_size cs on r.cohort_month = cs.cohort_month
group by r.cohort_month,cs.cohort_size
order by 1



--Phase 6: Customer Value & Retention

-- Q.Customer Lifetime Value (CLV) calculation by segment
WITH customer_spend AS (
    SELECT 
        t.customer_id,
        SUM(t.total_amount) AS total_revenue,
        COUNT(DISTINCT t.invoice_no) AS total_orders
    FROM transactions t
    GROUP BY t.customer_id
),
customer_clv AS (
    SELECT 
        customer_id,
        ROUND(total_revenue, 2) AS clv
    FROM customer_spend
),
-- Calculate percentile thresholds
clv_thresholds AS (
    SELECT 
        PERCENTILE_CONT(0.33) WITHIN GROUP (ORDER BY clv) AS p33,
        PERCENTILE_CONT(0.66) WITHIN GROUP (ORDER BY clv) AS p66
    FROM customer_clv
)
SELECT 
    c.customer_id,
    c.clv,
    CASE 
        WHEN c.clv >= (SELECT p66 FROM clv_thresholds) THEN 'High CLV'
        WHEN c.clv >= (SELECT p33 FROM clv_thresholds) THEN 'Medium CLV'
        ELSE 'Low CLV'
    END AS clv_segment
FROM customer_clv c




































