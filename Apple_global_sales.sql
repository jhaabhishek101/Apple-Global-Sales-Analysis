/*
====================================================
Apple global sales analysis using sql

dataset size : 11,500 transactions
database : postgresql
concepts covered :
- group by
- having
- case
- subqueries
- ctes
- window functions
- rank
- dense_rank
- row_number
- lag
====================================================
*/

DROP TABLE IF EXISTS apple_sales;
CREATE TABLE apple_sales (
    sale_id VARCHAR(20),
    sale_date DATE,
    year INTEGER,
    quarter VARCHAR(5),
    month VARCHAR(20),
    country VARCHAR(50),
    region VARCHAR(50),
    city VARCHAR(50),
    product_name VARCHAR(100),
    category VARCHAR(50),
    storage VARCHAR(30),
    color VARCHAR(30),
    unit_price_usd NUMERIC(10,2),
    discount_pct NUMERIC(5,2),
    units_sold INTEGER,
    discounted_price_usd NUMERIC(10,2),
    revenue_usd NUMERIC(12,2),
    currency VARCHAR(10),
    fx_rate_to_usd NUMERIC(10,4),
    revenue_local_currency NUMERIC(14,2),
    sales_channel VARCHAR(50),
    payment_method VARCHAR(30),
    customer_segment VARCHAR(30),
    customer_age_group VARCHAR(20),
    previous_device_os VARCHAR(20),
    customer_rating NUMERIC(3,2),
    return_status VARCHAR(20),
    day_of_week VARCHAR(20),
    month_number INTEGER,
    quarter_number INTEGER,
    discount_amount NUMERIC(10,2),
    return_flag INTEGER,
    price_band VARCHAR(30),
    rating_category VARCHAR(30),
    discount_bucket VARCHAR(20)
);

/*---------------------------------------------------
BUSINESS QUESTIONS
-----------------------------------------------------
*/

--Q1. What is the overall business performance in terms of total transactions, total units sold, total revenue, and average selling price?

select 
	count(*) as total_transactions,
	sum(units_sold) as total_units_sold,
	round(sum(revenue_usd),2) as total_revenue,
	round(avg(discounted_price_usd),2) as average_selling_price
from apple_sales;

--Q2. Which product categories generate the highest revenue?

select
    category,
    round(sum(revenue_usd), 2) as total_revenue
from apple_sales
group by category
order by total_revenue desc;

--Q3. Which product categories sold the highest number of units?

select
    category,
    sum(units_sold) as total_units_sold
from apple_sales
group by category
order by total_units_sold desc;

--Q4. Which sales channels generated the highest revenue?

select
    sales_channel,
    round(sum(revenue_usd),2) as total_revenue
from apple_sales
group by sales_channel
order by total_revenue desc;

--Q5. Which countries generated the highest revenue? (Top 10)

select
    country,
    round(sum(revenue_usd),2) as total_revenue
from apple_sales
group by country
order by total_revenue desc
limit 10;

--Q6. Which customer segments generate the highest revenue and maintain the best customer ratings?

select
    customer_segment,
    round(sum(revenue_usd),2) as total_revenue,
    sum(units_sold) as total_units_sold,
    round(avg(customer_rating),2) as average_rating,
    round(100.0 * sum(case when return_flag = 1 then 1 else 0 end) / count(*),2) as return_rate
from apple_sales
group by customer_segment
order by total_revenue desc;

--Q7. Which product categories have generated more than $1 million in revenue?

select
    category,
    round(sum(revenue_usd),2) as total_revenue
from apple_sales
group by category
having sum(revenue_usd) > 1000000
order by total_revenue desc;

--Q8. Which product categories have the highest average selling price?

select
    category,
    round(avg(discounted_price_usd),2) as average_selling_price
from apple_sales
group by category
order by average_selling_price desc;

--Q9. Which customer age group generates the highest revenue?

select
    customer_age_group,
    round(sum(revenue_usd), 2) as total_revenue,
    sum(units_sold) as total_units_sold,
    round(avg(customer_rating), 2) as average_rating
from apple_sales
group by customer_age_group
order by total_revenue desc;

--Q10. Which sales channels are performing above the company's average revenue?

select
    sales_channel,
    round(sum(revenue_usd), 2) as total_revenue
from apple_sales
group by sales_channel
having sum(revenue_usd) >
(
    select avg(channel_revenue)
    from
    (
        select sum(revenue_usd) as channel_revenue
        from apple_sales
        group by sales_channel
    ) as avg_revenue
)
order by total_revenue desc;

--Q11. Which product categories contribute the highest percentage of total revenue?

select
    category,
    round(sum(revenue_usd), 2) as total_revenue,
    round(
        sum(revenue_usd) * 100.0 /
        (select sum(revenue_usd) from apple_sales),
        2
    ) as revenue_percentage
from apple_sales
group by category
order by revenue_percentage desc;

--Q12. Which product category ranks highest in revenue?

select
    category,
    round(sum(revenue_usd), 2) as total_revenue,
    rank() over (
        order by sum(revenue_usd) desc
    ) as revenue_rank
from apple_sales
group by category;

--Q13. What are the top 3 revenue-generating countries?

with country_revenue as(
    select
        country,
        round(sum(revenue_usd), 2) as total_revenue
    from apple_sales
    group by country)

select
    country,
    total_revenue,
    dense_rank() over (order by total_revenue desc) as revenue_rank
from country_revenue
where total_revenue is not null
limit 3;

--Q14. Which sales channel has the highest average order value?

select
    sales_channel,
    round(avg(revenue_usd), 2) as average_order_value
from apple_sales
group by sales_channel
order by average_order_value desc;

--Q15. Which product category has the highest average customer rating?

with category_ratings as(
    select
        category,
        round(avg(customer_rating), 2) as average_rating
    from apple_sales
    group by category)

select
    category,
    average_rating,
    dense_rank() over (
        order by average_rating desc
    ) as rating_rank
from category_ratings;

--Q16. How has monthly revenue changed over time?

with monthly_revenue as(
    select
        year,
        month_number,
        month,
        round(sum(revenue_usd), 2) as total_revenue
    from apple_sales
    group by year, month_number, month)

select
    year,
    month,
    total_revenue,
    lag(total_revenue) over (
        order by year, month_number
    ) as previous_month_revenue,
    round(
        total_revenue -
        lag(total_revenue) over (
            order by year, month_number
        ),
        2
    ) as revenue_change
from monthly_revenue
order by year, month_number;

--Q17. Which countries generate high revenue despite having high return rates?

with country_performance as(
    select
        country,
        round(sum(revenue_usd), 2) as total_revenue,
        round(100.0 * sum(return_flag) / count(*), 2) as return_rate
    from apple_sales
    group by country)

select *
from country_performance
where total_revenue >
(
    select avg(total_revenue)
    from country_performance
)
order by return_rate desc, total_revenue desc;

--Q18. Which product category has the highest return rate while generating above-average revenue?

with category_performance as (
    select
        category,
        round(sum(revenue_usd), 2) as total_revenue,
        round(
            100.0 * sum(return_flag) / count(*),
            2
        ) as return_rate
    from apple_sales
    group by category)

select *
from category_performance
where total_revenue >
(
    select avg(total_revenue)
    from category_performance
)
order by return_rate desc;

--Q19. Which customer segment delivers high revenue with a low return rate?

select
    customer_segment,
    round(sum(revenue_usd), 2) as total_revenue,
    round(
        100.0 * sum(return_flag) / count(*),
        2
    ) as return_rate,
    round(avg(customer_rating), 2) as average_rating
from apple_sales
group by customer_segment
order by total_revenue desc;

--Q20. Which product is the top revenue generator within each category?

with product_revenue as(
    select
        category,
        product_name,
        round(sum(revenue_usd), 2) as total_revenue
    from apple_sales
    group by category, product_name),

ranked_products as(
    select *,
           dense_rank() over
           (
               partition by category
               order by total_revenue desc
           ) as revenue_rank
    from product_revenue)

select
    category,
    product_name,
    total_revenue
from ranked_products
where revenue_rank = 1;

--Q21. Which countries contribute the most revenue for each product category?

with country_category_sales as(
    select
        category,
        country,
        round(sum(revenue_usd),2) as total_revenue
    from apple_sales
    group by category, country),

ranked_sales as(
    select *,
           row_number() over
           (
               partition by category
               order by total_revenue desc
           ) as rn
    from country_category_sales)

select
    category,
    country,
    total_revenue
from ranked_sales
where rn = 1;

--Q22. Which products have above-average customer ratings but below-average revenue?

with product_summary as(
    select
        product_name,
        round(avg(customer_rating),2) as average_rating,
        round(sum(revenue_usd),2) as total_revenue
    from apple_sales
    group by product_name)

select *
from product_summary
where average_rating >
(
    select avg(average_rating)
    from product_summary
)
and total_revenue <
(
    select avg(total_revenue)
    from product_summary
)
order by average_rating desc;

--Q23. Which products generate high revenue but also have a high return rate?

with product_performance as(
    select
        product_name,
        round(sum(revenue_usd), 2) as total_revenue,
        round(100.0 * sum(return_flag) / count(*),2) as return_rate
    from apple_sales
    group by product_name)

select *
from product_performance
where total_revenue >
(
    select avg(total_revenue)
    from product_performance
)
order by return_rate desc;

--Q24. Which price bands contribute the most revenue?

select
    price_band,
    round(sum(revenue_usd), 2) as total_revenue,
    round(sum(revenue_usd) * 100.0 /
        (select sum(revenue_usd) from apple_sales),2) as revenue_share
from apple_sales
group by price_band
order by total_revenue desc;

--Q25. How effective are discounts in driving sales?

select
    discount_bucket,
    count(*) as total_orders,
    sum(units_sold) as total_units_sold,
    round(avg(revenue_usd), 2) as average_revenue
from apple_sales
group by discount_bucket
order by
case
    when discount_bucket = '0%' then 1
    when discount_bucket = '1-10%' then 2
    when discount_bucket = '11-20%' then 3
    when discount_bucket = '21-30%' then 4
end;

--Q26. Which products are consistently top-rated and low-return?

with product_summary as(
    select
        product_name,
        round(avg(customer_rating), 2) as average_rating,
        round(
            100.0 * sum(return_flag) / count(*),
            2
        ) as return_rate,
        round(sum(revenue_usd), 2) as total_revenue
    from apple_sales
    group by product_name)

select *
from product_summary
where average_rating >= 4
and return_rate < 10
order by total_revenue desc;

--Q27. Which are the top 3 revenue-generating products within each category?

with product_revenue as(
    select
        category,
        product_name,
        round(sum(revenue_usd), 2) as total_revenue
    from apple_sales
    group by category, product_name),

ranked_products as(
    select *,
           rank() over
           (
               partition by category
               order by total_revenue desc
           ) as revenue_rank
    from product_revenue)

select
    category,
    product_name,
    total_revenue,
    revenue_rank
from ranked_products
where revenue_rank <= 3
order by category, revenue_rank;