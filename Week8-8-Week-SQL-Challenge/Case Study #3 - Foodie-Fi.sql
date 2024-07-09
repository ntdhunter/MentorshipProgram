-- A. Customer Journey
-- 1. Based off the 8 sample customers provided in the sample subscriptions table below,
-- write a brief description about each customer’s onboarding journey.
-- Answer:

SELECT sub.customer_id,
       plans.plan_id,
       plans.plan_name,
       sub.start_date
FROM foodie_fi.plans
JOIN foodie_fi.subscriptions AS sub ON plans.plan_id = sub.plan_id
WHERE sub.customer_id IN (1,
                          2,
                          11,
                          13,
                          15,
                          16,
                          18,
                          19)
ORDER BY sub.customer_id;

-- B. Data Analysis Questions
-- 1. How many customers has Foodie-Fi ever had?
-- Answer:

SELECT COUNT(DISTINCT customer_id) num_of_customers
FROM foodie_fi.subscriptions;

-- 2. What is the monthly distribution of trial plan start_date values for our dataset -
-- use the start of the month as the group by value
-- Answer:

SELECT DATE_PART('month', s.start_date) month_date,
       TO_CHAR(s.start_date, 'FMMonth') month_name,
       COUNT(s.customer_id) trial_plan_subscriptions
FROM foodie_fi.plans p
JOIN foodie_fi.subscriptions s ON p.plan_id = s.plan_id
WHERE p.plan_name = 'trial'
GROUP BY month_date,
         month_name
ORDER BY month_date;

-- 3. What plan start_date values occur after the year 2020 for our dataset?
-- Show the breakdown by count of events for each plan_name.
-- Answer:

SELECT p.plan_id,
       p.plan_name,
       COUNT(s.customer_id) num_of_events
FROM foodie_fi.plans p
JOIN foodie_fi.subscriptions s ON p.plan_id = s.plan_id
WHERE s.start_date >= '2021-01-01'
GROUP BY p.plan_name,
         p.plan_id
ORDER BY p.plan_id;

-- 4. What is the customer count and percentage of customers who have churned rounded to 1 decimal place?
-- Answer:

SELECT SUM (CASE
                WHEN p.plan_name = 'churn' THEN 1
                ELSE 0
            END) churned_customers,
           ROUND(100.0 * SUM (CASE
                                  WHEN p.plan_name = 'churn' THEN 1
                                  ELSE 0
                              END) / COUNT(DISTINCT s.customer_id), 1) percentage_churned_customer
FROM foodie_fi.plans p
JOIN foodie_fi.subscriptions s ON p.plan_id = s.plan_id -- 5. How many customers have churned straight after their initial free trial -
-- what percentage is this rounded to the nearest whole number?
-- Answer:
WITH plan_per_customer AS
  (SELECT s.customer_id,
          p.plan_name,
          ROW_NUMBER() OVER (PARTITION BY s.customer_id
                             ORDER BY s.start_date) counts
   FROM foodie_fi.plans p
   JOIN foodie_fi.subscriptions s ON p.plan_id = s.plan_id
   ORDER BY s.customer_id)
SELECT COUNT(*) churned_customers,
       ROUND(100.0 * COUNT(*) /
               (SELECT COUNT(DISTINCT customer_id) num_of_customers
                FROM foodie_fi.subscriptions), 1) churn_percentage
FROM plan_per_customer
WHERE plan_name = 'churn'
  AND counts = 2;

-- OR
-- Using the LEAD() window function to find next plan of currnent plan
-- The LEAD window function in PostgreSQL is used to access data from a subsequent row in the same result set without the need for a self-join.
-- It is particularly useful for performing calculations or comparisons between rows in a data set.
WITH ranked_cte AS
  (SELECT sub.customer_id,
          plans.plan_name,
          LEAD(plans.plan_name) OVER (PARTITION BY sub.customer_id
                                      ORDER BY sub.start_date) AS next_plan
   FROM foodie_fi.subscriptions AS sub
   JOIN foodie_fi.plans ON sub.plan_id = plans.plan_id)
SELECT COUNT(customer_id) AS churned_customers,
       ROUND(100.0 * COUNT(customer_id) /
               (SELECT COUNT(DISTINCT customer_id)
                FROM foodie_fi.subscriptions)) AS churn_percentage
FROM ranked_cte
WHERE plan_name = 'trial'
  AND next_plan = 'churn';

-- 6. What is the number and percentage of customer plans after their initial free trial?
-- Answer:
WITH next_plans AS
  (SELECT customer_id,
          plan_id,
          LEAD(plan_id) OVER(PARTITION BY customer_id
                             ORDER BY plan_id) AS next_plan_id
   FROM foodie_fi.subscriptions)
SELECT next_plan_id AS plan_id,
       COUNT(customer_id) AS converted_customers,
       ROUND(100 * COUNT(customer_id)::NUMERIC /
               (SELECT COUNT(DISTINCT customer_id)
                FROM foodie_fi.subscriptions) , 1) AS conversion_percentage
FROM next_plans
WHERE next_plan_id IS NOT NULL
  AND plan_id = 0
GROUP BY next_plan_id
ORDER BY next_plan_id;

-- 7. What is the customer count and percentage breakdown of all 5 plan_name values at 2020-12-31?
-- Answer:
-- Statistical the customer count and percentage from the start to 31-12-2020 for all 5 plans
WITH next_dates AS
  (SELECT customer_id,
          plan_id,
          start_date,
          LEAD(start_date) OVER (PARTITION BY customer_id
                                 ORDER BY start_date) AS next_date
   FROM foodie_fi.subscriptions
   WHERE start_date <= '2020-12-31' )
SELECT plan_id,
       COUNT(DISTINCT customer_id) AS customers,
       ROUND(100.0 * COUNT(DISTINCT customer_id) /
               (SELECT COUNT(DISTINCT customer_id)
                FROM foodie_fi.subscriptions) , 1) AS percentage
FROM next_dates
WHERE next_date IS NULL
GROUP BY plan_id;

-- 8. How many customers have upgraded to an annual plan in 2020?
-- Answer:

SELECT COUNT(DISTINCT s.customer_id)
FROM foodie_fi.plans p
JOIN foodie_fi.subscriptions s ON p.plan_id = s.plan_id
WHERE DATE_PART('year', s.start_date) = 2020
  AND p.plan_name = 'pro annual';

-- 9. How many days on average does it take for a customer to upgrade to an annual plan from the day they join Foodie-Fi?
-- Answer:
WITH trial_plan AS
  (SELECT customer_id,
          start_date trial_date
   FROM foodie_fi.subscriptions
   WHERE plan_id = 0 ),
     annual_plan AS
  (SELECT customer_id,
          start_date annual_date
   FROM foodie_fi.subscriptions
   WHERE plan_id = 3 )
SELECT ROUND(AVG(a.annual_date - t.trial_date) , 1) avg_days_to_upgrade
FROM trial_plan t
JOIN annual_plan a ON t.customer_id = a.customer_id;

-- 10. Can you further breakdown this average value into 30 day periods (i.e. 0-30 days, 31-60 days etc)
-- Answer:
-- trial_plan CTE: Filter results to include only the customers subscribed to the trial plan.
-- annual_plan CTE: Filter results to only include the customers subscribed to the pro annual plan.
-- bins CTE: Put customers in 30-day buckets based on the average number of days taken to upgrade to a pro annual plan.
WITH trial_plan AS
  (SELECT customer_id,
          start_date AS trial_date
   FROM foodie_fi.subscriptions
   WHERE plan_id = 0 ),
     annual_plan AS
  (SELECT customer_id,
          start_date AS annual_date
   FROM foodie_fi.subscriptions
   WHERE plan_id = 3 ),
     bins AS
  (SELECT WIDTH_BUCKET(annual.annual_date - trial.trial_date, 0, 365, 12) AS avg_days_to_upgrade
   FROM trial_plan AS trial
   JOIN annual_plan AS annual ON trial.customer_id = annual.customer_id)
SELECT ((avg_days_to_upgrade - 1) * 30 || ' - ' || avg_days_to_upgrade * 30 || ' days') AS bucket,
       COUNT(*) AS num_of_customers
FROM bins
GROUP BY avg_days_to_upgrade
ORDER BY avg_days_to_upgrade;

-- 11. How many customers downgraded from a pro monthly to a basic monthly plan in 2020?
-- Answer:
WITH basic_monthly_plan AS
  (SELECT customer_id,
          start_date basic_monthly_date
   FROM foodie_fi.subscriptions
   WHERE plan_id = 1
     AND DATE_PART('year', start_date) = 2020 ),
     pro_monthly_plan AS
  (SELECT customer_id,
          start_date pro_monthly_date
   FROM foodie_fi.subscriptions
   WHERE plan_id = 2
     AND DATE_PART('year', start_date) = 2020 )
SELECT COUNT(*)
FROM basic_monthly_plan b
JOIN pro_monthly_plan p ON b.customer_id = p.customer_id
WHERE b.basic_monthly_date > p.pro_monthly_date;

-- OR
WITH ranked_cte AS
  (SELECT sub.customer_id,
          plans.plan_id,
          plans.plan_name,
          LEAD(plans.plan_id) OVER (PARTITION BY sub.customer_id
                                    ORDER BY sub.start_date) AS next_plan_id
   FROM foodie_fi.subscriptions AS sub
   JOIN foodie_fi.plans ON sub.plan_id = plans.plan_id
   WHERE DATE_PART('year', start_date) = 2020 )
SELECT COUNT(customer_id) AS churned_customers
FROM ranked_cte
WHERE plan_id = 2
  AND next_plan_id = 1;