-- Data Cleaning and Transformation
-- Table: customer_orders
-- Answer:

CREATE TEMP TABLE customer_orders_temp AS
SELECT order_id,
       customer_id,
       pizza_id,
       CASE
           WHEN exclusions IS NULL
                OR exclusions LIKE 'null' THEN ' '
           ELSE exclusions
       END AS exclusions,
       CASE
           WHEN extras IS NULL
                OR extras LIKE 'null' THEN ' '
           ELSE extras
       END AS extras,
       order_time
FROM pizza_runner.customer_orders;


SELECT *
FROM customer_orders_temp;

-- Table: runner_orders
-- Answer:

CREATE TEMP TABLE runner_orders_temp AS
SELECT order_id,
       runner_id,
       CASE
           WHEN pickup_time IS NULL
                OR pickup_time LIKE 'null' THEN ' '
           ELSE pickup_time
       END pickup_time,
       CASE
           WHEN distance IS NULL
                OR distance LIKE 'null' THEN ' '
           WHEN distance LIKE '%km%' THEN TRIM(REPLACE(REPLACE(distance, ' km', ''), 'km', ''))
           ELSE distance
       END AS distance,
       CASE
           WHEN duration IS NULL
                OR duration LIKE 'null' THEN ' '
           WHEN duration LIKE '%minutes%' THEN TRIM('minutes'
                                                    FROM duration)
           WHEN duration LIKE '%minute%' THEN TRIM('minute'
                                                   FROM duration)
           WHEN duration LIKE '%mins%' THEN TRIM('mins'
                                                 FROM duration)
           ELSE duration
       END AS duration,
       CASE
           WHEN cancellation IS NULL
                OR cancellation LIKE 'null' THEN ' '
           ELSE cancellation
       END AS cancellation
FROM pizza_runner.runner_orders;


SELECT *
FROM runner_orders_temp;


ALTER TABLE runner_orders_temp
ALTER COLUMN pickup_time TIMESTAMP,
ALTER COLUMN distance FLOAT,
ALTER COLUMN duration INT;

-- A. Pizza Metrics
-- 1. How many pizzas were ordered?
-- Answer:

SELECT COUNT(*)
FROM pizza_runner.customer_orders;

-- 2. How many unique customer orders were made?
-- Answer:

SELECT COUNT(DISTINCT order_id)
FROM pizza_runner.customer_orders;

-- 3. How many successful orders were delivered by each runner?
-- Answer: The distance difference of 0 is the condition of the successful orders

SELECT runner_id,
       COUNT(order_id) AS successful_orders
FROM #runner_orders
WHERE distance != 0
GROUP BY runner_id;

-- 4. How many of each type of pizza was delivered?
-- Answer: The distance difference of 0 is the condition of the type of pizzas are delivered

SELECT p.pizza_name,
       COUNT(c.pizza_id) AS delivered_pizza_count
FROM #customer_orders AS c
JOIN #runner_orders AS r ON c.order_id = r.order_id
JOIN pizza_names AS p ON c.pizza_id = p.pizza_id
WHERE r.distance != 0
GROUP BY p.pizza_name;

-- 5. How many Vegetarian and Meatlovers were ordered by each customer?
-- Answer:

SELECT c.customer_id,
       SUM (CASE
                WHEN p.pizza_name = 'Vegetarian' THEN 1
                ELSE 0
            END) vegetarian_counts,
           SUM (CASE
                    WHEN p.pizza_name = 'Meatlovers' THEN 1
                    ELSE 0
                END) meatlovers_counts
FROM pizza_runner.customer_orders c
INNER JOIN pizza_runner.pizza_names p ON c.pizza_id = p.pizza_id
GROUP BY c.customer_id
ORDER BY c.customer_id;

-- 6. What was the maximum number of pizza delivered in a single order?
-- Answer:

SELECT COUNT(pizza_id) pizzas_per_order
FROM pizza_runner.customer_orders c
JOIN runner_orders_temp AS r ON c.order_id = r.order_id
WHERE r.distance != 0
GROUP BY order_id
ORDER BY pizza_per_order DESC
LIMIT 1;

-- OR
WITH pizza_count_cte AS
  (SELECT c.order_id,
          COUNT(c.pizza_id) AS pizza_per_order
   FROM customer_orders_temp AS c
   JOIN runner_orders_temp AS r ON c.order_id = r.order_id
   WHERE r.distance != 0
   GROUP BY c.order_id)
SELECT MAX(pizza_per_order) AS pizza_count
FROM pizza_count_cte;

-- 7. For each customer, how many delivered pizzas had at least 1 change and how many had no changes?
-- Answer:

SELECT customer_id,
       COUNT (CASE
                  WHEN extras = ' '
                       AND exclusions = ' ' THEN 1
                  ELSE 0
              END) no_changes,
             COUNT (CASE
                        WHEN extras <> ' '
                             OR exclusions <> ' ' THEN 1
                        ELSE 0
                    END) at_least_one_change
FROM customer_orders_temp c
INNER JOIN runner_orders_temp r ON c.order_id = r.order_id
WHERE distance != 0
GROUP BY customer_id
ORDER BY customer_id;

-- 8. How many pizzas were delivered that had both exclusions and extras?
-- Answer:

SELECT COUNT (*) pizza_count_w_exclusions_extras
FROM pizza_runner.customer_orders c
INNER JOIN pizza_runner.runner_orders r ON c.order_id = r.order_id
WHERE r.distance IS NOT NULL
  AND r.distance NOT LIKE 'null'
  AND r.distance <> ''
  AND exclusions IS NOT NULL
  AND exclusions <> ''
  AND exclusions NOT LIKE 'null'
  AND extras IS NOT NULL
  AND extras <> ''
  AND extras NOT LIKE 'null';

-- OR

SELECT SUM(CASE
               WHEN exclusions IS NOT NULL
                    AND extras IS NOT NULL THEN 1
               ELSE 0
           END) AS pizza_count_w_exclusions_extras
FROM customer_orders_temp AS c
JOIN runner_orders_temp AS r ON c.order_id = r.order_id
WHERE r.distance >= 1
  AND exclusions <> ' '
  AND extras <> ' ';

-- 9. What was the total volume of pizzas ordered for each hour of the daay?
-- Answer:

SELECT DATE_PART('hour', order_time::TIMESTAMP) hour_of_day,
       COUNT(order_id) pizza_count
FROM pizza_runner.customer_orders
GROUP BY hour_of_day
ORDER BY hour_of_day;

-- 10. What was the volume of orders for each day of week?
-- Answer:

SELECT TO_CHAR(order_time, 'FMDay') day_of_week,
       COUNT(order_id) total_ordered
FROM pizza_runner.customer_orders
GROUP BY day_of_week;

-- B. Runner and Customer Experience
-- 1. How many runners signed up for each 1 week period? (i.e. week starts 2021-01-01)
-- Answer:

SELECT DATE_PART('week', registration_date::TIMESTAMP) week_period,
       COUNT(runner_id) runner_count
FROM pizza_runner.runners
GROUP BY week_period
ORDER BY week_period;

-- 2. What was the average time in minutes it took for each runner to arrive at the Pizza Runner HQ to pick up the order?
-- Answer:
WITH time_taken_cte AS
  (SELECT c.order_id,
          c.order_time,
          r.pickup_time,
          CAST(r.pickup_time AS TIMESTAMP) - c.order_time pickup_minutes
   FROM customer_orders_temp AS c
   JOIN runner_orders_temp AS r ON c.order_id = r.order_id
   WHERE r.distance <> ' '
   GROUP BY c.order_id,
            c.order_time,
            r.pickup_time)
SELECT AVG(pickup_minutes) AS avg_pickup_minutes
FROM time_taken_cte;

-- 3. Is there any relationship between the number of pizzas and how long the order takes to prepare?
-- Answer:
WITH prep_time_cte AS
  (SELECT c.order_id,
          COUNT(c.order_id) AS pizza_order,
          c.order_time,
          r.pickup_time,
          CAST(r.pickup_time AS TIMESTAMP) - c.order_time prep_time_minutes
   FROM customer_orders_temp AS c
   JOIN runner_orders_temp AS r ON c.order_id = r.order_id
   WHERE r.distance <> ' '
   GROUP BY c.order_id,
            c.order_time,
            r.pickup_time)
SELECT pizza_order,
       AVG(prep_time_minutes) AS avg_prep_time_minutes
FROM prep_time_cte
GROUP BY pizza_order;

-- 4. Is there any relationship between the number of pizzas and how long the order takes to prepare?
-- Answer:

SELECT c.customer_id,
       AVG(CAST(r.distance AS FLOAT)) AS avg_distance
FROM customer_orders_temp AS c
JOIN runner_orders_temp AS r ON c.order_id = r.order_id
WHERE r.duration <> ' '
GROUP BY c.customer_id;

-- 5. What was the difference between the longest and shortest delivery times for all orders?
-- Answer:

SELECT MAX(CAST(duration AS INTEGER)) - MIN(CAST(duration AS INTEGER)) delivery_time_difference
FROM runner_orders_temp
WHERE duration <> ' ';

-- 6. What was the average speed for each runner for each delivery and do you notice any trend for these values?
-- Answer:

SELECT r.runner_id,
       c.customer_id,
       c.order_id,
       COUNT(c.order_id) AS pizza_count,
       r.distance,
       r.duration,
       CAST(r.duration AS INTEGER) / 60 duration_hr,
       ROUND((CAST(r.distance AS FLOAT) / CAST(r.duration AS INTEGER) * 60)::NUMERIC, 2) avg_speed
FROM runner_orders_temp AS r
JOIN customer_orders_temp AS c ON r.order_id = c.order_id
WHERE r.distance <> ' '
GROUP BY r.runner_id,
         c.customer_id,
         c.order_id,
         r.distance,
         r.duration
ORDER BY c.order_id;

-- 7. What is the successful delivery percentage for each runner?
-- Answer:

SELECT runner_id,
       ROUND(100 * SUM(CASE
                           WHEN distance = ' ' THEN 0
                           ELSE 1
                       END) / COUNT(*), 0) AS success_perc
FROM runner_orders_temp
GROUP BY runner_id
ORDER BY runner_id;

-- C. Ingredient Optimisation
-- 1. What are the standard ingredients for each pizza?
-- Answer:
-- 2. What was the most commonly added extra?
-- Answer:
WITH toppings_cte AS
  (SELECT pizza_id,
          REGEXP_SPLIT_TO_TABLE(toppings, '[,\s]+')::INTEGER AS topping_id
   FROM pizza_runner.pizza_recipes)
SELECT t.topping_id,
       pt.topping_name,
       COUNT(t.topping_id) AS topping_count
FROM toppings_cte t
INNER JOIN pizza_runner.pizza_toppings pt ON t.topping_id = pt.topping_id
GROUP BY t.topping_id,
         pt.topping_name
ORDER BY topping_count DESC;

-- 3. What was the most common exclusion?
-- Answer:
-- 4. Generate an order item for each record in the customers_orders table in the format of one of the following:
-- Answer:
-- 5. Generate an alphabetically ordered comma separated ingredient list for each pizza order from the customer_orders table
-- and add a 2x in front of any relevant ingredients
-- Answer:
-- 6. For example: "Meat Lovers: 2xBacon, Beef, ... , Salami"
-- Answer:
-- 7. What is the total quantity of each ingredient used in all delivered pizzas sorted by most frequent first?
-- Answer:
-- D. Pricing and Ratings
-- 1. If a Meat Lovers pizza costs $12 and Vegetarian costs $10 and there were no charges for changes -
-- how much money has Pizza Runner made so far if there are no delivery fees?
-- Answer:
-- 2. What if there was an additional $1 charge for any pizza extras?
-- Answer:
-- 3. The Pizza Runner team now wants to add an additional ratings system that allows customers to rate their runner,
-- how would you design an additional table for this new dataset generate a schema for this new table
-- and insert your own data for ratings for each successful customer order between 1 to 5.
-- Answer:
-- 4. Using your newly generated table - can you join all of the information together to form a table which has the following information for successful deliveries?
-- Answer:
-- 5. If a Meat Lovers pizza was $12 and Vegetarian $10 fixed prices with no cost for extras and each runner is paid $0.30 per kilometre traveled -
-- how much money does Pizza Runner have left over after these deliveries?
-- Answer:
