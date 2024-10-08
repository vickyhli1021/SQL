-- A.Customer Journey
SELECT s.customer_id, s.plan_id, p.plan_name, s.start_date
FROM foodie_fi.subscriptions s
LEFT JOIN foodie_fi.plans p ON s.plan_id=p.plan_id
WHERE s.customer_id IN (1,2,11,13,15,16,18,19)
ORDER BY s.customer_id, s.start_date;

--B. Data Analysis questions
--1. How many customers has Foodie-Fi ever had?
SELECT COUNT(DISTINCT customer_id) AS unique_customer
FROM foodie_fi.subscriptions;

--2. What is the monthly distribution of trial plan start_date (use start of the month as the group by value)?
SELECT EXTRACT(MONTH FROM start_date) AS start_month, 
  UPPER(TO_CHAR(start_date, 'month')) AS month_name, COUNT(customer_id)
FROM foodie_fi.subscriptions
WHERE plan_id = 0
GROUP BY start_month, month_name;
-- extract() function only returns the extract value, date_trunc()function still keeps other values

--3. What plan start_date occurs after 2020, breakdown by count of events for each plan_name
SELECT s.plan_id, p.plan_name, COUNT(s.customer_id) AS count_of_events
FROM foodie_fi.subscriptions s
LEFT JOIN foodie_fi.plans p ON s.plan_id=p.plan_id
WHERE EXTRACT(YEAR FROM s.start_date) > 2020
GROUP BY s.plan_id, p.plan_name
ORDER BY count_of_events;

--4. What is the customer count and percentage of customers who have churned rounded to 1 decimal place
SELECT SUM(CASE WHEN p.plan_name = 'churn' THEN 1 END) AS customer_churn,
  COUNT(DISTINCT s.customer_id) AS total_customers,
  ROUND(
    (SUM(CASE WHEN p.plan_name = 'churn' THEN 1 END) :: NUMERIC/COUNT(DISTINCT s.customer_id))*100, 1) AS churn_rate
FROM foodie_fi.subscriptions s
LEFT JOIN foodie_fi.plans p ON s.plan_id=p.plan_id;


--5. How many customers have churned straight after their initial free trial - what percentage is this rounded to the nearest whole number
WITH ranking AS(
SELECT *, RANK()OVER(PARTITION BY customer_id ORDER BY start_date ASC) AS row_num
FROM foodie_fi.subscriptions)

SELECT SUM(CASE WHEN row_num=2 AND plan_name = 'churn' THEN 1 END) AS churn_customer, COUNT(DISTINCT customer_id) AS total_customer, ROUND(
  (SUM(CASE WHEN row_num=2 AND plan_name = 'churn' THEN 1 END)::NUMERIC / COUNT(DISTINCT customer_id))*100,0) AS churn_rate
FROM ranking r
LEFT JOIN foodie_fi.plans p ON r.plan_id=p.plan_id;


--6.What is the number and percentage of customer plans after their initial free trial
WITH ranking AS(
SELECT *, RANK()OVER(PARTITION BY customer_id ORDER BY start_date ASC) AS row_num
FROM foodie_fi.subscriptions)

SELECT r.plan_id, p.plan_name, COUNT(r.plan_id) AS convert_customer,
  ROUND((COUNT(r.plan_id)::NUMERIC/(SELECT COUNT(DISTINCT customer_id) FROM foodie_fi.subscriptions))*100,1) AS conversion_rate
FROM ranking r
LEFT JOIN foodie_fi.plans p ON r.plan_id=p.plan_id
WHERE row_num=2
GROUP BY r.plan_id, p.plan_name;



--7. What is the customer count and percentage breakdown of all 5 plan_name values at 2020-12-31?
WITH date AS (
  SELECT *, 
  RANK() OVER(PARTITION BY customer_id ORDER BY start_date DESC) AS date_rank
  FROM foodie_fi.subscriptions
  WHERE start_date <= '2020-12-31')

SELECT p.plan_name, COUNT(d.customer_id) AS customer_num, 
ROUND((COUNT(d.customer_id):: NUMERIC/ (SELECT COUNT(customer_id) FROM date WHERE date_rank=1))*100,1) AS percentage
FROM date d
LEFT JOIN foodie_fi.plans p ON d.plan_id=p.plan_id
WHERE date_rank = 1
GROUP BY p.plan_name
ORDER BY customer_num DESC;

-- create CTE to rank customer by the start_date in descending order, and only take the latest subscription of each customer


--8. How many customers have upgraded to an annual plan in 2020?
SELECT COUNT(*)
FROM foodie_fi.subscriptions
WHERE plan_id = 3
AND start_date >= '2020-01-01' AND start_date <= '2020-12-31';


--9. How many days on average does it take for a customer to an annual plan from the day they join Foodie-Fi?
SELECT ROUND(AVG(s2.start_date-s1.start_date),1) AS avg_day
FROM foodie_fi.subscriptions s1
LEFT JOIN foodie_fi.subscriptions s2 ON s1.customer_id=s2.customer_id
AND s1.plan_id +3 = s2.plan_id
WHERE s2.plan_id = 3;

-- self-join to mapping each customer from day one to the annual plan


--10. Can you further breakdown this average value into 30 day periods (i.e. 0-30 days, 31-60 days etc)
WITH bucket AS(
SELECT s2.start_date-s1.start_date AS duration, 
WIDTH_BUCKET(s2.start_date-s1.start_date, 1, 360, 12) AS bucket -- width_bucket(expression, min, max, buckets) function to create buckets 
FROM foodie_fi.subscriptions s1
LEFT JOIN foodie_fi.subscriptions s2 ON s1.customer_id=s2.customer_id
AND s1.plan_id +3 = s2.plan_id
WHERE s2.plan_id = 3)

SELECT CONCAT((bucket-1)*30+1, '-', bucket*30, 'days') AS day_range,
 COUNT(bucket) AS customer_count
FROM bucket
GROUP BY bucket;


--11. How many customers downgraded from a pro monthly to a basic monthly plan in 2020? 
WITH downgrade AS (
SELECT *, 
LEAD(plan_id) OVER(PARTITION BY customer_id ORDER BY start_date) AS downgrade  -- lead() function access the subsequent record
FROM foodie_fi.subscriptions)

SELECT COUNT(*)
FROM downgrade
WHERE plan_id= 2 and downgrade =1
AND start_date >= '2020-01-01' AND start_date <= '2020-12-31';



-- C. Payment
CREATE TABLE payments_2020 AS
WITH RECURSIVE join_table AS(
SELECT s.customer_id, s.plan_id, p.plan_name, s.start_date,
  LEAD(s.start_date, 1) OVER (PARTITION BY s.customer_id ORDER BY s.start_date, s.plan_id) AS next_payment_date, p.price AS payment
FROM foodie_fi.subscriptions s
LEFT JOIN foodie_fi.plans p ON s.plan_id=p.plan_id
WHERE p.plan_name NOT IN ('trial', 'churn')
AND s.start_date >= '2020-01-01' AND s.start_date <= '2020-12-31'),
join_table1 AS(
SELECT customer_id, plan_id, plan_name, start_date,
  COALESCE(next_payment_date, '2020-12-31') AS next_date, payment
FROM join_table),
join_table2 AS(
SELECT customer_id, plan_id, plan_name, start_date, next_date, payment
FROM join_table1
  
UNION ALL
  
SELECT customer_id, plan_id, plan_name, 
DATE((start_date + INTERVAL '1 MONTH')) AS starr_date, next_date, payment
FROM join_table2
WHERE next_date > DATE((start_date + INTERVAL '1 MONTH')) --termination check
AND plan_name != 'pro annual'),
join_table3 AS(
  SELECT *, LAG(plan_id, 1) OVER (PARTITION BY customer_id ORDER BY start_date) AS last_plan, 
  LAG(payment,1) OVER (PARTITION BY customer_id ORDER BY start_date) AS last_payment, -- LAG() access the preceding record
  RANK() OVER (PARTITION BY customer_id ORDER BY start_date) AS payment_order
  FROM join_table2
  ORDER BY customer_id, start_date)
  
SELECT customer_id, plan_id, plan_name, start_date, 
  (CASE WHEN plan_id IN (2,3) AND last_plan=1 THEN payment-last_payment
  ELSE payment END) AS amount, payment_order
FROM join_table3;

SELECT *
FROM payments_2020;


-- RECURSIVE query calls itself repeatedly until it reaches a termination condition; allow for hierarchical or self-referencing 
-- the anchor part establishes the base case, the recursive part iteratively builds upon the anchor part; both should have the same number of columns

-- WITH RECURSIVE cte AS (
--   Base(anchor) query
--  ...
-- UNION ALL
--   Recursive query
--  ...
)
-- SELECT ...
-- FROM cte;


-- D. Outside the box
--1. How would you calculate the rate of growth for Foodie-Fi?
-- For annual customer growth rate






-- For monthly customer growth rate


--2. What key metrics would you recommend Foodie-Fi management to track over time to assess performance of their overall business?

--3. What are some key customer journeys or experiences that you would analyse further to improve customer retention?

--4. If the Foodie-Fi team were to create an exit survey shown to customers who wish to cancel their subscription, what questions would you include in the survey?

--5. What business levers could the Foodie-Fi team use to reduce the customer churn rate? How would you validate the effectiveness of your ideas?





