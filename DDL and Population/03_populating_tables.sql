
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