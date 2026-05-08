--Checking the datatypes for time-related columns prior to analysis
SELECT TOP 10 order_dow,
			order_hour_of_day,
			days_since_prior_order
FROM orders;

--Check the prior_order column ranges to make sure int is appropriate to change as datatype
SELECT MAX(days_since_prior_order),
		MIN(days_since_prior_order)
FROM orders;

--Change day column datatype to int since we will only need full days
ALTER TABLE orders
ALTER COLUMN days_since_prior_order int;

--Remove unnecessary column - tied to ML analysis in this dataset
ALTER TABLE orders
DROP COLUMN eval_set;

--Check important columns for null values that could affect analysis
SELECT *
FROM aisles
WHERE aisle_id IS NULL OR 
		aisle IS NULL
UNION ALL
SELECT *
FROM departments
WHERE department_id IS NULL OR 
	department IS NULL
UNION ALL
SELECT order_id,
		user_id 
FROM orders 
WHERE order_id IS NULL OR 
		user_id IS NULL
UNION ALL
SELECT product_id,
		product_name
FROM products
WHERE product_id IS NULL OR 
		product_name IS NULL
UNION ALL
SELECT order_id,
		product_id
FROM order_products_prior
WHERE order_id IS NULL OR 
		product_id IS NULL;

/*days_since_prior_order contains NULLs which represent a customer's first order. 
These have been intentionally left as NULL as COALESCE to 0 would misrepresent them as same-day repeat orders. 
Handled in views via CASE statement.*/

--Checking for duplicates in main order tables
SELECT COUNT(order_id)
FROM orders
GROUP BY order_id
HAVING COUNT(order_id)>1;

SELECT COUNT(order_id)
FROM order_products_prior
GROUP BY order_id
HAVING COUNT(order_id)>1;
