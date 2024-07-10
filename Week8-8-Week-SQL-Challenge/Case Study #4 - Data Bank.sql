-- A. Customer Nodes Exploration
-- 1. How many unique nodes are there on the Data Bank system?
-- Answer:
SELECT
	COUNT(DISTINCT node_id) unique_node_counts
FROM data_bank.customer_nodes;
-- 2. What is the number of nodes per region?
-- Answer:
SELECT
	r.region_id,
    r.region_name,
	COUNT(DISTINCT node_id) unique_node_counts
FROM data_bank.customer_nodes cn
JOIN data_bank.regions r ON cn.region_id = r.region_id
GROUP BY r.region_id, r.region_name;
-- 3. How many customers are allocated to each region?
-- Answer:
SELECT
	r.region_id,
    r.region_name,
	COUNT(customer_id) customer_counts
FROM data_bank.customer_nodes cn
JOIN data_bank.regions r ON cn.region_id = r.region_id
GROUP BY r.region_id, r.region_name
ORDER BY r.region_id;
-- 4. How many days on average are customers reallocated to a different node?
-- Answer:
-- Calculate days in node for each customer
-- Calculate total days in node for each customer
-- Calculate days on average are customers reallocated
WITH node_days AS (
SELECT
	customer_id,
    node_id,
    end_date - start_date days_in_node
FROM data_bank.customer_nodes
WHERE end_date != '9999-12-31'
GROUP BY customer_id, node_id, start_date, end_date
)
, total_node_days AS (
  SELECT
  	customer_id,
  	node_id,
  	SUM(days_in_node) total_days_in_node
  FROM node_days
  GROUP BY customer_id, node_id
  )
  
  SELECT ROUND(AVG(total_days_in_node)) avg_node_reallocation_days
  FROM total_node_days;
-- 5. What is the median, 80th and 95th percentile for this same reallocation days metric for each region?
-- Answer:
-- The percentile is a measure used in statistics to indicate the value below which a given percentage of observations in a group of observations falls.
-- Percentiles are used to understand and interpret data distributions, helping to determine the relative standing of a value within a dataset
-- Key Points About Percentiles
-- 1. Definition: The pth percentile is the value below which p% of the data falls
-- 2. Range: Percentiles range from 0 to 100
-- 3. Interpertaion:
--  The 25th percentile (first quartile, Q1) is the value below which 25% of the data falls.
--  The 50th percentile (second quartile, median) is the value below which 50% of the data falls.
--  The 75th percentile (third quartile, Q3) is the value below which 75% of the data falls.
-- The PERCENTILE_CONT function in PostgreSQL is an ordered set aggregate function used to compute a specific percentile value of 
-- a continuous distribution for a set of data. This function interpolates between the values to determine the percentile, making 
-- it useful for finding values like the median or other percentiles in a dataset.
WITH node_days AS (
  SELECT 
    customer_id, 
    region_id,
    end_date - start_date AS days_in_node
  FROM data_bank.customer_nodes
  WHERE end_date != '9999-12-31'
), total_node_days AS (
  SELECT 
    customer_id,
    region_id,
    SUM(days_in_node) AS total_days_in_node
  FROM node_days
  GROUP BY customer_id, region_id
)
SELECT 
  region_id,
  PERCENTILE_CONT(0.5) WITHIN GROUP (ORDER BY total_days_in_node) AS median_days,
  PERCENTILE_CONT(0.8) WITHIN GROUP (ORDER BY total_days_in_node) AS percentile_80,
  PERCENTILE_CONT(0.95) WITHIN GROUP (ORDER BY total_days_in_node) AS percentile_95
FROM total_node_days
GROUP BY region_id;
-- B. Customer Transactions
-- 1. What is the unique count and total amount for each transaction type?
-- Answer:
SELECT
	txn_type,
    COUNT(txn_type),
    SUM(txn_amount)
FROM data_bank.customer_transactions
GROUP BY txn_type;
-- 2. What is the average total historical deposit counts and amounts for all customers?
-- Answer:
WITH trans_customer AS (
SELECT
	customer_id,
    SUM(CASE
       		WHEN txn_type = 'deposit' THEN txn_amount
       ELSE 0
       END) deposit_amount,
    SUM(CASE
       		WHEN txn_type = 'withdrawal' THEN txn_amount
       ELSE 0
       END) withdrawal_amount,
		SUM(CASE
       		WHEN txn_type = 'withdrawal' THEN txn_amount
       ELSE 0
       END) purchase_amount
FROM data_bank.customer_transactions
GROUP BY customer_id
)

SELECT
	AVG(deposit_amount) avg_total_deposit,
    AVG(deposit_amount) - AVG(withdrawal_amount) - AVG(purchase_amount) avg_total_amount
FROM trans_customer;
-- 3. For each month - how many Data bank customers make more than 1 deposit and either 1 purchase or 1 withdrawal in a single month?
-- Answer:
-- Step 1: For each month, customers make ? deposit transactions, ? withdrawal transactions and ? purchase transactions
WITH trans_monthly AS (
SELECT
	DATE_PART('month', txn_date) month_date,
    customer_id,
   	SUM(CASE
       	WHEN txn_type = 'deposit' THEN 1 			ELSE 0
       END) deposit_count,
       SUM(CASE
       	WHEN txn_type = 'withdrawal' THEN 1 			ELSE 0
       END) withdrawal_count,
       SUM(CASE
       	WHEN txn_type = 'purchase' THEN 1 			ELSE 0
       END) purchase_count
FROM data_bank.customer_transactions
GROUP BY month_date, customer_id
ORDER BY month_date, customer_id
)
SELECT
	month_date,
    SUM(CASE
       WHEN deposit_count > 1 AND purchase_count > 1 THEN 1
       ELSE 0
       END) purchase_cus
       ,
       SUM(CASE
          WHEN withdrawal_count > 1 THEN 1
          ELSE 0
          END) withdrawal_cus
FROM trans_monthly
GROUP BY month_date;
-- 4. What is the closing balance for each customer at the the end of the month? Also show the change in balance each month in the same table output?
-- Answer:
-- 5. Comparing the closing balances of a customer's first month and the closing balance from their second nth, what percentage of customers:
-- - What percentage of customers have a negative first month balance? What percentage of customers have a positive first month balance?
-- - What percentage of customers increase their opening month's positive closing balance by more than 5% in the following month?
-- - What percentage of customers reduce their opening month’s positive closing balance by more than 5% in the following month?
-- - What percentage of customers move from a positive balance in the first month to a negative balance in the second month?
-- Answer:
