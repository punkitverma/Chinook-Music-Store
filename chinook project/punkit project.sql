use chinook;
-- OBJECTIVE QUESTIONS

-- Q1. Does any table have missing values or duplicates? If yes how would you handle it ?
SELECT * FROM album;
SELECT * FROM artist;
SELECT COUNT(*) FROM customer -- 49 company, 29 state, 47 fax values are null in the customer table
WHERE fax is NULL;
SELECT COUNT(*) FROM customer -- 49 company, 29 state, 47 fax values are null in the customer table
WHERE fax is NULL;
SELECT * from employee; -- 1 reports_to value is null in the employee table
SELECT * FROM genre;
SELECT * FROM invoice;
SELECT * FROM invoice_line;
SELECT * FROM media_type;
SELECT * FROM playlist;
SELECT * FROM playlist_track;
SELECT COUNT(*) FROM track -- 978 composer columns are null in the track table
WHERE composer is NULL

/*
The dataset does not contain any duplicate values, ensuring data accuracy and reliability.
To handle null values, the COALESCE function would be used.
*/

--------------------------------------------------------------------------------------------------------------------------------------------------------

-- Q2. Find the top-selling tracks and top artist in the USA and identify their most famous genres.

SELECT Top_selling_track, Top_artist, Top_genre FROM 
(
SELECT t.name Top_selling_track, a.name Top_artist, g.name Top_genre, SUM(t.unit_price * il.quantity) FROM track t
LEFT JOIN invoice_line il on t.track_id = il.track_id
LEFT JOIN invoice i on i.invoice_id = il.invoice_id
LEFT JOIN album al on al.album_id = t.album_id
LEFT JOIN artist a on a.artist_id = al.artist_id
LEFT JOIN genre g on g.genre_id = t.genre_id
WHERE billing_country = "USA"
GROUP BY t.name, a.name, g.name
ORDER BY SUM(total) DESC
LIMIT 10
) Agg_table;

--------------------------------------------------------------------------------------------------

-- Q3. What is the customer demographic breakdown (age, gender, location) of Chinook's customer base?

SELECT city, country, COUNT(customer_id) FROM customer
GROUP BY 1,2
ORDER BY country;

SELECT country, COUNT(customer_id) FROM customer
GROUP BY 1
ORDER BY 1;

SELECT COUNT(distinct country) FROM customer;

/*
The customer demographic breakdown based on location is highly diversified.
Chinook's customer base spans 24 countries, with the maximum number of customers located in the USA.
However, the customer table lacks age and gender columns, which limits the ability to perform a 
detailed demographic analysis of the customer base.
*/

-------------------------------------------------------------------------------------------------------

-- Q4. Calculate the total revenue and number of invoices for each country, state, and city

SELECT billing_city, billing_state, billing_country, COUNT(invoice_id) num_of_invoices, SUM(total) total_revenue FROM invoice
GROUP BY 1,2,3
ORDER BY COUNT(invoice_id) DESC, SUM(total) DESC

---------------------------------------------------------------------------------------------------------

-- Q5. Find the top 5 customers by total revenue in each country

WITH cte as
(
SELECT country, first_name, last_name, SUM(t.unit_price * il.quantity) total_revenue FROM customer c
LEFT JOIN invoice i on i.customer_id = c.customer_id
LEFT JOIN invoice_line il on il.invoice_id = i.invoice_id 
LEFT JOIN track t on t.track_id = il.track_id
GROUP BY 1,2,3
ORDER BY country
),
cte2 as
(
SELECT country, first_name, last_name,
RANK() OVER(PARTITION BY country ORDER BY total_revenue DESC) rk
FROM cte
)
SELECT country, first_name, last_name FROM cte2
WHERE rk <= 5;

--------------------------------------------------------------------------------------------------------

-- Q6. Identify the top-selling track for each customer

with CustomerTrackSales as (
	select 
		c.customer_id,
        CONCAT(c.first_name, ' ', c.last_name) as customer_full_name,
        t.name as track_name,
        SUM(il.unit_price * il.quantity) as total_revenue,
        ROW_NUMBER() over (PARTITION BY c.customer_id ORDER BY SUM(il.unit_price * il.quantity) DESC) as rank_num
	FROM customer c
	JOIN invoice i on c.customer_id = i.customer_id
	JOIN invoice_line il on i.invoice_id = il.invoice_id
	JOIN track t on il.track_id = t.track_id
	GROUP BY c.customer_id, customer_full_name, t.name
)
SELECT
	customer_id,
    customer_full_name,
    track_name,
    total_revenue
FROM CustomerTrackSales
WHERE rank_num = 1
ORDER BY customer_id;



----------------------------------------------------------------------------------------------------

-- Q7. Are there any patterns or trends in customer purchasing behavior 
-- (e.g., frequency of purchases, preferred payment methods, average order value)?

WITH InvoiceMetrics AS (
    SELECT
        c.customer_id,
        CONCAT(c.first_name, ' ', c.last_name) AS customer_name,
        i.invoice_date,
        DATEDIFF(
            LEAD(i.invoice_date) OVER (PARTITION BY c.customer_id ORDER BY i.invoice_date),
            i.invoice_date
        ) AS days_between_purchases,
        i.total
    FROM
        customer c
    JOIN
        invoice i ON c.customer_id = i.customer_id
),
CustomerStats AS (
    SELECT
        customer_id,
        customer_name,
        COUNT(*) AS total_purchases,
        AVG(days_between_purchases) AS avg_days_between_purchases,
        SUM(total) AS total_spent,
        AVG(total) AS avg_order_value,
        MAX(total) AS max_order_value,
        MIN(total) AS min_order_value
    FROM
        InvoiceMetrics
    GROUP BY
        customer_id, customer_name
)
SELECT
    customer_id,
    customer_name,
    total_purchases,
    avg_days_between_purchases,
    total_spent,
    avg_order_value,
    max_order_value,
    min_order_value
FROM
    CustomerStats
WHERE
    total_spent > 0
ORDER BY
    avg_days_between_purchases ASC,
    total_spent DESC,
    total_purchases DESC;


/*
No there is no correlation or trend between the number/frequency of orders by different customers and the 
average sales generated by these customers.
The average sales most probably depends on the unit price of each track and not he number of orders.
*/ 
------------------------------------------------------------------------------------------------------

-- Q8. What is the customer churn rate?

WITH num_cust_in_1st_3months as 
(
SELECT COUNT(customer_id) ttl from invoice
WHERE invoice_date BETWEEN '2017-01-01' AND '2017-03-31'
),-- I have taken the assumption that total number of customers in the beginning is equal to the customers joining in the first 3 months.
num_cust_in_last_2months as
(
SELECT COUNT(customer_id) l_num FROM invoice
WHERE invoice_date BETWEEN '2020-11-01' AND '2020-12-31' 
) -- I have taken the assumption that churn rate will be calculated on the basis of the number of customers left in the last two months. 
SELECT ((SELECT ttl FROM num_cust_in_1st_3months)-(SELECT l_num FROM num_cust_in_last_2months))/(SELECT ttl FROM num_cust_in_1st_3months) * 100 as churn_rate
;

/* 
Therefore the customer churn rate of the company is 40.8163 based on the total number of customer 
in first 3 months i.e 49 and the number of customer present in the last 2 months i.e 29
So, number of customers lost = 49-29 = 20
*/ 
------------------------------------------------------------------------------------------------------

-- Q9. Calculate the percentage of total sales contributed by each genre in the USA and 
--     identify the best-selling genres and artists.

WITH cte as
(
SELECT SUM(total) total_revenue_for_USA FROM invoice
WHERE billing_country = 'USA'
),
genre_sales as
(
SELECT  g.genre_id, g.name, sum(t.unit_price * il.quantity) total_revenue_for_genre FROM track t
LEFT JOIN genre g on g.genre_id = t.genre_id
LEFT JOIN invoice_line il on il.track_id = t.track_id
LEFT JOIN invoice i on i.invoice_id = il.invoice_id
WHERE billing_country = 'USA'
GROUP BY 1,2 
ORDER BY total_revenue_for_genre DESC
),
ranking as
(
SELECT genre_id, name, ROUND(total_revenue_for_genre/(SELECT total_revenue_for_USA FROM cte) * 100,2) percentage_contribution,
DENSE_RANK() OVER(ORDER BY ROUND(total_revenue_for_genre/(SELECT total_revenue_for_USA FROM cte) * 100,2) DESC) rk FROM genre_sales
)
SELECT ranking.genre_id, ranking.name genre_name, a.name artist_name, percentage_contribution, rk FROM ranking
LEFT JOIN track t on t.genre_id = ranking.genre_id
LEFT JOIN album al on al.album_id = t.album_id
LEFT JOIN artist a on a.artist_id = al.artist_id
GROUP BY 1,2,3,4


---------------------------------------------------------------------------------------------------------

-- Q10. Find customers who have purchased tracks from at least 3 different+ genres

SELECT name_of_customer FROM
(
SELECT CONCAT(first_name, ' ', last_name) name_of_customer, COUNT(DISTINCT g.name) FROM customer c 
LEFT JOIN invoice i on i.customer_id = c.customer_id
LEFT JOIN invoice_line il on il.invoice_id = i.invoice_id
LEFT JOIN track t on t.track_id = il.track_id
LEFT JOIN genre g on g.genre_id = t.genre_id
GROUP BY 1 HAVING COUNT(DISTINCT g.name) >= 3
ORDER BY COUNT(DISTINCT g.name) DESC
) agg_table

/* Leonie Köhler is the person who has bought tracks from 14 different genres.
*/

-------------------------------------------------------------------------------------------------------

-- Q11. Rank genres based on their sales performance in the USA

WITH cte as
(
SELECT t.genre_id, g.name,  SUM(t.unit_price * il.quantity) sale_performance FROM track t
LEFT JOIN genre g on g.genre_id = t.genre_id
LEFT JOIN invoice_line il on il.track_id = t.track_id
LEFT JOIN invoice i on i.invoice_id = il.invoice_id
WHERE billing_country = 'USA'
GROUP BY 1, 2
)
SELECT name, sale_performance,
DENSE_RANK() OVER(ORDER BY sale_performance DESC) `rank` FROM cte
;

------------------------------------------------------------------------------------------------------

-- Q12. Identify customers who have not made a purchase in the last 3 months

WITH last_3_months AS
(
    SELECT * 
    FROM invoice
    WHERE invoice_date > CURDATE() - INTERVAL 3 MONTH
)
SELECT 
    CONCAT(c.first_name, ' ', c.last_name) AS name_of_customer,
    c.email,
    c.phone,
    COUNT(i.invoice_id) AS total_purchases
FROM customer c
LEFT JOIN last_3_months lm ON lm.customer_id = c.customer_id
LEFT JOIN invoice i ON i.customer_id = c.customer_id
WHERE lm.invoice_id IS NULL
GROUP BY c.customer_id
ORDER BY total_purchases DESC;




_________________________________________________________________________________________________________________________
_________________________________________________________________________________________________________________________

-- SUBJECTIVE QUESTIONS

-- Q1. Recommend the three albums from the new record label that should be prioritised 
-- for advertising and promotion in the USA based on genre sales analysis.

WITH TopGenreSalesInUsa AS (
	SELECT 
		g.genre_id,
        g.name as genre_name,
        SUM(il.unit_price * il.quantity) as total_sales,
        RANK() OVER(ORDER BY SUM(il.unit_price * il.quantity) DESC) as genre_rank
	FROM
		genre g 
	JOIN
		track t on t.genre_id = g.genre_id
	JOIN
		invoice_line il ON il.track_id = t.track_id
	JOIN
		invoice i ON i.invoice_id = il.invoice_id
	WHERE
		i.billing_country = 'USA'
	GROUP BY
		g.genre_id, g.name
	ORDER BY
		total_sales DESC
)
SELECT 
	al.title as album_name,
    a.name as artist_name,
    g.name as genre_name,
    SUM(il.unit_price * il.quantity) as total_sales
FROM
	album al 
JOIN
	track t ON al.album_id = t.album_id
JOIN
	invoice_line il ON il.track_id = t.track_id
JOIN
	genre g ON t.genre_id = g.genre_id
JOIN
	artist a ON al.artist_id = a.artist_id
WHERE
	t.genre_id IN (SELECT genre_id FROM TopGenreSalesInUsa WHERE genre_rank < 3)
GROUP BY
	al.title, g.name, a.name
ORDER BY
	total_sales DESC
limit 3;

------------------------------------------------------------------------------------------------------

-- Q2. Determine the top-selling genres in countries 
-- other than the USA and identify any commonalities or differences.

SELECT  
    g.genre_id, 
    g.name, 
    SUM(t.unit_price * il.quantity) AS total_revenue_for_genre,
    SUM(il.quantity) AS total_tracks_sold,
    COUNT(DISTINCT i.invoice_id) AS total_invoices
FROM 
    track t
LEFT JOIN 
    genre g ON g.genre_id = t.genre_id
LEFT JOIN 
    invoice_line il ON il.track_id = t.track_id
LEFT JOIN 
    invoice i ON i.invoice_id = il.invoice_id
WHERE 
    billing_country != 'USA'
GROUP BY 
    g.genre_id, g.name
ORDER BY 
    total_revenue_for_genre DESC;


------------------------------------------------------------------------------------------------------

-- Q3. Customer Purchasing Behavior Analysis: 
-- How do the purchasing habits (frequency, basket size, spending amount) of long-term customers differ 
-- from those of new customers? What insights can these patterns provide about customer loyalty and 
-- retention strategies?
 
 WITH cte as
(
SELECT i.customer_id, 
	MAX(invoice_date), MIN(invoice_date), 
	abs(TIMESTAMPDIFF(MONTH, MAX(invoice_date), 
	MIN(invoice_date))) time_for_each_customer, 
	SUM(total) sales, SUM(quantity) items, 
	COUNT(invoice_date) frequency FROM invoice i
LEFT JOIN customer c on c.customer_id = i.customer_id
LEFT JOIN invoice_line il on il.invoice_id = i.invoice_id
GROUP BY 1
ORDER BY time_for_each_customer DESC
),
average_time as
(
SELECT AVG(time_for_each_customer) average FROM cte
),-- 1244.3220 Days OR 40.36 Months
categorization as
(
SELECT *,
CASE
WHEN time_for_each_customer > (SELECT average from average_time) THEN "Long-term Customer" ELSE "Short-term Customer" 
END category
FROM cte
)
SELECT category, SUM(sales) total_spending, SUM(items) basket_size, COUNT(frequency) frequency FROM categorization
GROUP BY 1 

 -----------------------------------------------------------------------------------------------------
 
 -- Q4. Product Affinity Analysis: Which music genres, artists, or albums are frequently purchased 
 -- together by customers? How can this information guide product recommendations and 
 -- cross-selling initiatives?

WITH cte as
(
SELECT invoice_id, COUNT(DISTINCT g.name) num FROM invoice_line il
left JOIN track t on t.track_id = il.track_id
left JOIN genre g on  g.genre_id = t.genre_id
GROUP BY 1 HAVING COUNT(DISTINCT g.name) > 1)

SELECT cte.invoice_id, num, g.name FROM cte
left join invoice_line il on il.invoice_id = cte.invoice_id
left JOIN track t on t.track_id = il.track_id
left JOIN genre g on  g.genre_id = t.genre_id
GROUP BY 1,2,3;

WITH cte as
(SELECT invoice_id, COUNT(DISTINCT al.title) num FROM invoice_line il
left JOIN track t on t.track_id = il.track_id
left JOIN album al on al.album_id = t.album_id
GROUP BY 1 HAVING COUNT(DISTINCT al.title) > 1)

SELECT cte.invoice_id, num, al.title FROM cte
left join invoice_line il on il.invoice_id = cte.invoice_id
left JOIN track t on t.track_id = il.track_id
left JOIN album al on  al.album_id = t.album_id
GROUP BY 1,2,3;

WITH cte as
(SELECT invoice_id, COUNT(DISTINCT a.name) num FROM invoice_line il
left JOIN track t on t.track_id = il.track_id
left JOIN album al on al.album_id = t.album_id
left join artist a on a.artist_id = al.artist_id
GROUP BY 1 HAVING COUNT(DISTINCT a.name) > 1)

SELECT cte.invoice_id, num, a.name FROM cte
left join invoice_line il on il.invoice_id = cte.invoice_id
left JOIN track t on t.track_id = il.track_id
left JOIN album al on  al.album_id = t.album_id
left join artist a on a.artist_id = al.artist_id
GROUP BY 1,2,3;

------------------------------------------------------------------------------------------------------

-- Q5. Regional Market Analysis: Do customer purchasing behaviors and churn rates vary across 
-- different geographic regions or store locations? How might these correlate with local demographic or 
-- economic factors?

WITH num_cust_in_1st_3months as
(
SELECT billing_country, COUNT(customer_id) ttl from invoice
WHERE invoice_date BETWEEN '2017-01-01' AND '2017-03-31'
GROUP BY 1
),
num_cust_in_last_2months as
(
SELECT billing_country, COUNT(customer_id) l_num FROM invoice
WHERE invoice_date BETWEEN '2020-11-01' AND '2020-12-31' 
GROUP BY 1
)
SELECT n1.billing_country, (ttl - COALESCE(l_num,0))/ttl * 100 churn_rate FROM num_cust_in_1st_3months n1
LEFT JOIN  num_cust_in_last_2months n2 on n1.billing_country = n2.billing_country
;

WITH num_cust_in_1st_3months as
(
SELECT billing_city, COUNT(customer_id) ttl from invoice
WHERE invoice_date BETWEEN '2017-01-01' AND '2017-03-31'
GROUP BY 1
),
num_cust_in_last_2months as
(
SELECT billing_city, COUNT(customer_id) l_num FROM invoice
WHERE invoice_date BETWEEN '2020-11-01' AND '2020-12-31' 
GROUP BY 1
)
SELECT n1.billing_city, (ttl - COALESCE(l_num,0))/ttl * 100 churn_rate FROM num_cust_in_1st_3months n1
LEFT JOIN  num_cust_in_last_2months n2 on n1.billing_city = n2.billing_city
;

WITH num_cust_in_1st_3months as
(
SELECT billing_state, COUNT(customer_id) ttl from invoice
WHERE invoice_date BETWEEN '2017-01-01' AND '2017-03-31'
GROUP BY 1
),
num_cust_in_last_2months as
(
SELECT billing_state, COUNT(customer_id) l_num FROM invoice
WHERE invoice_date BETWEEN '2020-11-01' AND '2020-12-31' 
GROUP BY 1
)
SELECT n1.billing_state, (ttl - COALESCE(l_num,0))/ttl * 100 churn_rate FROM num_cust_in_1st_3months n1
LEFT JOIN  num_cust_in_last_2months n2 on n1.billing_state = n2.billing_state
;


SELECT billing_country, COUNT(invoice_id) num_invoices, AVG(total) avg_sales FROM invoice
GROUP BY 1
ORDER BY COUNT(invoice_id) DESC, AVG(total) DESC
 
-----------------------------------------------------------------------------------------------------

-- Q6. Customer Risk Profiling: Based on customer profiles (age, gender, location, purchase history), 
-- which customer segments are more likely to churn or pose a higher risk of reduced spending? 
-- What factors contribute to this risk?

SELECT i.customer_id, 
CONCAT(first_name, " ", last_name) name, 
billing_country, invoice_date, 
SUM(total) total_spending, 
COUNT(invoice_id) num_of_orders FROM invoice i
LEFT JOIN customer c on c.customer_id = i.customer_id
GROUP BY 1,2,3,4
ORDER BY name

--------------------------------------------------------------------------------------------------------

-- Q7. Customer Lifetime Value Modeling: How can you leverage customer data (tenure, purchase history, 
-- engagement) to predict the lifetime value of different customer segments? 
-- This could inform targeted marketing and loyalty program strategies. 
-- Can you observe any common characteristics or purchase patterns among customers who have stopped 
-- purchasing?

WITH CustomerTenure AS (
    SELECT 
        c.customer_id, CONCAT(c.first_name,' ', c.last_name) AS customer,
        MIN(i.invoice_date) AS first_purchase_date,
        MAX(i.invoice_date) AS last_purchase_date,
        DATEDIFF(MAX(i.invoice_date), MIN(i.invoice_date)) AS tenure_days,
        COUNT(i.invoice_id) AS purchase_frequency,
        SUM(i.total) AS total_spent
    FROM customer c
    JOIN invoice i ON c.customer_id = i.customer_id
    GROUP BY c.customer_id
)

SELECT 
    customer_id,
    customer,
    tenure_days,
    purchase_frequency,
    total_spent,
    ROUND(total_spent / purchase_frequency, 2) AS avg_order_value,
    DATEDIFF(CURRENT_DATE, last_purchase_date) AS days_since_last_purchase
FROM CustomerTenure
ORDER BY days_since_last_purchase DESC;      

--------------------------------------------------------------------------------------------------------
-- Q8. If data on promotional campaigns (discounts, events, email marketing) is available, 
-- how could you measure their impact on customer acquisition, retention, and overall sales?
-- -- Answered in Word File
------------------------------------------------------------------------------------------------------------
-- Q9. How would you approach this problem, if the objective and subjective questions weren't given?
-- -- Answered in Word File
-- --------------------------------------------------------------------------------------------------------
-- 10. How can you alter the "Albums" table to add a new column named "ReleaseYear" of type INTEGER to store
 -- the release year of each album?

ALTER TABLE album 
ADD COLUMN ReleaseYear INT(4);

SELECT * FROM album;

-- ------------------------------------------------------------------------------------------------------------------------------------------

-- 11. Chinook is interested in understanding the purchasing behavior of customers based on their geographical location. 
-- They want to know the average total amount spent by customers from each country, along with the number of customers and 
-- the average number of tracks purchased per customer. Write a SQL query to provide this information. 

SELECT 
    c.country,
    ROUND(AVG(track_count)) AS average_tracks_per_customer,
    SUM(i.total) AS total_spent,
    COUNT(DISTINCT c.customer_id) AS no_of_customers,
    ROUND(SUM(i.total)/ COUNT(DISTINCT c.customer_id),2) AS avg_total_spent
    
FROM customer c
JOIN invoice i ON c.customer_id = i.customer_id
JOIN (
        SELECT 
            invoice_id, 
            COUNT(track_id) AS track_count
        FROM invoice_line
        GROUP BY invoice_id
) il ON i.invoice_id = il.invoice_id
GROUP BY c.country
ORDER BY avg_total_spent DESC;

--------------------------------------------------------------------------------------------------------------------------------------------



