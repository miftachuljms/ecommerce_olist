-- CREATING TABLES --
DROP TABLE IF EXISTS customers;
CREATE TABLE customers (
	customer_id VARCHAR(50) PRIMARY KEY NOT NULL,
	customer_unique_id VARCHAR(50) NOT NULL,
	customer_zip_code_prefix INT NOT NULL,
	customer_city VARCHAR(50) NOT NULL,
	customer_state VARCHAR(15) NOT NULL
);

DROP TABLE IF EXISTS geolocation;
CREATE TABLE geolocation (
	geolocation_zip_code_prefix INT NOT NULL,
	geolocation_lat NUMERIC(10,7) NOT NULL,
	geolocation_lng NUMERIC(10,7) NOT NULL,
	geolocation_city VARCHAR(50) NOT NULL,
	geolocation_state VARCHAR(50) NOT NULL
);

DROP TABLE IF EXISTS category_name;
CREATE TABLE category_name (
	product_category_name VARCHAR(50) NOT NULL,
	product_category_name_english VARCHAR(50) NOT NULL
);

DROP TABLE IF EXISTS sellers;
CREATE TABLE sellers (
	seller_id VARCHAR(50) PRIMARY KEY  NOT NULL,
	seller_zip_code_prefix INT NOT NULL,
	seller_city VARCHAR(50) NOT NULL,
	seller_state VARCHAR(15) NOT NULL
);

DROP TABLE IF EXISTS products;
CREATE TABLE products (
	product_id VARCHAR(50) PRIMARY KEY NOT NULL,
	product_category_name VARCHAR(50) NULL,
	product_name_lenght INT NULL,
	product_description_lenght INT NULL,
	product_photos_qty INT NULL,
	product_weight_g NUMERIC(10,2) NULL,
	product_length_cm NUMERIC(10,2) NULL,
	product_height_cm NUMERIC(10,2) NULL,
	product_width_cm NUMERIC(10,2) NULL
);

DROP TABLE IF EXISTS orders ;
CREATE TABLE orders (
	order_id VARCHAR(50) PRIMARY KEY NOT NULL,
	customer_id VARCHAR(50) NOT NULL,
	order_status VARCHAR(50) NOT NULL,
	order_purchase_timestamp TIMESTAMP WITHOUT TIME ZONE NOT NULL,
	order_approved_at TIMESTAMP WITHOUT TIME ZONE NULL,
	order_delivered_carrier_date TIMESTAMP WITHOUT TIME ZONE NULL,
	order_delivered_customer_date TIMESTAMP WITHOUT TIME ZONE NULL,
	order_estimated_delivery_date TIMESTAMP WITHOUT TIME ZONE NOT NULL,
	CONSTRAINT fk_order_customer FOREIGN KEY (customer_id) 
    	REFERENCES customers(customer_id) ON DELETE CASCADE
);

DROP TABLE IF EXISTS order_items;
CREATE TABLE order_items (
	order_id VARCHAR(50) NOT NULL,
	order_item_id VARCHAR(15) NOT NULL,
	product_id VARCHAR(50) NOT NULL,
	seller_id VARCHAR(50) NOT NULL,
	shipping_limit_date TIMESTAMP WITHOUT TIME ZONE NOT NULL,
	price VARCHAR(50) NOT NULL,
	freight_value NUMERIC(10,7) NOT NULL,
	CONSTRAINT fk_order_item_order FOREIGN KEY (order_id) 
		REFERENCES orders(order_id) ON DELETE CASCADE,
    CONSTRAINT fk_order_item_seller FOREIGN KEY (seller_id) 
    	REFERENCES sellers(seller_id) ON DELETE CASCADE,
    CONSTRAINT fk_order_item_product FOREIGN KEY (product_id) 
    	REFERENCES products(product_id) ON DELETE CASCADE
);

DROP TABLE IF EXISTS order_reviews;
CREATE TABLE order_reviews (
	review_id VARCHAR(500),
	order_id VARCHAR(50),
	review_score INT,
	review_comment_title VARCHAR(500),
	review_comment_message VARCHAR(500),
	review_creation_date TIMESTAMP WITHOUT TIME ZONE,
	review_answer_timestamp TIMESTAMP WITHOUT TIME ZONE,
	CONSTRAINT fk_review_order FOREIGN KEY (order_id) 
    	REFERENCES orders(order_id) ON DELETE CASCADE
);

DROP TABLE IF EXISTS order_payments;
CREATE TABLE order_payments (
	order_id VARCHAR(50),
	payment_sequential INT,
	payment_type VARCHAR(50),
	payment_installments INT,
	payment_value NUMERIC(10,2),
	CONSTRAINT fk_payment_order FOREIGN KEY (order_id) 
    	REFERENCES orders(order_id) ON DELETE CASCADE
);


-- CHANGE PRODUCT CATEGORY NAME TO ENGLISH
UPDATE products
SET product_category_name = product_category_name_english
FROM category_name
WHERE products.product_category_name = category_name.product_category_name;



-- EXPLORATORY DATA ANALYSIS
-- 1. Sales Analysis
-- 1.1 Total Revenue
SELECT
	SUM(price::numeric) total_revenue
FROM order_items;

-- 1.2 Total Orders
SELECT 
	COUNT(order_id) total_orders 
FROM orders;



-- 1.3 Cities with the Highest Total Sales
WITH city_sales AS (
    SELECT 
        c.customer_city,
        ROUND(SUM(oi.price::numeric + oi.freight_value),2) total_sales
    FROM order_items oi
    JOIN orders o USING(order_id)
    JOIN customers c USING(customer_id)
    GROUP BY 1
)
SELECT 
    INITCAP(customer_city) cust_city, 
    total_sales,
    RANK() OVER (ORDER BY total_sales DESC) ranking
FROM city_sales
LIMIT 10;


-- 1.4 Products with the Most Transactions
SELECT
	p.product_category_name,
	COUNT(oi.order_id) total_orders
FROM order_items oi
JOIN products p USING (product_id)
GROUP BY 1
ORDER BY 2 DESC
LIMIT 10;


-- 1.5 Average Order Value
SELECT 
    ROUND(SUM(price::numeric + freight_value) / COUNT(DISTINCT order_id), 2) aov
FROM order_items


-- 2. Customer Analysis
-- 2.1 Unique Customers
SELECT 
	COUNT(DISTINCT customer_id) total_customers 
FROM customers;


-- 2.2 Cities with the Most Customers
SELECT
	INITCAP(customer_city) cust_city,
	COUNT (DISTINCT customer_id) total_customers
FROM customers
GROUP BY 1
ORDER BY 2 DESC
LIMIT 10;


-- 2.3 Customer Segmentation Based on Order Value
WITH customer_spending AS (
    SELECT 
        o.customer_id, 
        ROUND(SUM(oi.price::numeric + oi.freight_value),2) order_value
    FROM orders o
    JOIN order_items oi USING(order_id)
    GROUP BY 1
),
customer_segmentation AS (
SELECT 
    customer_id,
    order_value,
    CASE 
        WHEN order_value >= 2999 THEN 'High Value'
        WHEN order_value BETWEEN 1000 AND 2999 THEN 'Medium Value'
        ELSE 'Low Value'
    END AS cust_segment
FROM customer_spending
)
SELECT
	cust_segment,
	COUNT(cust_segment) total_cust_segment
FROM customer_segmentation
GROUP BY 1
ORDER BY 2 DESC;


-- 3. Logistics & Delivery Analysis
-- 3.1 Delivery & Cancellation Rate
SELECT 
    (SELECT ROUND(COUNT(*) * 100.0 / (SELECT COUNT(*) FROM orders), 2) FROM orders WHERE order_status = 'delivered') delivery_rate,
    (SELECT ROUND(COUNT(*) * 100.0 / (SELECT COUNT(*) FROM orders), 2) FROM orders WHERE order_status = 'canceled') cancellation_rate;


-- 3.2 Average Delivery Time per Product Category
SELECT
	p.product_category_name,
	CEIL(AVG(EXTRACT(DAY FROM o.order_delivered_customer_date - o.order_purchase_timestamp))) avg_delivery_days
FROM orders o
JOIN order_items oi USING(order_id)
JOIN products p USING(product_id)
GROUP BY 1
ORDER BY 2 DESC
LIMIT 10;


-- 3.3 Cities with Longest & Fastest Delivery Times
WITH delivery_days AS (
    SELECT 
        c.customer_city,
        CEIL(AVG(EXTRACT(DAY FROM o.order_delivered_customer_date - o.order_purchase_timestamp))) avg_delivery_days
    FROM orders o
    JOIN customers c USING(customer_id)
    GROUP BY 1
)
SELECT 
	(SELECT INITCAP(customer_city) cust_city FROM delivery_days ORDER BY avg_delivery_days DESC LIMIT 1) city_with_max_days,
    (SELECT MAX(avg_delivery_days) FROM delivery_days) max_avg_delivery_days,
    (SELECT INITCAP(customer_city) cust_city FROM delivery_days ORDER BY avg_delivery_days ASC LIMIT 1) city_with_min_days,
    (SELECT MIN(avg_delivery_days) FROM delivery_days) min_avg_delivery_days;


-- 4. Payment Analysis
-- 4.1 Most Frequently Used Payment Methods
SELECT
	payment_type,
	COUNT(order_id) total_transacions
FROM order_payments
GROUP BY 1
ORDER BY 2 DESC;


-- 4.2 Average Number of Installments per Transaction
SELECT
	CEIL(AVG(payment_installments)) avg_installments
FROM order_payments;


-- 4.3 Relationship between Payment Method and Number of Transactions
WITH payment_method AS (
    SELECT 
        payment_type,
        COUNT(order_id) total_transactions,
        SUM(payment_value) total_revenue
    FROM order_payments
    GROUP BY 1
)
SELECT 
    payment_type,
    total_transactions,
    total_revenue,
    ROUND(total_revenue / total_transactions, 2) avg_transaction_value
FROM payment_method
ORDER BY 3 DESC;


-- 5. RFM (Recency, Frequency, Monetary) Analysis
-- 5.1 RFM
WITH rfm AS (
    SELECT 
        o.customer_id,
        MAX(o.order_purchase_timestamp) last_order_date,
        COUNT(o.order_id) frequency,
        SUM(oi.price::numeric + oi.freight_value)S monetary_value,
        EXTRACT(DAY FROM (SELECT MAX(order_purchase_timestamp) FROM orders) - MAX(o.order_purchase_timestamp)) recency
    FROM orders o
    JOIN order_items oi USING(order_id)
    GROUP BY 1
)
SELECT 
	CEIL(AVG(recency)),
	COUNT(DISTINCT frequency) n_frequency, 
	CEIL(SUM(monetary_value)) total_monetary
FROM rfm;

	
-- 5.2 RFM Customer Segmentation
WITH rfm AS (
    SELECT 
        o.customer_id,
        MAX(o.order_purchase_timestamp) last_order_date,
        COUNT(o.order_id) frequency,
        SUM(oi.price::numeric + oi.freight_value) monetary_value,
        EXTRACT(DAY FROM (SELECT MAX(order_purchase_timestamp) FROM orders) - MAX(o.order_purchase_timestamp)) recency
    FROM orders o
    JOIN order_items oi USING(order_id)
    GROUP BY 1
),
rfm_segment AS (
	SELECT 
	    customer_id,
	    recency,
	    frequency,
	    monetary_value,
	    CASE 
	        WHEN recency <= 30 THEN 'Recent'
	        WHEN recency BETWEEN 31 AND 90 THEN 'Active'
	        ELSE 'Dormant'
	    END AS recency_segment
	FROM rfm
	ORDER BY 4 DESC
)
SELECT
	recency_segment,
	COUNT(recency_segment)
FROM rfm_segment
GROUP BY 1
ORDER BY 2 DESC;