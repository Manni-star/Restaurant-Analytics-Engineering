
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