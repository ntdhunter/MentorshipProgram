-- A. Data Cleansing Steps
-- In a single query, perform the following operations and generate a new table in the data_mart schema named clean_weekly_sales:
 -- Convert the week_date to a DATE format
-- Add a week_number as the second column for each week_date value, for example any value from the 1st of January to 7th of January will be 1, 8th to 14th will be 2 etc
-- Add a month_number with the calendar month for each week_date value as the 3rd column
-- Add a calendar_year column as the 4th column containing either 2018, 2019 or 2020 values
-- Add a new column called age_band after the original segment column using the following mapping on the number inside the segment value
-- Answer:

DROP TABLE IF EXISTS clean_weekly_sales;


CREATE TEMP TABLE clean_weekly_sales AS
  (SELECT TO_DATE(week_date, 'DD/MM/YY') AS week_date,
          DATE_PART('week', TO_DATE(week_date, 'DD/MM/YY')) AS week_number,
          DATE_PART('month', TO_DATE(week_date, 'DD/MM/YY')) AS month_number,
          DATE_PART('year', TO_DATE(week_date, 'DD/MM/YY')) AS calendar_year,
          region,
          platform,
          SEGMENT,
          CASE
              WHEN RIGHT(SEGMENT, 1) = '1' THEN 'Young Adults'
              WHEN RIGHT(SEGMENT, 1) = '2' THEN 'Middle Aged'
              WHEN RIGHT(SEGMENT, 1) IN ('3',
                                         '4') THEN 'Retirees'
              ELSE 'unknown'
          END AS age_band,
          CASE
              WHEN LEFT(SEGMENT, 1) = 'C' THEN 'Couples'
              WHEN LEFT(SEGMENT, 1) = 'F' THEN 'Families'
              ELSE 'unknown'
          END AS demographic,
          transactions,
          ROUND((sales::NUMERIC/transactions),2) AS avg_transaction,
          sales
   FROM data_mart.weekly_sales);

-- B. Data Exploration
-- 1. What day of week is used for each week_date value?
-- Answer:

SELECT DISTINCT(TO_CHAR(week_date, 'day')) AS week_day
FROM clean_weekly_sales;

-- 2. What range of week numbers are missing from the dataset?
-- Answer:
WITH week_number_cte AS
  (SELECT GENERATE_SERIES(1, 52) AS week_number)
SELECT DISTINCT week_no.week_number
FROM week_number_cte AS week_no
LEFT JOIN clean_weekly_sales AS sales ON week_no.week_number = sales.week_number
WHERE sales.week_number IS NULL; -- Filter to identify the missing week numbers where the values are `NULL`.
-- 3. How many total transactions were there for each year in the dataset?
-- Answer:

SELECT calendar_year,
       SUM(transactions)
FROM clean_weekly_sales
GROUP BY calendar_year;

-- 4. What is the total sales for each region for each month?
-- Answer:

SELECT region,
       month_number,
       SUM(sales)
FROM clean_weekly_sales
GROUP BY region,
         month_number
ORDER BY region,
         month_number;

-- 5.What is the total count of transactions for each platform?
-- Answer:

SELECT platform,
       SUM(transactions)
FROM clean_weekly_sales
GROUP BY platform
ORDER BY platform;

-- 6. What is the percentage of sales for Retail vs Shopify for each month?
-- Answer:
WITH monthly_sales AS
  (SELECT calendar_year,
          month_number,
          platform,
          SUM(sales) sales
   FROM clean_weekly_sales
   GROUP BY month_number,
            platform,
            calendar_year)
SELECT calendar_year,
       month_number,
       ROUND(100.0 * MAX(CASE
                             WHEN platform = 'Retail' THEN sales
                             ELSE 0
                         END) / SUM(sales), 2) retail_precentage,
       ROUND(100.0 * MAX(CASE
                             WHEN platform = 'Shopify' THEN sales
                             ELSE 0
                         END) / SUM(sales), 2) shopify_precentage
FROM monthly_sales
GROUP BY calendar_year,
         month_number
ORDER BY calendar_year,
         month_number;

-- 7. What is the percentage of sales by demographic for each year in the dataset?
-- Answer:
WITH yearly_sales AS
  (SELECT calendar_year,
          demographic,
          SUM(sales) sales
   FROM clean_weekly_sales
   GROUP BY calendar_year,
            demographic)
SELECT calendar_year,
       ROUND(100.0 * MAX(CASE
                             WHEN demographic = 'Couples' THEN sales
                             ELSE 0
                         END) / SUM(sales), 2) couples_percentage,
       ROUND(100.0 * MAX(CASE
                             WHEN demographic = 'Families' THEN sales
                             ELSE 0
                         END) / SUM(sales), 2) families_percentage,
       ROUND(100.0 * MAX(CASE
                             WHEN demographic = 'unknown' THEN sales
                             ELSE 0
                         END) / SUM(sales), 2) unknown_percentage
FROM yearly_sales
GROUP BY calendar_year
ORDER BY calendar_year;

-- 8. Which age_band and demographic values contribute the most to Retail sales?
-- Answer:

SELECT age_band,
       demographic,
       SUM(sales) sales
FROM clean_weekly_sales
WHERE platform = 'Retail'
GROUP BY age_band,
         demographic
ORDER BY sales DESC
LIMIT 1;

-- 9. Can we use the avg_transaction column to find the average transaction size for each year for Retail vs Shopify? If not -- how would you calculate it instead?
-- Answer: Yes

SELECT calendar_year,
       platform,
       SUM(avg_transaction) avg_transaction
FROM clean_weekly_sales
GROUP BY calendar_year,
         platform
ORDER BY calendar_year,
         platform;

-- C. Before & After Analysis
-- 1. What are the total sales for the 4 weeks before and after 2020-06-15? What is the growth or reduction rate in actual values and percentage of sales?
-- Answer:
-- Determine the week_number corresponding to '2020-06-15'

SELECT DISTINCT week_number
FROM clean_weekly_sales
WHERE week_date = '2020-06-15'
  AND calendar_year = '2020';

-- --> week_number = 25 --> 4 weeks before is 21 and 4 weeks after is 28
WITH packaging_sales AS
  (SELECT week_date,
          week_number,
          SUM(sales) AS total_sales
   FROM clean_weekly_sales
   WHERE (week_number BETWEEN 21 AND 28)
     AND (calendar_year = 2020)
   GROUP BY week_date,
            week_number),
     before_after_changes AS
  (SELECT SUM(CASE
                  WHEN week_number BETWEEN 21 AND 24 THEN total_sales
              END) AS before_packaging_sales,
          SUM(CASE
                  WHEN week_number BETWEEN 25 AND 28 THEN total_sales
              END) AS after_packaging_sales
   FROM packaging_sales)
SELECT after_packaging_sales - before_packaging_sales AS sales_variance,
       ROUND(100 * (after_packaging_sales - before_packaging_sales) / before_packaging_sales, 2) AS variance_percentage
FROM before_after_changes;

-- 2. What about the entire 12 weeks before and after?
-- Answer:
WITH packaging_sales AS
  (SELECT week_date,
          week_number,
          SUM(sales) AS total_sales
   FROM clean_weekly_sales
   WHERE (week_number BETWEEN 13 AND 36)
     AND (calendar_year = 2020)
   GROUP BY week_date,
            week_number),
     before_after_changes AS
  (SELECT SUM(CASE
                  WHEN week_number BETWEEN 13 AND 24 THEN total_sales
              END) AS before_packaging_sales,
          SUM(CASE
                  WHEN week_number BETWEEN 25 AND 36 THEN total_sales
              END) AS after_packaging_sales
   FROM packaging_sales)
SELECT after_packaging_sales - before_packaging_sales AS sales_variance,
       ROUND(100 * (after_packaging_sales - before_packaging_sales) / before_packaging_sales, 2) AS variance_percentage
FROM before_after_changes;

-- 3. How do the sales metrics for these 2 periods before and after compare with the previous years in 2018 and 2019?
-- Part 1: How do the sale metrics for 4 weeks before and after compare with the previous years in 2018 and 2019?
-- Answer:
WITH changes AS
  (SELECT calendar_year,
          week_number,
          SUM(sales) AS total_sales
   FROM clean_weekly_sales
   WHERE week_number BETWEEN 21 AND 28
   GROUP BY calendar_year,
            week_number),
     before_after_changes AS
  (SELECT calendar_year,
          SUM(CASE
                  WHEN week_number BETWEEN 13 AND 24 THEN total_sales
              END) AS before_packaging_sales,
          SUM(CASE
                  WHEN week_number BETWEEN 25 AND 28 THEN total_sales
              END) AS after_packaging_sales
   FROM changes
   GROUP BY calendar_year)
SELECT calendar_year,
       after_packaging_sales - before_packaging_sales AS sales_variance,
       ROUND(100 * (after_packaging_sales - before_packaging_sales) / before_packaging_sales, 2) AS variance_percentage
FROM before_after_changes;

-- Part 2: How do the sale metrics for 12 weeks beefore and after compare with the previous years in 2018 and 2019?
-- Answer:
WITH packaging_sales AS
  (SELECT calendar_year,
          week_number,
          SUM(sales) AS total_sales
   FROM clean_weekly_sales
   WHERE (week_number BETWEEN 13 AND 36)
   GROUP BY calendar_year,
            week_number),
     before_after_changes AS
  (SELECT calendar_year,
          SUM(CASE
                  WHEN week_number BETWEEN 13 AND 24 THEN total_sales
              END) AS before_packaging_sales,
          SUM(CASE
                  WHEN week_number BETWEEN 25 AND 36 THEN total_sales
              END) AS after_packaging_sales
   FROM packaging_sales
   GROUP BY calendar_year)
SELECT calendar_year,
       after_packaging_sales - before_packaging_sales AS sales_variance,
       ROUND(100 * (after_packaging_sales - before_packaging_sales) / before_packaging_sales, 2) AS variance_percentage
FROM before_after_changes;

-- D. Bonus Question
-- 1. Which areas of the business have the highest negative impact in sales metrics performance in 2020 for the 12 week before and after period?
-- Answer:
-- 2. Do you have any further recommendations for Danny’s team at Data Mart or any interesting insights based off this analysis?
-- Answer: