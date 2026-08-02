
-- 1. TOTAL ORDERS
SELECT COUNT(DISTINCT order_id) AS total_orders
FROM orders;


-- 2. TOTAL SALES
SELECT 
    ROUND(SUM(o.quantity * it.item_price)) AS total_sales_kpi
FROM orders o
INNER JOIN items it
ON o.item_id = it.item_id;


-- 3. TOTAL ITEM SOLD
SELECT
	SUM(quantity) AS total_items_sold
FROM orders;


-- 4. AVERAGE ORDER VALUE 
SELECT
	COUNT(DISTINCT order_id) AS total_orders,
    SUM(o.quantity * it.item_price) AS total_revenue,
    ROUND(
		(SUM(o.quantity * it.item_price) / COUNT(DISTINCT order_id))
        ,0 ) AS AOV
FROM orders o
JOIN items it
ON o.item_id = it.item_id
ORDER BY o.order_id ASC;


-- 5. SALES BY CATEGORY
SELECT
	it.item_cat AS category,
    ROUND(SUM(o.quantity * it.item_price)) AS total_sales_kpi
FROM orders o
INNER JOIN items it
ON o.item_id = it.item_id
GROUP BY
	it.item_cat;
    

-- 6. TOP SELLING ITEMS
SELECT 
	it.item_id,
    it.item_name,
    ROUND(SUM(o.quantity * it.item_price)) AS total_sales_kpi
FROM orders o
INNER JOIN items it
ON o.item_id = it.item_id
GROUP BY
	it.item_id
ORDER BY total_sales_kpi DESC
LIMIT 5;


-- 7. REGIONAL Sales Distribution (RSD)
SELECT 
	ad.latitude,
	ad.longitude,
	LEFT(TRIM(ad.delivery_zipcode), 3) AS postal_fsa,
	ad.delivery_city,
    SUM(o.quantity * it.item_price) AS total_sales

FROM address ad
INNER JOIN orders o
	ON ad.add_id = o.add_id
INNER JOIN items it
	ON o.item_id = it.item_id
GROUP BY
	ad.latitude,
	ad.longitude,
	LEFT(TRIM(ad.delivery_zipcode), 3),
	ad.delivery_city;
    
    
-- 8. REGIONAL Orders Distribution i.e. GEO-Fulfilment-Mapping (GFM):
SELECT
	ad.latitude,
	ad.longitude,
	LEFT(TRIM(ad.delivery_zipcode), 3) AS postal_fsa,
	ad.delivery_city,
    CASE
		WHEN o.delivery = 'Y' THEN 'Home Delivery'
        ELSE 'In-Store Pickup'
	END AS fulfilment_type,
	COUNT(DISTINCT o.order_id) AS total_orders
FROM orders o
INNER JOIN address ad
	ON o.add_id = ad.add_id
GROUP BY
	ad.latitude,
	ad.longitude,
	LEFT(TRIM(ad.delivery_zipcode), 3),
    ad.delivery_city,
    o.delivery;








