-- A. Digital Analysis
-- 1. How many users are there?
-- Answer:
-- 2. How many cookies does each user have on average?
-- Answer:
-- 3. What is the unique number of visit by all users pere month?
-- Answer:
-- 4. What is the number of events for each event type?
-- Answer:
-- 5. What is the percentage of visits which have a purchase event?
-- Answer:
-- 6. What is the percentage of visit which view the checkout page but do not have a purchase event?
-- Answer:
-- 7. What are the top 3 pages by number of views?
-- Answer:
-- 8. What is the number of views and cart adds for each product category?
-- Answer:
-- 9. What are the top 3 products by purchases?
-- Answer:
-- B. Product Funnel Analysis
-- Using a single SQL query - create a new output table which has the following details:
-- 1. How many times was each product viewed?
-- 2. How many times was each product added to cart?
-- 3. How many times was each product added to a cart but not purchased (abandoned)?
-- 4. How many times was each product purchased?

-- Let us visualize the output table.

-- Column	    Description
-- product	    Name of the product
-- views	    Number of views for each product
-- cart_adds	Number of cart adds for each product
-- abandoned	Number of times product was added to a cart, but not purchased
-- purchased	Number of times product was purchased
-- These information would come from these 2 tables.

-- events table - visit_id, page_id, event_type
-- page_hierarchy table - page_id, product_category
-- 1. Which product had the most views, cart adds and purchases?

-- 2. Which product was most likely to be abandoned?
-- 3. Which product had the highest view to purchase percentage?
-- 4. What is the average conversion rate from view to cart add?

-- 5. What is the average conversion rate from cart add to purchase?
-- C. Campaigns Analysis
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
-- (Optional column) cart_products: a comma separated text value with products added to the cart sorted by the order they were added to the cart (hint: use the sequence_number)
-- Answer:

-- Some ideas you might want to investigate further include:

-- Identifying users who have received impressions during each campaign period and comparing each metric with other users who did not have an impression event
-- Does clicking on an impression lead to higher purchase rates?
-- What is the uplift in purchase rate when comparing users who click on a campaign impression versus users who do not receive an impression? What if we compare them with users who just an impression but do not click?
-- What metrics can you use to quantify the success or failure of each campaign compared to each other?