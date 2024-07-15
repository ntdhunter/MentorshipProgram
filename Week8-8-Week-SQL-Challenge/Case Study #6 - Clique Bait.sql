-- A. Digital Analysis
-- 1. How many users are there?
-- Answer:

SELECT COUNT(DISTINCT user_id) number_of_users
FROM clique_bait.users;

-- 2. How many cookies does each user have on average?
-- Answer:
WITH cookies_per_user AS
  (SELECT user_id,
          COUNT(cookie_id) cookie_count
   FROM clique_bait.users
   GROUP BY user_id)
SELECT AVG(cookie_count) avg_cookies_per_user
FROM cookies_per_user;

-- 3. What is the unique number of visits by all users per month?
-- Answer:

SELECT TO_CHAR(e.event_time, 'Month') month_name,
       COUNT(DISTINCT visit_id) visit_count
FROM clique_bait.users u
JOIN clique_bait.events e ON u.cookie_id = e.cookie_id
GROUP BY DATE_PART('month', e.event_time),
         month_name
ORDER BY DATE_PART('month', e.event_time);

-- 4. What is the number of events for each event type?
-- Answer:

SELECT ei.event_name,
       COUNT(e.event_type)
FROM clique_bait.event_identifier ei
JOIN clique_bait.events e ON ei.event_type = e.event_type
GROUP BY ei.event_name,
         ei.event_type
ORDER BY ei.event_type;

-- 5. What is the percentage of visits that have a purchase event?
-- Answer:
-- event_type = 3 is the purchase event

SELECT ROUND(100.0 * SUM(CASE
                             WHEN event_type = 3 THEN 1
                             ELSE 0
                         END) /
               (SELECT COUNT(DISTINCT visit_id)
                FROM clique_bait.events), 2) purchased_percentage
FROM clique_bait.events;

-- 6. What is the percentage of visits who view the checkout page but do not have a purchase event?
-- Answer:
-- event_type = 3 is purchase event, page_id = 12 is checkout page
-- Formula: purchase/checkout * 100
WITH checkout_purchase AS
  (SELECT visit_id,
          MAX(CASE
                  WHEN event_type = 1
                       AND page_id = 12 THEN 1
                  ELSE 0
              END) AS checkout,
          MAX(CASE
                  WHEN event_type = 3 THEN 1
                  ELSE 0
              END) AS purchase
   FROM clique_bait.events
   GROUP BY visit_id)
SELECT ROUND(100 * (1-(SUM(purchase)::numeric/SUM(checkout))), 2) AS percentage_checkout_view_with_no_purchase
FROM checkout_purchase;

-- 7. What are the top 3 pages by number of views?
-- Answer:

SELECT ph.page_name,
       SUM(CASE
               WHEN event_type = 1 THEN 1
               ELSE 0
           END) views_count
FROM clique_bait.events e
JOIN clique_bait.page_hierarchy ph ON e.page_id = ph.page_id
GROUP BY ph.page_id,
         ph.page_name
ORDER BY ph.page_id,
         views_count DESC
LIMIT 3;

-- 8. What is the number of views and cart adds for each product category?
-- Answer:

SELECT ph.product_category,
       SUM(CASE
               WHEN e.event_type = 1 THEN 1
               ELSE 0
           END) views_count,
       SUM(CASE
               WHEN e.event_type = 2 THEN 1
               ELSE 0
           END) add_to_cards_count
FROM clique_bait.events e
JOIN clique_bait.page_hierarchy ph ON e.page_id = ph.page_id
WHERE ph.product_category IS NOT NULL
GROUP BY ph.product_category;

-- 9. What are the top 3 products by purchase?
-- Answer:
 -- B. Product Funnel Analysis
-- Using a single SQL query - create a new output table which has the following details:
-- 1. How many times was each product viewed?
-- 2. How many times was each product added to the cart?
-- 3. How often was each product added to a cart but not purchased (abandoned)?
-- 4. How many times was each product purchased?
 -- Let us visualize the output table.
 -- Column	    Description
-- product	    Name of the product
-- views	    Number of views for each product
-- cart_adds	Number of cart adds for each product
-- abandoned	Number of times product was added to a cart, but not purchased
-- purchased	Number of times the product was purchased
-- this information would come from these 2 tables.
 -- events table - visit_id, page_id, event_type
-- page_hierarchy table - page_id, product_category
-- Answer:
-- Note 1 - In product_page_events CTE, find page views and cart adds for individual visit ids by wrapping SUM around CASE statements so that we do not have to group the results by event_type as well.
-- Note 2 - In purchase_events CTE, get only visit ids that have made purchases.
-- Note 3 - In combined_table CTE, merge product_page_events and purchase_events using LEFT JOIN. Take note of the table sequence. To filter for visit ids with purchases, we use a CASE statement, and where the visit id is not null, it means the visit id is a purchase.
WITH product_page_events AS
  (-- Note 1
 SELECT e.visit_id,
        ph.product_id,
        ph.page_name AS product_name,
        ph.product_category,
        SUM(CASE
                WHEN e.event_type = 1 THEN 1
                ELSE 0
            END) AS page_view, -- 1 for Page View
 SUM(CASE
         WHEN e.event_type = 2 THEN 1
         ELSE 0
     END) AS cart_add -- 2 for Add Cart

   FROM clique_bait.events AS e
   JOIN clique_bait.page_hierarchy AS ph ON e.page_id = ph.page_id
   WHERE product_id IS NOT NULL
   GROUP BY e.visit_id,
            ph.product_id,
            ph.page_name,
            ph.product_category),
     purchase_events AS
  (-- Note 2
 SELECT DISTINCT visit_id
   FROM clique_bait.events
   WHERE event_type = 3 -- 3 for Purchase
),
     combined_table AS
  (-- Note 3
 SELECT ppe.visit_id,
        ppe.product_id,
        ppe.product_name,
        ppe.product_category,
        ppe.page_view,
        ppe.cart_add,
        CASE
            WHEN pe.visit_id IS NOT NULL THEN 1
            ELSE 0
        END AS purchase
   FROM product_page_events AS ppe
   LEFT JOIN purchase_events AS pe ON ppe.visit_id = pe.visit_id),
     product_info AS
  (SELECT product_id,
          product_name,
          product_category,
          SUM(page_view) AS VIEWS,
          SUM(cart_add) AS cart_adds,
          SUM(CASE
                  WHEN cart_add = 1
                       AND purchase = 0 THEN 1
                  ELSE 0
              END) AS abandoned,
          SUM(CASE
                  WHEN cart_add = 1
                       AND purchase = 1 THEN 1
                  ELSE 0
              END) AS purchases
   FROM combined_table
   GROUP BY product_id,
            product_name,
            product_category)
SELECT *
FROM product_info
ORDER BY product_id;

WITH product_page_events AS
  (-- Note 1
 SELECT e.visit_id,
        ph.product_id,
        ph.page_name AS product_name,
        ph.product_category,
        SUM(CASE
                WHEN e.event_type = 1 THEN 1
                ELSE 0
            END) AS page_view, -- 1 for Page View
 SUM(CASE
         WHEN e.event_type = 2 THEN 1
         ELSE 0
     END) AS cart_add -- 2 for Add Cart

   FROM clique_bait.events AS e
   JOIN clique_bait.page_hierarchy AS ph ON e.page_id = ph.page_id
   WHERE product_id IS NOT NULL
   GROUP BY e.visit_id,
            ph.product_id,
            ph.page_name,
            ph.product_category),
     purchase_events AS
  (-- Note 2
 SELECT DISTINCT visit_id
   FROM clique_bait.events
   WHERE event_type = 3 -- 3 for Purchase
),
     combined_table AS
  (-- Note 3
 SELECT ppe.visit_id,
        ppe.product_id,
        ppe.product_name,
        ppe.product_category,
        ppe.page_view,
        ppe.cart_add,
        CASE
            WHEN pe.visit_id IS NOT NULL THEN 1
            ELSE 0
        END AS purchase
   FROM product_page_events AS ppe
   LEFT JOIN purchase_events AS pe ON ppe.visit_id = pe.visit_id),
     product_category AS
  (SELECT product_category,
          SUM(page_view) AS VIEWS,
          SUM(cart_add) AS cart_adds,
          SUM(CASE
                  WHEN cart_add = 1
                       AND purchase = 0 THEN 1
                  ELSE 0
              END) AS abandoned,
          SUM(CASE
                  WHEN cart_add = 1
                       AND purchase = 1 THEN 1
                  ELSE 0
              END) AS purchases
   FROM combined_table
   GROUP BY product_category)
SELECT *
FROM product_category;

-- 1. Which product had the most views, cart adds, and purchases?
-- Answer:
-- Oyster has the most views.
-- Lobster has the most cart adds and purchases.
-- Russian Caviar is most likely to be abandoned.
-- 2. Which product was most likely to be abandoned?
-- Answer:
-- Russian Caviar is most likely to be abandoned.
-- 3. Which product had the highest view to purchase percentage?
-- Answer:

SELECT product_name,
       product_category,
       ROUND(100 * purchases/VIEWS, 2) AS purchase_per_view_percentage
FROM product_info
ORDER BY purchase_per_view_percentage DESC -- 4. What is the average conversion rate from view to cart add?
-- Answer:

SELECT ROUND(100*AVG(cart_adds/VIEWS), 2) AS avg_view_to_cart_add_conversion
FROM product_info -- 5. What is the average conversion rate from cart add to purchase?
-- Answer:

SELECT ROUND(100*AVG(purchases/cart_adds), 2) AS avg_cart_add_to_purchases_conversion_rate
FROM product_info -- C. Campaigns Analysis
-- Generate a table that has 1 single row for every unique visit_id record and has the following columns:
-- user_id
-- visit_id
-- visit_start_time: the earliest event_time for each visit
-- page_views: count of page views for each visit
-- cart_adds: count of product cart add events for each visit
-- purchase: 1/0 flag if a purchase event exists for each visit
-- campaign_name: map the visit to a campaign if the visit_start_time falls between the start_date and end_date
-- impression: count of ad impressions for each visit
-- click: count of ad clicks for each visit
-- (Optional column) cart_products: a comma-separated text value with products added to the cart sorted by the order they were added to the cart (hint: use the sequence_number)
-- Answer:

SELECT u.user_id,
       e.visit_id,
       MIN(e.event_time) AS visit_start_time,
       SUM(CASE
               WHEN e.event_type = 1 THEN 1
               ELSE 0
           END) AS page_views,
       SUM(CASE
               WHEN e.event_type = 2 THEN 1
               ELSE 0
           END) AS cart_adds,
       SUM(CASE
               WHEN e.event_type = 3 THEN 1
               ELSE 0
           END) AS purchase,
       c.campaign_name,
       SUM(CASE
               WHEN e.event_type = 4 THEN 1
               ELSE 0
           END) AS impression,
       SUM(CASE
               WHEN e.event_type = 5 THEN 1
               ELSE 0
           END) AS click,
       STRING_AGG(CASE
                      WHEN p.product_id IS NOT NULL
                           AND e.event_type = 2 THEN p.page_name
                      ELSE NULL
                  END, ', '
                  ORDER BY e.sequence_number) AS cart_products
FROM clique_bait.users AS you
INNER JOIN clique_bait.events AS e ON u.cookie_id = e.cookie_id
LEFT JOIN clique_bait.campaign_identifier AS c ON e.event_time BETWEEN c.start_date AND c.end_date
LEFT JOIN clique_bait.page_hierarchy AS p ON e.page_id = p.page_id
GROUP BY u.user_id,
         e.visit_id,
         c.campaign_name;

-- Some ideas you might want to investigate further include:
 -- Identifying users who have received impressions during each campaign period and comparing each metric with other users who did not have an impression event
-- Does clicking on an impression lead to higher purchase rates?
-- What is the uplift in purchase rate when comparing users who click on a campaign impression versus users who do not receive an impression? What if we compare them with users who just make an impression but do not click?
-- What metrics can you use to quantify the success or failure of each campaign compared to each other?