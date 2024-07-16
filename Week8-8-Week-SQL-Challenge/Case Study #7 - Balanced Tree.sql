-- Business Task
 -- Balanced Tree Clothing Company prides itself on providing an optimized range of clothing and lifestyle wear for the modern adventurer!
-- Danny, the CEO of this trendy fashion company has asked you to assist the team’s merchandising teams in analysing their
-- sales performance and generate a basic financial report to share with the wider business.
-- Revenue = price * qty and discounr = price * qty * discount / 100
-- A. High-Level Sales Analysis
-- 1. What was the total quantity sold for all products?
-- Answer:

SELECT pd.product_name,
       SUM(s.qty) total_quantity
FROM balanced_tree.product_details pd
JOIN balanced_tree.sales s ON pd.product_id = s.prod_id
GROUP BY pd.product_name;

-- 2. What is the total generated revenue for all products before discounts?
-- Answer:

SELECT pd.product_name,
       SUM(s.price) * SUM(s.qty) revenues
FROM balanced_tree.product_details pd
JOIN balanced_tree.sales s ON pd.product_id = s.prod_id
GROUP BY pd.product_name;

-- 3. What was the total discount amount for all products?
-- Answer:

SELECT pd.product_name,
       SUM(s.qty * s.price * s.discount/100) total_discount
FROM balanced_tree.product_details pd
JOIN balanced_tree.sales s ON pd.product_id = s.prod_id
GROUP BY pd.product_name;

-- B. Transaction Analysis
-- 1. How many unique transactions were there?
-- Answer:

SELECT COUNT(DISTINCT txn_id) unique_transactions
FROM balanced_tree.sales;

-- 2. What is the average unique products purchased in each transaction?
-- Answer:

SELECT ROUND(AVG(total_quantity)) AS avg_unique_products
FROM
  (SELECT txn_id,
          SUM(qty) AS total_quantity
   FROM balanced_tree.sales
   GROUP BY txn_id) AS total_quantities;

-- 3. What are the 25th, 50th, and 75 percentile values for the revenue per transaction?
-- Answer:
WITH revenue_cte AS
  (SELECT txn_id,
          SUM(price * qty) AS revenue
   FROM balanced_tree.sales
   GROUP BY txn_id)
SELECT PERCENTILE_CONT(0.25) WITHIN GROUP (
                                           ORDER BY revenue) AS median_25th,
                                          PERCENTILE_CONT(0.5) WITHIN GROUP (
                                                                             ORDER BY revenue) AS median_50th,
                                                                            PERCENTILE_CONT(0.75) WITHIN GROUP (
                                                                                                                ORDER BY revenue) AS median_75th
FROM revenue_cte;

-- 4. What is the average discount value per transaction?
-- Answer:

SELECT SUM(discount) /
  (SELECT COUNT(DISTINCT txn_id)
   FROM balanced_tree.sales) avg_discount_per_transaction
FROM balanced_tree.sales;

-- 5. What is the percentage split of all transactions for members vs non-members?
-- Answer:
WITH transactions_cte AS
  (SELECT member,
          COUNT(DISTINCT txn_id) AS transactions
   FROM balanced_tree.sales
   GROUP BY member)
SELECT member,
       transactions,
       ROUND(100 * transactions /
               (SELECT SUM(transactions)
                FROM transactions_cte)) AS percentage
FROM transactions_cte
GROUP BY member,
         transactions;

-- 6. What is the average revenue for member transactions and non-member transactions?
-- Answer:
WITH revenue_cte AS
  (SELECT member,
          txn_id,
          SUM(price * qty) AS revenue
   FROM balanced_tree.sales
   GROUP BY member,
            txn_id)
SELECT member,
       ROUND(AVG(revenue), 2) AS avg_revenue
FROM revenue_cte
GROUP BY member;

-- C. Product Analysis
-- 1. What are the top 3 products by total revenue before discount?
-- Answer:

SELECT pd.product_name,
       SUM(s.price) * SUM(s.qty) total_revenue
FROM balanced_tree.product_details pd
JOIN balanced_tree.sales s ON pd.product_id = s.prod_id
GROUP BY pd.product_name
ORDER BY total_revenue DESC
LIMIT 3;

-- 2. What is the total quantity, revenue, and discount for each segment?
-- Answer:

SELECT pd.segment_name,
       SUM(s.qty) total_quantity,
       SUM(s.price) * SUM(s.qty) - SUM(s.discount) total_revenue,
       SUM((s.qty * s.price) * s.discount/100) AS total_discount
FROM balanced_tree.product_details pd
JOIN balanced_tree.sales s ON pd.product_id = s.prod_id
GROUP BY pd.segment_name;

-- 3. What is the top-selling product for each segment?
-- Answer:
WITH ranked_product AS
  (SELECT pd.segment_name,
          pd.product_name,
          DENSE_RANK() OVER (PARTITION BY pd.segment_name
                             ORDER BY SUM(s.qty) DESC) ranked
   FROM balanced_tree.product_details pd
   JOIN balanced_tree.sales s ON pd.product_id = s.prod_id
   GROUP BY pd.segment_name,
            pd.product_name)
SELECT segment_name,
       product_name
FROM ranked_product
WHERE ranked = 1
ORDER BY segment_name;

-- OR
 WITH top_selling_cte AS
  (SELECT product.segment_id,
          product.segment_name,
          product.product_id,
          product.product_name,
          SUM(sales.qty) AS total_quantity,
          RANK() OVER (PARTITION BY segment_id
                       ORDER BY SUM(sales.qty) DESC) AS ranking
   FROM balanced_tree.sales
   INNER JOIN balanced_tree.product_details AS product ON sales.prod_id = product.product_id
   GROUP BY product.segment_id,
            product.segment_name,
            product.product_id,
            product.product_name)
SELECT segment_id,
       segment_name,
       product_id,
       product_name,
       total_quantity
FROM top_selling_cte
WHERE ranking = 1;

-- 4. What is the total quantity, revenue, and discount for each category?
-- Answer:

SELECT pd.category_name,
       SUM(s.qty) total_quantity,
       SUM(s.price) * SUM(s.qty) - SUM(s.discount) total_revenue,
       SUM((s.qty * s.price) * s.discount/100) total_discount
FROM balanced_tree.product_details pd
JOIN balanced_tree.sales s ON pd.product_id = s.prod_id
GROUP BY pd.category_name;

-- 5. What is the top-selling product for each category?
-- Answer:
WITH ranked_product AS
  (SELECT pd.category_name,
          pd.product_name,
          DENSE_RANK() OVER(PARTITION BY pd.category_name
                            ORDER BY SUM(s.qty) DESC) ranked
   FROM balanced_tree.product_details pd
   JOIN balanced_tree.sales s ON pd.product_id = s.prod_id
   GROUP BY pd.category_name,
            pd.product_name)
SELECT category_name,
       product_name
FROM ranked_product
WHERE ranked = 1;

--OR
 WITH top_selling_cte AS
  (SELECT product.category_id,
          product.category_name,
          product.product_id,
          product.product_name,
          SUM(sales.qty) AS total_quantity,
          RANK() OVER (PARTITION BY product.category_id
                       ORDER BY SUM(sales.qty) DESC) AS ranking
   FROM balanced_tree.sales
   INNER JOIN balanced_tree.product_details AS product ON sales.prod_id = product.product_id
   GROUP BY product.category_id,
            product.category_name,
            product.product_id,
            product.product_name)
SELECT category_id,
       category_name,
       product_id,
       product_name,
       total_quantity
FROM top_selling_cte
WHERE ranking = 1;

-- 6. What is the percentage split of revenue by product for each segment?
-- Answer:
WITH product_revenue AS
  (SELECT pd.segment_id,
          pd.segment_name,
          pd.product_name,
          SUM(s.price) * SUM(s.qty) revenue
   FROM balanced_tree.product_details pd
   JOIN balanced_tree.sales s ON pd.product_id = s.prod_id
   GROUP BY pd.segment_id,
            pd.segment_name,
            pd.product_name),
     segment_revenue AS
  (SELECT segment_id,
          SUM(revenue) revenue
   FROM product_revenue
   GROUP BY segment_id,
            segment_name)
SELECT sr.segment_name,
       pr.product_name,
       ROUND(100 * pr.revenue / sr.revenue, 2) revenue_percentage
FROM segment_revenue sr
JOIN product_revenue pr ON sr.segment_id = pr.segment_id;

-- 7. What is the percentage split of revenue by segment for each category?
-- Answer:
WITH segment_revenue AS
  (SELECT pd.category_id,
          pd.category_name,
          pd.segment_name,
          SUM(s.price) * SUM(s.qty) revenue
   FROM balanced_tree.product_details pd
   JOIN balanced_tree.sales s ON pd.product_id = s.prod_id
   GROUP BY pd.category_id,
            pd.category_name,
            pd.segment_name),
     category_revenue AS
  (SELECT category_id,
          SUM(revenue) revenue
   FROM segment_revenue
   GROUP BY category_id)
SELECT sr.category_name,
       sr.segment_name,
       ROUND(100 * sr.revenue / cr.revenue, 2) revenue_percentage
FROM category_revenue cr
JOIN segment_revenue sr ON cr.category_id = sr.category_id;

-- 8. What is the percentage split of total revenue by category?
-- Answer:
WITH category_revenue AS
  (SELECT pd.category_name,
          SUM(s.price) * SUM(s.qty) total_revenue
   FROM balanced_tree.product_details pd
   JOIN balanced_tree.sales s ON pd.product_id = s.prod_id
   GROUP BY pd.category_name)
SELECT category_name,
       ROUND(100 * total_revenue /
               (SELECT SUM(total_revenue)
                FROM category_revenue), 2) revenue_percentage
FROM category_revenue;

-- 9. What is the total transaction "penetration" for each product? (hint: penetration = number of transactions where
-- at least 1 quantity of a product was purchased divided by the total number of transactions)
-- Answer:
WITH product_transactions AS
  (SELECT pd.product_id,
          pd.product_name,
          COUNT(DISTINCT s.txn_id) product_transaction_count
   FROM balanced_tree.product_details pd
   JOIN balanced_tree.sales s ON pd.product_id = s.prod_id
   WHERE s.qty > 0
   GROUP BY pd.product_id,
            pd.product_name)
SELECT product_id,
       product_name,
       ROUND(product_transaction_count::DECIMAL /
               (SELECT COUNT(DISTINCT txn_id)
                FROM balanced_tree.sales), 2) penetration
FROM product_transactions;

-- 10. What is the most common combination of at least 1 quantity of any 3 products in a 1 single transaction?
-- Answer:
WITH filtered_transactions AS
  (SELECT pd.product_id,
          pd.product_name,
          s.txn_id
   FROM balanced_tree.product_details pd
   JOIN balanced_tree.sales s ON pd.product_id = s.prod_id
   WHERE s.qty > 0 ),
     grouped_products AS
  (SELECT txn_id,
          ARRAY_AGG(product_id
                    ORDER BY product_id) product_ids,
          ARRAY_AGG(product_name
                    ORDER BY product_id) product_names
   FROM filtered_transactions
   GROUP BY txn_id
   HAVING COUNT(DISTINCT product_id) = 3),
     counted_combinations AS
  (SELECT product_ids,
          product_names,
          COUNT(*) AS combination_count
   FROM grouped_products
   GROUP BY product_ids,
            product_names)
SELECT product_ids,
       product_names,
       combination_count
FROM counted_combinations
ORDER BY combination_count DESC
LIMIT 1;

-- Reporting Challenge
-- Write a single SQL script that combines all of the previous questions into a scheduled report that the Balanced Tree team can run at the beginning of each month to calculate the previous month’s values.
 -- Imagine that the Chief Financial Officer (who is also Danny) has asked for all of these questions at the end of every month.
 -- He first wants you to generate the data for January only - but then he also wants you to demonstrate that you can easily run the same analysis for February without many changes (if at all).
 -- Feel free to split up your final outputs into as many tables as you need - but be sure to explicitly reference which table outputs relate to which question for full marks :)
 -- Bonus Challenge
-- Use a single SQL query to transform the product_hierarchy and product_prices datasets to the product_details table.
 -- Hint: you may want to consider using a recursive CTE to solve this problem!