/* --------------------
   Case Study Questions
   --------------------*/

-- 1. What is the total amount each customer spent at the restaurant?
-- Answer:
SELECT sales.customer_id,
       SUM(menu.price) AS total_sales
FROM dannys_diner.sales
INNER JOIN dannys_diner.menu ON sales.product_id = menu.product_id
GROUP BY sales.customer_id
ORDER BY sales.customer_id;
-- 2. How many days has each customer visited the restaurant?
-- Answer:
SELECT customer_id,
       COUNT(DISTINCT order_date) AS visit_count
FROM dannys_diner.sales
GROUP BY customer_id;
-- It's important to apply the DISTINCT keyword while calculating the visit count to avoid duplicate counting of days. 
-- For instance, if Customer A visited the restaurant twice on '2021–01–07', 
-- counting without DISTINCT would result in 2 days instead of the accurate count of 1 day.
-- 3. What was the first item from the menu purchased by each customer?
-- Answer:
WITH ordered_sales AS
  (SELECT sales.customer_id,
          sales.order_date,
          menu.product_name,
          DENSE_RANK() OVER (PARTITION BY sales.customer_id
                             ORDER BY sales.order_date) AS rank
   FROM dannys_diner.sales
   INNER JOIN dannys_diner.menu ON sales.product_id = menu.product_id)
SELECT customer_id,
       product_name
FROM ordered_sales
WHERE rank = 1
GROUP BY customer_id,
         product_name;
-- 4. What is the most purchased item on the menu and how many times was it purchased by all customers?
-- Answer:
SELECT m.product_name,
       COUNT(s.product_id) purchased_times
FROM dannys_diner.sales s
INNER JOIN dannys_diner.menu m ON s.product_id = m.product_id
GROUP BY m.product_name
ORDER BY purchased_times DESC
LIMIT 1;
-- 5. Which item was the most popular for each customer?
-- Answer:
WITH ordered_sale AS
  (SELECT s.customer_id,
          m.product_name,
          COUNT(s.product_id) order_count,
          DENSE_RANK() OVER (PARTITION BY s.customer_id
                             ORDER BY COUNT(s.product_id) DESC) AS rank
   FROM dannys_diner.sales s
   INNER JOIN dannys_diner.menu m ON s.product_id = m.product_id
   GROUP BY s.customer_id,
            m.product_name)
SELECT customer_id,
       product_name,
       order_count
FROM ordered_sale
WHERE rank = 1;
-- 6. Which item was purchased first by the customer after they became a member?
-- Answer:
WITH ordered_after_join_sales AS
  (SELECT m.customer_id,
          me.product_name,
          ROW_NUMBER() OVER (PARTITION BY s.customer_id
                             ORDER BY s.order_date) AS row_num
   FROM dannys_diner.members m
   JOIN dannys_diner.sales s ON m.customer_id = s.customer_id
   JOIN dannys_diner.menu me ON s.product_id = me.product_id
   WHERE s.order_date > m.join_date )
SELECT customer_id,
       product_name
FROM ordered_after_join_sales
WHERE row_num = 1;
-- 7. Which item was purchased just before the customer became a member?
-- Answer:
WITH ordered_before_became_member AS
  (SELECT s.customer_id,
          me.product_name,
          ROW_NUMBER() OVER (PARTITION BY s.customer_id
                             ORDER BY s.order_date DESC) rank
   FROM dannys_diner.members m
   INNER JOIN dannys_diner.sales s ON s.customer_id = m.customer_id
   INNER JOIN dannys_diner.menu me ON s.product_id = me.product_id
   WHERE s.order_date < m.join_date )
SELECT customer_id,
       product_name
FROM ordered_before_became_member
WHERE rank = 1
ORDER BY customer_id;
-- 8. What is the total items and amount spent for each member before they became a member?
-- Answer:
SELECT s.customer_id,
       COUNT(s.product_id) total_items,
       SUM(me.price) amount
FROM dannys_diner.members m
INNER JOIN dannys_diner.sales s ON s.customer_id = m.customer_id
INNER JOIN dannys_diner.menu me ON s.product_id = me.product_id
WHERE s.order_date < m.join_date
GROUP BY s.customer_id
ORDER BY s.customer_id;
-- 9.  If each $1 spent equates to 10 points and sushi has a 2x points multiplier - how many points would each customer have?
-- Answer:
SELECT s.customer_id,
       SUM(CASE
               WHEN me.product_name = 'sushi' THEN me.price * 2 * 10
               ELSE me.price * 10
           END) POINT
FROM dannys_diner.sales s
INNER JOIN dannys_diner.menu me ON s.product_id = me.product_id
GROUP BY s.customer_id
ORDER BY s.customer_id;
-- 10. In the first week after a customer joins the program (including their join date) they earn 2x points on all items, not just sushi - how many points do customer A and B have at the end of January?
WITH dates_cte AS
  (SELECT customer_id,
          join_date,
          join_date + 6 AS valid_date,
          DATE_TRUNC('month', '2021-01-31'::DATE) + interval '1 month' - interval '1 day' AS last_date
   FROM dannys_diner.members)
SELECT sales.customer_id,
       SUM(CASE
               WHEN menu.product_name = 'sushi' THEN 2 * 10 * menu.price
               WHEN sales.order_date BETWEEN dates.join_date AND dates.valid_date THEN 2 * 10 * menu.price
               ELSE 10 * menu.price
           END) AS points
FROM dannys_diner.sales
INNER JOIN dates_cte AS dates ON sales.customer_id = dates.customer_id
AND dates.join_date <= sales.order_date
AND sales.order_date <= dates.last_date
INNER JOIN dannys_diner.menu ON sales.product_id = menu.product_id
GROUP BY sales.customer_id;