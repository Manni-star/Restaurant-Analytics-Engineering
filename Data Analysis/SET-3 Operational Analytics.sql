
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




-- ================================================
-- 		MART 2 — Inventory Stability & Risk Mart
-- ================================================

-- 1. Inventory Volatility Index per Ingredient:

-- How unstable is inventory over time?

/*
SUMMARY CHECKLIST FOR Coefficient of Variation:

	1) Index > 0.50 (Red Alert): Wildly volatile. Hard to predict. Focus here first.
    2) Index 0.20 to 0.50 (Yellow Warning): Moderately shifting. Keep an eye on it.
    3) Index < 0.20 (Green Healthy): Rock-solid stability. Perfectly managed.
*/


WITH volatility_buckets AS(
SELECT
	DATE_FORMAT(snapshot_date, '%Y-%m') AS `year-month`,
    ing_id,
    ing_name,
	
    ROUND (
		AVG(closing_stock), 2 ) AS avg_stock,
    
    ROUND (
    STDDEV(closing_stock), 2 ) AS stock_volatility,

	ROUND (
    STDDEV(closing_stock) / NULLIF(AVG(closing_stock), 0)
    ,2 ) AS volatility_index
FROM inventory_daily_snapshot
GROUP BY `year-month`, ing_id, ing_name
)
SELECT 
	vb.*,
    CASE
-- 		WHEN volatility_index > 0.50 THEN 'Red Alert (Wildly Volatile)' -- This will give error for -ve numbers !
		WHEN volatility_index < 0 OR volatility_index > 0.50 THEN 'Red Alert (Wildly Volatile)'
        WHEN volatility_index BETWEEN 0.20 AND 0.50 THEN 'Yellow Warning (Moderately Shifting)'
        ELSE 'Green Healthy (Rock-Solid Stability)'
	END AS risk_tier
FROM volatility_buckets vb; -- 1782 Rows




-- 2. Stock Drawdown Severity Analysis: (Daily Inventory Drawdown)

-- What is the maximum drop from peak inventory level?

WITH running_peak AS (
    SELECT
		DATE_FORMAT(snapshot_date, '%Y-%m') AS `year-month`,  
        ing_id,
        ing_name,
        snapshot_date,
        closing_stock
	FROM inventory_daily_snapshot
)
SELECT	-- Collapsing Rows:
	`year-month`,

    DATE_FORMAT(
		STR_TO_DATE(CONCAT((`year-month`), '-01'), "%Y-%m-%d"),
        "%M %Y") AS beautify_month,
        
	ing_id,
	ing_name,
    MAX(closing_stock) AS max_monthly,
    MIN(closing_stock) AS min_monthly,
    MAX(closing_stock) - MIN(closing_stock) AS monthly_drawn
FROM running_peak

WHERE `year-month` >= DATE_FORMAT(
                         DATE_SUB((SELECT MAX(snapshot_date) FROM inventory_daily_snapshot), INTERVAL 2 MONTH), 
                         '%Y-%m'
                      ) 
GROUP BY
	`year-month`,
    beautify_month,
	ing_id,
	ing_name
ORDER BY
	`year-month`,
	ing_id,
	ing_name;



-- TRUE "Daily" Inventory Drawdown
-- This is filtered for the Last 2 Month's (Max_Monthly_Stock - daily_stock) per ingredient
WITH running_peak AS (
    SELECT
		DATE_FORMAT(snapshot_date, '%Y-%m') AS `year-month`,   
        ing_id,
        ing_name,
        snapshot_date,
        closing_stock,

        MAX(closing_stock) OVER (
            PARTITION BY DATE_FORMAT(snapshot_date, '%Y-%m') , ing_id
--             ORDER BY snapshot_date
        ) AS peak_stock
    FROM inventory_daily_snapshot
)

SELECT
	rp.*,
	peak_stock - closing_stock AS max_drawdown
FROM running_peak rp

-- EXTRACTION PHASE: Filter dynamically for the last 2 calendar months
WHERE rp.snapshot_date >= 
	DATE_SUB((SELECT MAX(snapshot_date) FROM inventory_daily_snapshot), INTERVAL 2 MONTH)
ORDER BY `year-month`, ing_id, snapshot_date;




-- 3. Reorder Frequency Instability Score:

-- Which ingredients trigger frequent reorder cycles (instability signal) ?

-- Monthly Order Frequency:
SELECT
	EXTRACT(YEAR_MONTH FROM transaction_date ) AS `year_month`,
	ing_id,
    COUNT(ing_id) AS order_frequency_monthly,
    ROUND(30.0 / COUNT(ing_id), 1) AS order_cycle_days
FROM inventory_transactions
WHERE transaction_type = "PURCHASE_ORDER"
	AND transaction_date >= 
    DATE_FORMAT(
		DATE_SUB(
			(SELECT MAX(transaction_date) FROM inventory_transactions),
			INTERVAL 1 MONTH   -- Filter by last 2 months
		),
        "%Y-%m-01"
	)
GROUP BY `year_month`, ing_id
ORDER BY ing_id, `year_month` ;




-- Instability Score and Optimization Action:

WITH reorder_gaps AS (

    -- Layer 1: Calculate Gaps between Purchase Orders
    SELECT
        ing_id,
--         ing_name,
        DATE_FORMAT(transaction_date, '%Y-%m') AS `year-month`,
        transaction_date,
        LAG(transaction_date, 1) OVER (
            PARTITION BY ing_id 
            ORDER BY transaction_date
        ) AS previous_order_date
    FROM inventory_transactions
    WHERE transaction_type = 'PURCHASE_ORDER'
),

procurement_metrics AS (
    -- Layer 2: Core Reorder Frequency & Sample Instability Score
    SELECT
        `year-month`,
        ing_id,
--         ing_name,
        COUNT(*) AS total_reorders_placed,
        ROUND(AVG(DATEDIFF(transaction_date, previous_order_date)), 1) AS avg_days_between_orders,
        ROUND(
            STDDEV_SAMP(DATEDIFF(transaction_date, previous_order_date)) / 
            NULLIF(AVG(DATEDIFF(transaction_date, previous_order_date)), 0), 
            2
        ) AS reorder_instability_score
    FROM reorder_gaps
    WHERE transaction_date >= DATE_FORMAT(
                                 DATE_SUB((SELECT MAX(transaction_date) FROM inventory_transactions), INTERVAL 1 MONTH), 
                                 '%Y-%m-01'
                              )
    GROUP BY `year-month`, ing_id -- , ing_name
), -- 84 ROWS


drawdown_metrics AS (
    -- Layer 3: Max Monthly Drawdown (The Peak-to-Valley Plunge)
    SELECT
        DATE_FORMAT(snapshot_date, '%Y-%m') AS `year-month`,
        ing_id,
        MAX(closing_stock) - MIN(closing_stock) AS monthly_drawn
    FROM inventory_daily_snapshot
    WHERE snapshot_date >= DATE_FORMAT(
                             DATE_SUB((SELECT MAX(snapshot_date) FROM inventory_daily_snapshot), INTERVAL 1 MONTH), 
                             '%Y-%m-01'
                          )
    GROUP BY DATE_FORMAT(snapshot_date, '%Y-%m'), ing_id
) -- 108 ROWS

-- Final Phase: Combine everything and flag optimization targets
SELECT
    p.`year-month`,
    p.ing_id,
--     p.ing_name,
    p.total_reorders_placed,
    p.avg_days_between_orders,
    p.reorder_instability_score,
    d.monthly_drawn AS max_monthly_drawdown,
    
    -- Automated recommendation based on 3 criterias
    CASE 
        WHEN p.total_reorders_placed >= 6 
         AND p.reorder_instability_score <= 0.35 
         AND d.monthly_drawn <= 15 THEN 'CRITICAL TARGET: Consolidate to Bulk'
        WHEN p.total_reorders_placed >= 4 
         AND p.reorder_instability_score <= 0.35 THEN 'RECOMMENDED: Increase Order Size'
        ELSE 'MAINTAIN: Current Cadence is Stable'
    END AS optimization_action
FROM procurement_metrics p
JOIN drawdown_metrics d 
  ON p.ing_id = d.ing_id 
 AND p.`year-month` = d.`year-month` -- 84 ROWS
WHERE p.reorder_instability_score IS NOT NULL; -- 64 ROWS






-- 4. Stockout Risk Score (Threshold-Based Risk Model):

-- Which ingredients are at highest risk of stockout ?


CREATE TEMPORARY TABLE temp_stockout_analysis AS
WITH target_year_cte AS (
	SELECT MAX(YEAR(snapshot_date)) AS max_year FROM inventory_daily_snapshot
), 					-- Single Filtering of MAX(YEAR(..)) to be used in cte blocks below

base AS(

-- Annual Burn-Rate of 54 ingredients
SELECT
	YEAR(snapshot_date) AS max_year,
    ing_id,
    SUM(consumed_packages) AS total_consumed_packages,
    ROUND(SUM(consumed_packages) / 365, 2) AS burn_rate
FROM inventory_daily_snapshot
WHERE YEAR(snapshot_date) = 
		(SELECT max_year FROM target_year_cte)
GROUP BY
	YEAR(snapshot_date),
    ing_id
),

-- Number of days invent can survive without replinishment
base2 AS (
SELECT
	b1.max_year,
	invd.*,
    burn_rate,
    ROUND(
		closing_stock / NULLIF(burn_rate, 0)
	) AS days_without_replishment
FROM base b1
JOIN inventory_daily_snapshot invd
	ON b1.ing_id = invd.ing_id
    AND b1.max_year = YEAR(invd.snapshot_date)     -- Added Filter so that it doesn't scan the whole Table
)

-- Providing "Labels" for Critical Attention
SELECT
	b2.*,
    CASE
		WHEN closing_stock < 0 THEN "Currently Out of Stock!"
        WHEN closing_stock < (2 * burn_rate) 
			AND LAG(closing_stock, 1, 999999) OVER (PARTITION BY ing_id ORDER BY snapshot_date) > (2 * burn_rate)  -- 999999 protects 1st Day Calculation (due to > Operator)
				THEN "Order Immediately CHECK!"
		WHEN days_without_replishment BETWEEN 2 AND 3
				THEN "3-day CHECK"
-- 		ELSE "SAFE level"
	END AS critical_attention_flag
FROM base2 b2
WHERE YEAR(snapshot_date) = b2.max_year
ORDER BY ing_id, snapshot_date;

SELECT * FROM temp_stockout_analysis;

CREATE TEMPORARY TABLE temp_stockout_analysis2 AS
SELECT * FROM temp_stockout_analysis;

-- Answer 1: Which ingredients are at risk RIGHT NOW? (The Current State)
SELECT 
	CONCAT(
		DATE_FORMAT(snapshot_date, "%Y %M %d"),
        ' WEEK(', WEEK(snapshot_date), ')'
	) AS month_week,
	ing_id,
    ing_name,
    closing_stock,
    days_without_replishment,
    critical_attention_flag
FROM temp_stockout_analysis
WHERE critical_attention_flag IS NOT NULL
	AND YEARWEEK(snapshot_date) = (SELECT MAX(YEARWEEK(snapshot_date)) FROM temp_stockout_analysis2)
ORDER BY days_without_replishment ASC;


-- Answer 2: Which ingredients breach the danger zone the MOST OFTEN? (Historical Risk Score)
-- PIVOTED Historical Risk Score Report (with Weights)
SELECT 
    ing_id,
    ing_name,
    -- Grouping all flags into clean, dedicated metric columns
    COUNT(CASE WHEN critical_attention_flag = 'Currently Out of Stock!' THEN 1 END) AS out_of_stock_count,
    COUNT(CASE WHEN critical_attention_flag = 'Order Immediately CHECK!' THEN 1 END) AS emergency_order_count,
    COUNT(CASE WHEN critical_attention_flag = '3-day CHECK' THEN 1 END) AS low_stock_warning_count,
    
    -- Total count of ALL breaches combined
    COUNT(critical_attention_flag) AS total_breach_count,
    
    -- Custom Weighted Risk Score (3 pts for Stockout, 2 for Emergency, 1 for Warning)
    (COUNT(CASE WHEN critical_attention_flag = 'Currently Out of Stock!' THEN 1 END) * 3) +
    (COUNT(CASE WHEN critical_attention_flag = 'Order Immediately CHECK!' THEN 1 END) * 2) +
    (COUNT(CASE WHEN critical_attention_flag = '3-day CHECK' THEN 1 END) * 1) AS cumulative_risk_score
FROM temp_stockout_analysis
WHERE critical_attention_flag IS NOT NULL
GROUP BY 
    ing_id, 
    ing_name
ORDER BY 
    cumulative_risk_score DESC; -- Brings the absolute highest risk items to the top