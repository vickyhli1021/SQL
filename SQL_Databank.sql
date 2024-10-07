-- A. Customer nodes exploration
--1. How many unique nodes are there on the Data Bank system?
SELECT COUNT(DISTINCT node_id)
FROM data_bank.customer_nodes;


--2. What is the number of nodes per region?
SELECT r.region_name, COUNT(n.node_id) AS node_num
FROM data_bank.regions r
JOIN data_bank.customer_nodes n ON r.region_id=n.region_id
GROUP BY r.region_name
ORDER BY node_num DESC;


--3. How many customers are allocated to each region?
SELECT r.region_name, COUNT(DISTINCT n.customer_id) AS customer_num
FROM data_bank.regions r
JOIN data_bank.customer_nodes n ON r.region_id=n.region_id
GROUP BY r.region_name
ORDER BY customer_num DESC;


--4. How many days on average are customers reallocated to a different node?
SELECT ROUND(AVG(end_date-start_date),1) AS avg_days
FROM data_bank.customer_nodes
WHERE end_date != '9999-12-31';


--5. What is the median, 80th and 95th percentile for this same reallocation days metric for each region?
WITH reallocation AS (
SELECT r.region_id, r.region_name, (n.end_date-n.start_date) AS duration
FROM data_bank.customer_nodes n
JOIN data_bank.regions r ON r.region_id = n.region_id
WHERE end_date != '9999-12-31')

SELECT 
     region_name,
     PERCENTILE_CONT(0.5) WITHIN GROUP(ORDER BY duration) AS median,
     PERCENTILE_CONT(0.80) WITHIN GROUP(ORDER BY duration) AS percentile_80,
     PERCENTILE_CONT(0.95) WITHIN GROUP(ORDER BY duration) AS percentile_95
FROM reallocation r
GROUP BY region_name;


--B. Customer Transactions
--1. What is the unique count and total amount for each transaction type?
SELECT txn_type, COUNT(*), SUM(txn_amount) AS total_amount
FROM data_bank.customer_transactions
GROUP BY txn_type;


--2.What is the average total historical deposit counts and amounts for all customers?
WITH deposit_summary AS(
SELECT customer_id, txn_type,
  SUM(CASE WHEN txn_type = 'deposit' THEN 1 ELSE 0 END) AS deposit_count, 
  SUM(CASE WHEN txn_type = 'deposit' THEN txn_amount ELSE 0 END) AS deposit_amount
FROM data_bank.customer_transactions 
GROUP BY customer_id, txn_type)

SELECT txn_type, AVG(deposit_count), AVG(deposit_amount)
FROM deposit_summary
WHERE txn_type='deposit'
GROUP BY txn_type;


--3.For each month - how many Data Bank customers make more than 1 deposit and either 1 purchase or 1 withdrawal in a single month?
WITH summary AS(
SELECT TO_CHAR(txn_date, 'month') AS month, customer_id, 
  SUM(CASE WHEN txn_type='deposit' THEN 1 ELSE 0 END) AS deposit_count,
  SUM(CASE WHEN txn_type='purchase' THEN 1 ELSE 0 END) AS purchase_count,
  SUM(CASE WHEN txn_type='withdrawal' THEN 1 ELSE 0 END) AS withdrawal_count
FROM data_bank.customer_transactions 
GROUP BY customer_id, month)

SELECT month, COUNT(DISTINCT customer_id) AS customer_count
FROM summary
WHERE deposit_count >1 
AND (purchase_count =1 OR withdrawal_count =1)
GROUP BY month
ORDER BY customer_count DESC;


--4. What is the closing balance for each customer at the end of the month?
WITH summary AS(
SELECT customer_id, TO_CHAR(txn_date, 'month') AS month,
  SUM(CASE WHEN txn_type='deposit' THEN txn_amount ELSE 0 END) AS deposit,
  SUM(CASE WHEN txn_type='purchase' THEN -txn_amount ELSE 0 END) AS purchase,
  SUM(CASE WHEN txn_type='withdrawal' THEN -txn_amount ELSE 0 END) AS withdrawal
FROM data_bank.customer_transactions 
GROUP BY customer_id, month),
summary_total AS (
  SELECT customer_id, month, (deposit+purchase+withdrawal) AS total
  FROM summary)

SELECT customer_id, month, 
  SUM(total) OVER (PARTITION BY customer_id ORDER BY customer_id, month) AS closing_balance 
FROM summary_total;


--5. What is the percentage of customers who increase their closing balance by more than 5%?










