
-- 1. Confirm all tables exist (IMP)

SHOW TABLES;


-- 2. Verify each table schema

SHOW CREATE TABLE items;
SHOW CREATE TABLE recipe;
SHOW CREATE TABLE orders;
SHOW CREATE TABLE inventory;

-- 3. Verify foreign keys Creation (V.IMP)

SELECT
    table_name,
    column_name,
    constraint_name,
    referenced_table_name,
    referenced_column_name
FROM information_schema.key_column_usage
WHERE referenced_table_schema = DATABASE();


-- 4. Verify indexes

SHOW INDEX FROM items;
SHOW INDEX FROM orders;



-- 5. Validate schema logic WITHOUT data

SELECT *
FROM orders o
JOIN items i ON o.item_id = i.item_id;


-- 6. Validate full pipeline integrity (STRUCTURE ONLY)

SELECT
    o.item_id,
    i.sku,
    r.ingredients
FROM orders o
JOIN items i ON o.item_id = i.item_id
JOIN recipe r ON i.sku = r.sku
LIMIT 1;




