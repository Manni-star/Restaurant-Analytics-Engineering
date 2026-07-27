
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

