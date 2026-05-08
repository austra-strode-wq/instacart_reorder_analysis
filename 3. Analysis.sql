--Analysing which products has gotten reordered most
SELECT p.product_id,
		p.product_name,
		d.department,
		a.aisle,
		COUNT(reordered) AS flag_count
FROM products p
JOIN departments d ON p.department_id = d.department_id
JOIN aisles a ON p.aisle_id = a.aisle_id
JOIN order_products_prior opp ON p.product_id = opp.product_id
WHERE reordered = 1
GROUP BY p.product_id, p.product_name, d.department, a.aisle;

--Analyse most prevalent times of day for ordering
SELECT order_hour_of_day,
		COUNT(order_id) AS count_per_hour
FROM orders
GROUP BY order_hour_of_day
ORDER BY count_per_hour DESC;

--Analyse most prevalent days of ordering
SELECT COUNT(order_id) AS dow_orders,
		day_names
FROM v_day_names
GROUP BY day_names
ORDER BY dow_orders DESC;

--Analyse order sizes by product counts and distribution
WITH Product_Counts_CTE AS 
	(SELECT order_id,
			COUNT(product_id) AS products_per_order
	FROM order_products_prior
	GROUP BY order_id),
Aisles_Counts_CTE AS 
	(SELECT order_id,
			COUNT(DISTINCT aisle_id) AS aisle_counts
	FROM order_products_prior opp
	JOIN products p ON opp.product_id = p.product_id
	GROUP BY order_id)
SELECT pc.order_id,
		products_per_order,
		AVG(products_per_order) OVER() AS avg_product_counts,
		aisle_counts
FROM Product_Counts_CTE pc
JOIN Aisles_Counts_CTE ac ON pc.order_id = ac.order_id;

--Calculating reodering patterns by user_id; exploratory numbers first to see the best margins:
WITH Reordering_CTE AS 
	(SELECT user_id,
			COUNT(order_id) AS order_counts,
			AVG(days_since_prior_order) AS avg_reorder_days
	FROM orders
	GROUP BY user_id)
SELECT MAX(order_counts) AS max_order,
		AVG(order_counts) AS ballpark_orders,
		MAX(avg_reorder_days) AS highest_from_averages,
		AVG(avg_reorder_days) AS avg_from_averages
FROM Reordering_CTE;

--Reordering patterns flagging query:
WITH Reordering_CTE AS 
	(SELECT user_id,
			COUNT(order_id) AS order_counts,
			AVG(days_since_prior_order) AS avg_reorder_days
	FROM orders
	GROUP BY user_id)
SELECT user_id,
		order_counts,
		avg_reorder_days,
			CASE WHEN order_counts BETWEEN 1 AND 5 THEN 'Casual'
				WHEN order_counts BETWEEN 6 AND 25 THEN 'Regular'
				WHEN order_counts > 25 THEN 'Loyal'
				END AS flags_by_orders,
			CASE WHEN avg_reorder_days BETWEEN 0 AND 7 THEN 'Weekly'
				WHEN avg_reorder_days BETWEEN 8 AND 20 THEN 'Fortnightly'
				WHEN avg_reorder_days > 20 THEN 'Monthly+'
				END AS flags_by_days
FROM Reordering_CTE;

