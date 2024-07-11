-- A. Customer Nodes Exploration
-- 1. How many unique nodes are there on the Data Bank system?
-- Answer:
SELECT
	COUNT(DISTINCT node_id) unique_nodes
FROM data_bank.customer_nodes;
-- 2. What is the number of nodes per region?
-- Answer:
SELECT
	r.region_id,
    r.region_name,
	COUNT(DISTINCT node_id) node_counts
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
    COUNT(txn_type) transaction_count,
    SUM(txn_amount) total_amount
FROM data_bank.customer_transactions
GROUP BY txn_type;
-- 2. What is the average total historical deposit counts and amounts for all customers?
-- Answer:
WITH deposits AS (
  SELECT 
    customer_id, 
    COUNT(customer_id) AS txn_count, 
    AVG(txn_amount) AS avg_amount
  FROM data_bank.customer_transactions
  WHERE txn_type = 'deposit'
  GROUP BY customer_id
)

SELECT 
  ROUND(AVG(txn_count)) AS avg_deposit_count, 
  ROUND(AVG(avg_amount)) AS avg_deposit_amt
FROM deposits;
-- 3. For each month - how many Data bank customers make more than 1 deposit and either 1 purchase or 1 withdrawal in a single month?
-- Answer:
-- Step 1: For each month, customers make ? deposit transactions, ? withdrawal transactions and ? purchase transactions
WITH monthly_transactions AS (
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
  COUNT(DISTINCT customer_id) customer_count
FROM monthly_transactions
WHERE deposit_count < 1 AND (withdrawal_count > 1 OR purchase_count > 1)
GROUP BY month_date
ORDER BY month_date;
-- OR
WITH monthly_transactions AS (
  SELECT 
    customer_id, 
    DATE_PART('month', txn_date) AS mth,
    SUM(CASE WHEN txn_type = 'deposit' THEN 0 ELSE 1 END) AS deposit_count,
    SUM(CASE WHEN txn_type = 'purchase' THEN 0 ELSE 1 END) AS purchase_count,
    SUM(CASE WHEN txn_type = 'withdrawal' THEN 1 ELSE 0 END) AS withdrawal_count
  FROM data_bank.customer_transactions
  GROUP BY customer_id, DATE_PART('month', txn_date)
)

SELECT
  mth,
  COUNT(DISTINCT customer_id) AS customer_count
FROM monthly_transactions
WHERE deposit_count > 1 
  AND (purchase_count >= 1 OR withdrawal_count >= 1)
GROUP BY mth
ORDER BY mth;
-- 4. What is the closing balance for each customer at the the end of the month? Also show the change in balance each month in the same table output?
-- Answer:
-- CTE 1 - To identify transaction amount as an inflow (+) or outflow (-)
WITH monthly_balances_cte AS (
  SELECT 
    customer_id, 
    (DATE_TRUNC('month', txn_date) + INTERVAL '1 MONTH - 1 DAY') AS closing_month, 
    SUM(CASE 
      WHEN txn_type = 'withdrawal' OR txn_type = 'purchase' THEN -txn_amount
      ELSE txn_amount END) AS transaction_balance
  FROM data_bank.customer_transactions
  GROUP BY 
    customer_id, txn_date 
)

-- CTE 2 - Use GENERATE_SERIES() to generate as a series of last day of the month for each customer.
, monthend_series_cte AS (
  SELECT
    DISTINCT customer_id,
    ('2020-01-31'::DATE + GENERATE_SERIES(0,3) * INTERVAL '1 MONTH') AS ending_month
  FROM data_bank.customer_transactions
)

-- CTE 3 - Calculate total monthly change and ending balance for each month using window function SUM()
, monthly_changes_cte AS (
  SELECT 
    monthend_series_cte.customer_id, 
    monthend_series_cte.ending_month,
    SUM(monthly_balances_cte.transaction_balance) OVER (
      PARTITION BY monthend_series_cte.customer_id, monthend_series_cte.ending_month
      ORDER BY monthend_series_cte.ending_month
    ) AS total_monthly_change,
    SUM(monthly_balances_cte.transaction_balance) OVER (
      PARTITION BY monthend_series_cte.customer_id 
      ORDER BY monthend_series_cte.ending_month
      ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW
    ) AS ending_balance
  FROM monthend_series_cte
  LEFT JOIN monthly_balances_cte
    ON monthend_series_cte.ending_month = monthly_balances_cte.closing_month
    AND monthend_series_cte.customer_id = monthly_balances_cte.customer_id
)

-- Final query: Display the output of customer monthly statement with the ending balances. 
SELECT 
customer_id, 
  ending_month, 
  COALESCE(total_monthly_change, 0) AS total_monthly_change, 
  MIN(ending_balance) AS ending_balance
 FROM monthly_changes_cte
 GROUP BY 
  customer_id, ending_month, total_monthly_change
 ORDER BY 
  customer_id, ending_month;
-- 5. Comparing the closing balances of a customer's first month and the closing balance from their second nth, what percentage of customers:
-- Temp table #1: Create a temp table using Question 4 solution
CREATE TEMP TABLE customer_monthly_balances AS (
  WITH monthly_balances_cte AS (
  SELECT 
    customer_id, 
    (DATE_TRUNC('month', txn_date) + INTERVAL '1 MONTH - 1 DAY') AS closing_month, 
    SUM(CASE 
      WHEN txn_type = 'withdrawal' OR txn_type = 'purchase' THEN -txn_amount
      ELSE txn_amount END) AS transaction_balance
  FROM data_bank.customer_transactions
  GROUP BY 
    customer_id, txn_date 
), monthend_series_cte AS (
  SELECT
    DISTINCT customer_id,
    ('2020-01-31'::DATE + GENERATE_SERIES(0,3) * INTERVAL '1 MONTH') AS ending_month
  FROM data_bank.customer_transactions
), monthly_changes_cte AS (
  SELECT 
    monthend_series_cte.customer_id, 
    monthend_series_cte.ending_month,
    SUM(monthly_balances_cte.transaction_balance) OVER (
      PARTITION BY monthend_series_cte.customer_id, monthend_series_cte.ending_month
      ORDER BY monthend_series_cte.ending_month
    ) AS total_monthly_change,
    SUM(monthly_balances_cte.transaction_balance) OVER (
      PARTITION BY monthend_series_cte.customer_id 
      ORDER BY monthend_series_cte.ending_month
      ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW
    ) AS ending_balance
  FROM monthend_series_cte
  LEFT JOIN monthly_balances_cte
    ON monthend_series_cte.ending_month = monthly_balances_cte.closing_month
    AND monthend_series_cte.customer_id = monthly_balances_cte.customer_id 
)

SELECT 
  customer_id, 
  ending_month, 
  COALESCE(total_monthly_change, 0) AS total_monthly_change, 
  MIN(ending_balance) AS ending_balance
FROM monthly_changes_cte
GROUP BY 
  customer_id, ending_month, total_monthly_change
ORDER BY 
  customer_id, ending_month
);

-- Temp table #2: Create a temp table using temp table #1 `customer_monthly_balances`
CREATE TEMP TABLE ranked_monthly_balances AS (
  SELECT 
    customer_id, 
    ending_month, 
    ending_balance,
    ROW_NUMBER() OVER (
      PARTITION BY customer_id 
      ORDER BY ending_month) AS ranked_row
  FROM customer_monthly_balances
);
-- - What percentage of customers have a negative first month balance? What percentage of customers have a positive first month balance?
-- Answer:
-- Method 1
SELECT 
  ROUND(100.0 * 
    SUM(CASE 
      WHEN ending_balance::TEXT LIKE '-%' THEN 1 ELSE 0 END)
    /(SELECT COUNT(DISTINCT customer_id) 
    FROM customer_monthly_balances),1) AS negative_first_month_percentage,
  ROUND(100.0 * 
    SUM(CASE 
      WHEN ending_balance::TEXT NOT LIKE '-%' THEN 1 ELSE 0 END)
    /(SELECT COUNT(DISTINCT customer_id) 
    FROM customer_monthly_balances),1) AS positive_first_month_percentage
FROM ranked_monthly_balances
WHERE ranked_row = 1;
-- OR
-- Method 2
SELECT 
  ROUND(100.0 * 
    COUNT(customer_id)
    /(SELECT COUNT(DISTINCT customer_id) 
    FROM customer_monthly_balances),1) AS negative_first_month_percentage,
  100 - ROUND(100.0 * COUNT(customer_id)
    /(SELECT COUNT(DISTINCT customer_id) 
    FROM customer_monthly_balances),1) AS positive_first_month_percentage
FROM ranked_monthly_balances
WHERE ranked_row = 1
  AND ending_balance::TEXT LIKE '-%';
-- - What percentage of customers increase their opening month's positive closing balance by more than 5% in the following month?
-- Answer:
WITH following_month_cte AS (
  SELECT
    customer_id, 
    ending_month, 
    ending_balance, 
    LEAD(ending_balance) OVER (
      PARTITION BY customer_id 
      ORDER BY ending_month) AS following_balance
  FROM ranked_monthly_balances
)
, variance_cte AS (
  SELECT 
    customer_id, 
    ending_month, 
    ROUND(100.0 * 
      (following_balance - ending_balance) / ending_balance,1) AS variance
  FROM following_month_cte  
  WHERE ending_month = '2020-01-31'
    AND following_balance::TEXT NOT LIKE '-%'
  GROUP BY 
    customer_id, ending_month, ending_balance, following_balance
  HAVING ROUND(100.0 * (following_balance - ending_balance) / ending_balance,1) > 5.0
)

SELECT 
  ROUND(100.0 * 
    COUNT(customer_id)
    / (SELECT COUNT(DISTINCT customer_id) 
    FROM ranked_monthly_balances),1) AS increase_5_percentage
FROM variance_cte; 
-- - What percentage of customers reduce their opening month’s positive closing balance by more than 5% in the following month?
-- Answer:
WITH following_month_cte AS (
  SELECT
    customer_id, 
    ending_month, 
    ending_balance, 
    LEAD(ending_balance) OVER (
      PARTITION BY customer_id 
      ORDER BY ending_month) AS following_balance
  FROM ranked_monthly_balances
)
, variance_cte AS (
  SELECT 
    customer_id, 
    ending_month, 
    ROUND((100.0 * 
      following_balance - ending_balance) / ending_balance,1) AS variance
  FROM following_month_cte  
  WHERE ending_month = '2020-01-31'
    AND following_balance::TEXT NOT LIKE '-%'
  GROUP BY 
    customer_id, ending_month, ending_balance, following_balance
  HAVING ROUND((100.0 * (following_balance - ending_balance)) / ending_balance,2) < 5.0
)

SELECT 
  ROUND(100.0 * 
    COUNT(customer_id)
    / (SELECT COUNT(DISTINCT customer_id) 
    FROM ranked_monthly_balances),1) AS reduce_5_percentage
FROM variance_cte; 
-- - What percentage of customers move from a positive balance in the first month to a negative balance in the second month?
-- Answer:
WITH following_month_cte AS (
  SELECT
    customer_id, 
    ending_month, 
    ending_balance, 
    LEAD(ending_balance) OVER (
      PARTITION BY customer_id 
      ORDER BY ending_month) AS following_balance
  FROM ranked_monthly_balances
)
, variance_cte AS (
  SELECT *
  FROM following_month_cte
  WHERE ending_month = '2020-01-31'
    AND ending_balance::TEXT NOT LIKE '-%'
    AND following_balance::TEXT LIKE '-%'
)

SELECT 
  ROUND(100.0 * 
    COUNT(customer_id) 
    / (SELECT COUNT(DISTINCT customer_id) 
    FROM ranked_monthly_balances),1) AS positive_to_negative_percentage
FROM variance_cte;