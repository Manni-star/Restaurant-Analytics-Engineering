
------------------------
-- POPULATING TABLES
------------------------
USE restaurant_operations_analytics;

---------------------------------
-- STEP 1 — CREATE STAGING TABLES
---------------------------------

CREATE TABLE stg_customers AS
SELECT *
FROM customers
WHERE 1 = 0;

SHOW CREATE TABLE stg_customers;

CREATE TABLE stg_address AS
SELECT *
FROM address
WHERE 1 = 0;

CREATE TABLE stg_items AS
SELECT *
FROM items
WHERE 1 = 0;

CREATE TABLE stg_inventory AS
SELECT *
FROM inventory
WHERE 1 = 0;

CREATE TABLE stg_shift AS
SELECT *
FROM shift
WHERE 1 = 0;

CREATE TABLE stg_staff AS
SELECT *
FROM staff
WHERE 1 = 0;

CREATE TABLE stg_suppliers AS
SELECT *
FROM suppliers
WHERE 1 = 0;

CREATE TABLE stg_ingredients AS
SELECT *
FROM ingredients
WHERE 1 = 0;

CREATE TABLE stg_recipe AS
SELECT *
FROM recipe
WHERE 1 = 0;

CREATE TABLE stg_rota AS
SELECT *
FROM rota
WHERE 1 = 0;

CREATE TABLE stg_ingredients_supplier AS
SELECT *
FROM ingredients_supplier
WHERE 1 = 0;

CREATE TABLE stg_inventory_transactions AS
SELECT *
FROM inventory_transactions
WHERE 1 = 0;

CREATE TABLE stg_inventory_daily_snapshot AS
SELECT *
FROM inventory_daily_snapshot
WHERE 1 = 0;

CREATE TABLE stg_orders AS
SELECT *
FROM orders
WHERE 1 = 0;


---------------------------------
-- STEP 2 — LOAD CSV INTO STAGING
---------------------------------

SET FOREIGN_KEY_CHECKS = 0; 
SET GLOBAL local_infile = 1;    -- Enable LOCAL INFILE (client side)

-- Log Table:
CREATE TABLE IF NOT EXISTS pipeline_logs (
    log_id INT AUTO_INCREMENT PRIMARY KEY,
    table_name VARCHAR(50),
    rows_inserted INT,
    log_message VARCHAR(100),
    execution_time TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);


-- Stored Proceedure for INSERTS logging
DELIMITER $$
CREATE PROCEDURE logging(IN source_table_var VARCHAR(50), IN message_var VARCHAR(100))
BEGIN
    -- 1. Create a quick variable to trap the actual row count instantly
    DECLARE total_rows INT;
    SET total_rows = ROW_COUNT();   -- ROW_COUNT() is internal tracking of Changes (Concurrent changes)

    -- 2. Insert into logs using your inputs and variables
    INSERT INTO pipeline_logs (table_name, rows_inserted, log_message)
    VALUES (source_table_var, total_rows, message_var); -- No quotes around source_table_var!
END $$
DELIMITER ;

-- CUSTOMERS TABLE:

START TRANSACTION;
TRUNCATE stg_customers;

LOAD DATA LOCAL INFILE '/Users/mymac/Desktop/1. Restaurant Proj/6. Customers.csv'
INTO TABLE stg_customers
FIELDS TERMINATED BY ','
ENCLOSED BY '"' -- Adds protection for text fields with commas
IGNORE 1 ROWS;

CALL logging('stg_customers', '-- Customers successfully loaded');

COMMIT;


-- address

START TRANSACTION;
TRUNCATE stg_address;

LOAD DATA LOCAL INFILE '/Users/mymac/Desktop/1. Restaurant Proj/7. Address.csv'
INTO TABLE stg_address
FIELDS TERMINATED BY ','
ENCLOSED BY '"'
IGNORE 1 ROWS;

CALL logging('stg_address', '-- Address successfully loaded');

COMMIT;


-- items 

START TRANSACTION;
TRUNCATE stg_items;

LOAD DATA LOCAL INFILE '/Users/mymac/Desktop/1. Restaurant Proj/2. ITEMS.csv'
INTO TABLE stg_items
FIELDS TERMINATED BY ','
ENCLOSED BY '"'
IGNORE 1 ROWS;

CALL logging('stg_items', '-- Items successfully loaded');

COMMIT;


-- inventory  

START TRANSACTION;

LOAD DATA LOCAL INFILE '/Users/mymac/Desktop/1. Restaurant Proj/5-1. Inventory.csv'
INTO TABLE stg_inventory
FIELDS TERMINATED BY ','
ENCLOSED BY '"'
IGNORE 1 ROWS;

CALL logging('stg_inventory','-- Inventory successfully loaded');

COMMIT;


-- shift 

SELECT * FROM stg_shift;

START TRANSACTION;

LOAD DATA LOCAL INFILE '/Users/mymac/Desktop/1. Restaurant Proj/8. shift_table.csv'
INTO TABLE stg_shift
FIELDS TERMINATED BY ','
ENCLOSED BY '"'
LINES TERMINATED BY '\r\n' -- <-- This removes the hidden '\r' character  (causing error).
IGNORE 1 ROWS;

CALL logging('stg_shift','-- Shift successfully loaded');

COMMIT;


-- staff

START TRANSACTION;

LOAD DATA LOCAL INFILE '/Users/mymac/Desktop/1. Restaurant Proj/9. staff_table.csv'
INTO TABLE stg_staff
FIELDS TERMINATED BY ','
ENCLOSED BY '"'
LINES TERMINATED BY '\r\n'
IGNORE 1 ROWS;

CALL logging('stg_staff','-- Staff successfully loaded');

COMMIT;


-- suppliers

LOAD DATA LOCAL INFILE '/Users/mymac/Desktop/1. Restaurant Proj/11. suppliers.csv'
INTO TABLE stg_suppliers
FIELDS TERMINATED BY ','
ENCLOSED BY '"'
LINES TERMINATED BY '\r\n'
IGNORE 1 ROWS;

CALL logging('stg_suppliers','-- Suppliers successfully loaded');

COMMIT;


-- ingredients

LOAD DATA LOCAL INFILE '/Users/mymac/Desktop/1. Restaurant Proj/3. Ingredients.csv'
INTO TABLE stg_ingredients
FIELDS TERMINATED BY ','
ENCLOSED BY '"'
LINES TERMINATED BY '\r\n'
IGNORE 1 ROWS;

CALL logging('stg_ingredients','-- Ingredients successfully loaded');

COMMIT;

-- recipe

START TRANSACTION;
TRUNCATE stg_recipe;

LOAD DATA LOCAL INFILE '/Users/mymac/Desktop/1. Restaurant Proj/4-2 Recepie.csv'
INTO TABLE stg_recipe
FIELDS TERMINATED BY ','
ENCLOSED BY '"'
LINES TERMINATED BY '\n' -- <-- Remove '\r' character (causing error) from \r\n.
IGNORE 1 ROWS;

CALL logging('stg_recipe','-- Recipe successfully loaded');

COMMIT;


-- rota

START TRANSACTION;
TRUNCATE stg_rota;

LOAD DATA LOCAL INFILE '/Users/mymac/Desktop/1. Restaurant Proj/10. rota_table.csv'
INTO TABLE stg_rota
FIELDS TERMINATED BY ','
ENCLOSED BY '"'
LINES TERMINATED BY '\r\n'
IGNORE 1 ROWS;

CALL logging('stg_rota','-- Rota successfully loaded');

COMMIT;


-- ingredients_supplier

START TRANSACTION;

LOAD DATA LOCAL INFILE '/Users/mymac/Desktop/1. Restaurant Proj/12. Ingredients_supplier.csv'
INTO TABLE stg_ingredients_supplier
FIELDS TERMINATED BY ','
ENCLOSED BY '"'
LINES TERMINATED BY '\r\n'
IGNORE 1 ROWS;

CALL logging('stg_ingredients_supplier', '-- Ingredients_supplier successfully loaded');

COMMIT;


-- inventory_transactions

START TRANSACTION;

LOAD DATA LOCAL INFILE '/Users/mymac/Desktop/1. Restaurant Proj/13. inventory_transactions.csv'
INTO TABLE stg_inventory_transactions
FIELDS TERMINATED BY ','
ENCLOSED BY '"'
LINES TERMINATED BY '\n' -- <-- Remove '\r' character (causing error) from \r\n.
IGNORE 1 ROWS;

CALL logging('stg_inventory_transactions', '-- Inventory_transactions successfully loaded');

COMMIT;


-- inventory_daily_snapshot

START TRANSACTION;

LOAD DATA LOCAL INFILE '/Users/mymac/Desktop/1. Restaurant Proj/14-1. inventory_daily_snapshot copy.csv'
INTO TABLE stg_inventory_daily_snapshot
FIELDS TERMINATED BY ','
ENCLOSED BY '"'
LINES TERMINATED BY '\n'
IGNORE 1 ROWS;

CALL logging('stg_inventory_daily_snapshot','-- Inventory_daily_snapshot successfully loaded');

COMMIT;


-- orders

START TRANSACTION;

LOAD DATA LOCAL INFILE '/Users/mymac/Desktop/1. Restaurant Proj/transactions_updated.csv'
INTO TABLE stg_orders
FIELDS TERMINATED BY ','
ENCLOSED BY '"'
LINES TERMINATED BY '\n'
IGNORE 1 ROWS;

CALL logging('stg_orders', '-- Orders successfully loaded');

COMMIT;


---------------------------------
-- STEP 3 — VALIDATE STAGING DATA
---------------------------------

-- A. Row Count Check:

SELECT COUNT(*) FROM stg_orders;


-- B. Duplicate Grain Check:

SELECT * FROM stg_orders LIMIT 10;

SELECT
    order_id,
    item_id,
    COUNT(*)
FROM stg_orders
GROUP BY
    order_id,
    item_id
HAVING COUNT(*) > 1;


-- C. NULL Checks:

SELECT *
FROM stg_orders
WHERE order_id IS NULL;


SELECT *
FROM stg_orders
WHERE STR_TO_DATE(created_at, '%Y-%m-%d %H:%i:%s') IS NULL;  -- catched mismatched values == Null !


SELECT s.*
FROM stg_orders s
LEFT JOIN stg_customers c
    ON s.cust_id = c.cust_id
WHERE c.cust_id IS NULL;



-------------------------------------------------------------------------------------------
-- STEP 5 — Implement staging-to-production data migration transactions with audit logging
-------------------------------------------------------------------------------------------
SELECT * FROM pipeline_logs;

-- CUSTOMERS TABLE:

START TRANSACTION;

INSERT INTO customers (
	cust_id,
	cust_firstname,		
	cust_lastname
)
SELECT 
	cust_id,
	cust_firstname,		
	cust_lastname			
FROM stg_customers;

CALL logging('customers','stg_customers TO customers');

COMMIT;



-- address

START TRANSACTION;

INSERT INTO address (
	add_id,	
	delivery_address,		
	delivery_city,		
	delivery_zipcode
)
SELECT 
	add_id,	
	delivery_address,		
	delivery_city,		
	delivery_zipcode
FROM stg_address;

CALL logging('address','stg_address TO address');

COMMIT;


-- items 

START TRANSACTION;

INSERT INTO items(
	item_id,
	sku,
	item_name,		
	item_cat,		
	item_size
)
SELECT
	item_id,
	sku,
	item_name,		
	item_cat,		
	item_size		
FROM stg_items;

CALL logging('items','stg_items TO items');

COMMIT;


-- inventory  

START TRANSACTION;

INSERT INTO inventory
SELECT *
FROM stg_inventory;

CALL logging('inventory','stg_inventory TO inventory');

COMMIT;


-- shift 

START TRANSACTION;

INSERT INTO shift
SELECT *
FROM stg_shift;

CALL logging('shift','stg_shift TO shift');

COMMIT;


-- staff

START TRANSACTION;

INSERT INTO staff
SELECT *
FROM stg_staff;

CALL logging('staff','stg_staff TO staff');

COMMIT;


-- suppliers

START TRANSACTION;

INSERT INTO suppliers
SELECT *
FROM stg_suppliers;

CALL logging('suppliers','stg_suppliers TO suppliers');

COMMIT;



-- ingredients

START TRANSACTION;

INSERT INTO ingredients
SELECT *
FROM stg_ingredients;

CALL logging('ingredients','stg_ingredients TO ingredients');

COMMIT;

-- recipe

START TRANSACTION;

INSERT INTO recipe
SELECT *
FROM stg_recipe;

CALL logging('recipe','stg_recipe TO recipe');

COMMIT;

-- rota

START TRANSACTION;

INSERT INTO rota
SELECT *
FROM stg_rota;

CALL logging('rota','stg_rota TO rota');

COMMIT;

-- ingredients_supplier

START TRANSACTION;

INSERT INTO ingredients_supplier
SELECT *
FROM stg_ingredients_supplier;

CALL logging('ingredients_supplier','stg_ingredients_supplier TO ingredients_supplier');

COMMIT;

-- inventory_transactions

START TRANSACTION;

INSERT INTO inventory_transactions
SELECT *
FROM stg_inventory_transactions;

CALL logging('inventory_transactions','stg_inventory_transactions TO inventory_transactions');

COMMIT;


-- inventory_daily_snapshot 

START TRANSACTION;

INSERT INTO inventory_daily_snapshot
SELECT *
FROM stg_inventory_daily_snapshot;

CALL logging('inventory_daily_snapshot','stg_inventory_daily_snapshot TO inventory_daily_snapshot');

COMMIT;


-- orders

START TRANSACTION;

INSERT INTO orders
SELECT *
FROM stg_orders;

CALL logging('orders','stg_orders TO orders');

COMMIT;


-------------------------------------------
-- STEP 6 — DROP STAGING TABLES 
-------------------------------------------


SHOW TABLES LIKE 'stg_%';


DROP TABLES IF EXISTS stg_customers;
DROP TABLES IF EXISTS stg_address;
DROP TABLES IF EXISTS stg_items;
DROP TABLES IF EXISTS stg_inventory;
DROP TABLES IF EXISTS stg_shift;
DROP TABLES IF EXISTS stg_staff;
DROP TABLES IF EXISTS stg_suppliers;
DROP TABLES IF EXISTS stg_ingredients;
DROP TABLES IF EXISTS stg_recipe;
DROP TABLES IF EXISTS stg_rota;
DROP TABLES IF EXISTS stg_ingredients_supplier;
DROP TABLES IF EXISTS stg_inventory_transactions;
DROP TABLES IF EXISTS stg_inventory_daily_snapshot;
DROP TABLES IF EXISTS stg_orders;



SET FOREIGN_KEY_CHECKS = 1; 
SET GLOBAL local_infile = 0; 


SELECT 
    TABLE_NAME AS 'Table Name', 
    TABLE_ROWS AS 'Row Count'
FROM INFORMATION_SCHEMA.TABLES
WHERE TABLE_SCHEMA = 'restaurant_operations_analytics'
ORDER BY TABLE_ROWS DESC;


