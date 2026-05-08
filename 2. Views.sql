 --Creating a view for day-names for better readability
CREATE VIEW v_day_names AS 
SELECT *,
	CASE WHEN order_dow = 0 THEN 'Monday'
	WHEN order_dow = 1 THEN 'Tuesday'
	WHEN order_dow = 2 THEN 'Wednesday'
	WHEN order_dow = 3 THEN 'Thursday'
	WHEN order_dow = 4 THEN 'Friday'
	WHEN order_dow = 5 THEN 'Saturday'
	WHEN order_dow = 6 THEN 'Sunday'
	END AS day_names, 
	CASE WHEN order_dow = 0 THEN 1
		WHEN order_dow = 1 THEN 2
		WHEN order_dow = 2 THEN 3
		WHEN order_dow = 3 THEN 4
		WHEN order_dow = 4 THEN 5
		WHEN order_dow = 5 THEN 6
		WHEN order_dow = 6 THEN 7
		END AS day_sort_order
FROM orders;

--Creating a view to deal with first order NULL values for more accurate analysis
CREATE VIEW v_orders_flagged AS
	SELECT *, 
	CASE WHEN days_since_prior_order IS NULL THEN 'first_oder'
	ELSE 'repeat_order'
	END AS first_order_flag
FROM orders;

--Creating a view for top ordered aisle/product breakdown
CREATE VIEW v_aisles_and_products AS
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


--Creating a view for order size diversity by product counts
--Order size categories added for Power Bi visualisation
--Bins defined based on data distribution - avg 10, max 146
CREATE VIEW v_order_size_diversity AS
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
		aisle_counts,
		CASE WHEN products_per_order BETWEEN 1 AND 5 THEN 'Small (1-5)'
			WHEN products_per_order BETWEEN 6 AND 15 THEN 'Medium (6-15)'
			WHEN products_per_order BETWEEN 16 AND 30 THEN 'Large (16-30)'
			WHEN products_per_order BETWEEN 31 AND 50 THEN 'Extra Large (31-50)'
			WHEN products_per_order > 50 THEN 'Bulk (50+)'
			END AS order_size_category
FROM Product_Counts_CTE pc
JOIN Aisles_Counts_CTE ac ON pc.order_id = ac.order_id;

--Creating a view for reordering information (counts and reorder day data)
CREATE VIEW v_reordering_data AS 
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
