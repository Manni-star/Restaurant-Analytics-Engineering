
-- ==================================================================
-- 	SET-3: Operational Intelligence - Advanced Operational Analytics
-- ==================================================================


USE `restaurant_operations_analytics`;


-- ============================================
-- 		MART 1 — Inventory Operations Mart
-- ============================================



-- 1. Ingredient Consumption Flow (Cumulative Flow Analysis):

-- Business Question: “How fast are we consuming each ingredient 'day over day'?”

SELECT
	invd.snapshot_date,
	invd.ing_id,
    invd.consumed_packages,
    -- By adding YEAR() and MONTH(), the cumulative sum automatically 
    -- resets back to 0 on the 1st of every single month!
    SUM(consumed_packages) OVER (PARTITION BY ing_id, YEAR(snapshot_date), MONTH(snapshot_date)
		ORDER BY snapshot_date ASC) as cumulative_consumption_flow
FROM inventory_daily_snapshot invd
ORDER BY invd.ing_id;




-- 2. Inventory Depletion Trend Velocity:

--  VELOCITY TREND: Today's speed minus yesterday's speed
--  Velocity = consumed_packages - LAG(consumed_packages, 1, 0)

SELECT 
	invd.snapshot_date,
	invd.ing_id,
    invd.consumed_packages,
    consumed_packages - LAG(consumed_packages, 1, 0) OVER (
		PARTITION BY ing_id ORDER BY snapshot_date ASC) AS depletion_velocity
FROM inventory_daily_snapshot invd
LIMIT 10;




-- 3. Manual Re-order Stock Alerts (Stock Between 60% and 80% Max Threshold)

WITH calculated_alerts AS (
SELECT
	invd.snapshot_date,
	invd.ing_id,
    invd.closing_stock,
    invd.pending_order,
    CASE
		WHEN invd.closing_stock < LAG(invd.closing_stock, 1, 0) OVER (
				PARTITION BY invd.ing_id ORDER BY invd.snapshot_date)
			AND invd.pending_order = 'N'
            AND invd.closing_stock BETWEEN 0.60*invt.stock_levels AND 0.80*invt.stock_levels
        THEN "CHECK for reorder"
        ELSE "Don't check for Reorder"
	END AS stock_percent_between60_80
FROM inventory_daily_snapshot invd
INNER JOIN ingredients ing 
	ON invd.ing_id = ing.ing_id
INNER JOIN inventory invt
	ON ing.ing_id = invt.ing_id
)

SELECT * 
FROM calculated_alerts
WHERE 
	YEARWEEK(snapshot_date) = (
		SELECT MAX(YEARWEEK(snapshot_date)) FROM inventory_daily_snapshot
        )
ORDER BY 
    ing_id, 
    snapshot_date ASC;




-- 4. Supplier Lead Time (Order Fulfillment Latency):
-- How long does it actually take to replenish stock after event is trigered ("PURCHASE_ORDER") - either automatically or manually. 
-- "Actual" Lead Time derived from inventory_transactions table:
 
  WITH continuous_stream AS (
    SELECT 
        supplier_id,
        ing_id,
        transaction_type,
        transaction_date,
        -- Generate the uniform timeline
        ROW_NUMBER() OVER(
            PARTITION BY supplier_id, ing_id 
            ORDER BY transaction_date, transaction_id
        ) AS global_seq -- Forming a Numbered Sequence for block-2 ("Forward Looking Frame")
    FROM inventory_transactions
),

delivery_lookup AS (
    SELECT 
        supplier_id,
        ing_id,
        transaction_type,
        transaction_date AS order_date,
        
        -- Look ahead in the continuous stream to grab the very next receipt date
        MIN(CASE WHEN transaction_type = 'PURCHASE_RECEIPT' THEN transaction_date END) -- "What to look for... in Look Forward Frame"
            OVER(
                PARTITION BY supplier_id, ing_id -- These Partitions are same as Previous Numbered Sequence
                ORDER BY global_seq -- Riding on Previous Numbered Sequence
                ROWS BETWEEN 1 FOLLOWING AND UNBOUNDED FOLLOWING -- "Looking Forward Frame"
            ) AS receipt_date
    FROM continuous_stream
)

-- It only FILTERS PURCHASE_ORDERS, because PURCHASE_RECEIPTS also got "paired" by Forward-Looking Frame "ROWS BETWEEN 1 FOLLOWING... "
SELECT 
    supplier_id,
    ing_id,
    transaction_type,
    order_date,
    receipt_date,
    DATEDIFF(receipt_date, order_date) AS lead_time
FROM delivery_lookup
WHERE transaction_type = 'PURCHASE_ORDER'  -- FILTERATION by "PURCHASE_ORDER" is absolutely critical !
ORDER BY ing_id, order_date ASC;





-- 5. Month-Over-Month Supply Chain Disruptions:
-- Monthly Stockout Frequency of ingredient, and Stockout Severity (Total Calendar Days of Stockout)

/*
How frequently do our ingredients run out of stock each month ?
And, how many total calendar days it spent empty (severity) ?
*/


WITH stockout_events AS (
    SELECT
        ing_id,
        ing_name,
        snapshot_date,
        -- Extract month and year for grouping
        DATE_FORMAT(snapshot_date, '%Y-%m') AS `year_month`, -- For Monthly Bucket
        closing_stock,
        
        -- Yesterday's closing stock to check if it was positive
        LAG(closing_stock, 1) OVER (
            PARTITION BY ing_id 
            ORDER BY snapshot_date
        ) AS yesterday_closing_stock
    FROM inventory_daily_snapshot
),

detected_drops AS (
    SELECT *,
        -- THE CORE LOGIC: Count a '1' ONLY on the day it drops below zero
        -- Handle the first day of the dataset (yesterday IS NULL) as a stockout if it starts <= 0
        CASE 
            WHEN closing_stock <= 0 
				AND (yesterday_closing_stock > 0 
                OR yesterday_closing_stock IS NULL) THEN 1 
            ELSE 0 
        END AS stockout_occurrence_flag
    FROM stockout_events
)

SELECT
    `year_month`,
    ing_id,
    ing_name,
    -- Total times the ingredient fell into a stockout state this month
    SUM(stockout_occurrence_flag) AS times_ran_out_of_stock,
    
    -- Bonus Metric: Total actual days spent out of stock this month
    SUM(CASE WHEN closing_stock <= 0 THEN 1 ELSE 0 END) AS total_days_spent_out_of_stock
FROM detected_drops
GROUP BY 
    `year_month`,
    ing_id,
    ing_name
-- This filters out all items that stayed perfectly in stock
HAVING times_ran_out_of_stock > 0 OR total_days_spent_out_of_stock > 0
ORDER BY 
    `year_month` ASC, 
    times_ran_out_of_stock DESC;




-- 6. Days Below Safety Threshold per Ingredient:

SELECT
	DATE_FORMAT(snapshot_date, '%Y-%m') AS `year-month`,
    invd.ing_id,
    invd.ing_name,
    COUNT(*) AS days_below_threshold
FROM inventory_daily_snapshot invd
JOIN inventory inv
    ON invd.ing_id = inv.ing_id
WHERE invd.closing_stock <= inv.reorder_point_packages -- FILTER using condition
GROUP BY DATE_FORMAT(snapshot_date, '%Y-%m'), invd.ing_id, invd.ing_name
ORDER BY invd.ing_id;