
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
FROM inventory_daily_snapshot invd;
-- LIMIT 10;




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
    
    
    
    
-- ================================================
-- 		MART 3 — Procurement Intelligence Mart
-- ================================================

-- 1. Supplier Dependency Concentration Index:

-- Are we over-dependent on a few suppliers for ingredients? (i.e. Monopoly vs Diversity)

WITH base AS (
SELECT
	ing_id,
    supplier_id,
    COUNT(*) AS total_orders_by_supplier,
    SUM(change_qty) AS supplier_volume,
    SUM(SUM(change_qty)) OVER (PARTITION BY ing_id) AS total_volume
FROM inventory_transactions
WHERE transaction_type = "PURCHASE_ORDER"
GROUP BY
	ing_id,
    supplier_id	
),

ratios AS (
SELECT
	b.*,
    ROUND((supplier_volume / total_volume), 2) AS supplier_dependency_ratio  -- represents "proportional Volume" i.e. Market Share
FROM base b
)

SELECT 
	r.*,
    -- Window function computes the overall Ingredient Risk Index (HHI: Herfindahl-Hirschman Index)
    ROUND(
		SUM(
			POWER(supplier_dependency_ratio, 2)  -- ratio squared (then Summed against ing_id Bucket)
		) 
		OVER(PARTITION BY ing_id),
	2) AS ingredient_hhi_risk_index  -- HHI: represents monopoly vs diversity
FROM ratios r
ORDER BY ing_id, supplier_id;




-- 2. Supplier Reliability Score (Lead-Time Stability):

-- It is Lead Time Consistency, i.e. Which suppliers deliver consistently (low lead-time variation) ?

 -- "Actual" Lead Time is derived from inventory_transactions table. 
 
 CREATE VIEW v_lead_time AS
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
        ) AS global_seq -- Forming a Numbered Sequence for block-2
    FROM inventory_transactions
),
delivery_lookup AS (
    SELECT 
        supplier_id,
        ing_id,
        transaction_type,
        transaction_date AS order_date,
        -- Look ahead in the continuous stream to grab the very next receipt date
        MIN(CASE WHEN transaction_type = 'PURCHASE_RECEIPT' THEN transaction_date END)
            OVER(
                PARTITION BY supplier_id, ing_id
                ORDER BY global_seq -- Riding on Previous Numbered Sequence
                ROWS BETWEEN 1 FOLLOWING AND UNBOUNDED FOLLOWING
            ) AS receipt_date
    FROM continuous_stream
)

-- It Filters Purchase_Orders, because Purchase_Receipts also got "paired" by "ROWS BETWEEN 1 FOLLOWING... "
SELECT 
    supplier_id,
    ing_id,
    transaction_type,
    order_date,
    receipt_date,
    DATEDIFF(receipt_date, order_date) AS lead_time
FROM delivery_lookup
WHERE transaction_type = 'PURCHASE_ORDER'  -- Filteration by "Purchase_Order" is absolutely critical !
ORDER BY ing_id, order_date ASC;


SELECT * FROM `v_lead_time`;


-- Now we use lead_time column for Coefficient of Variation analysis i.e. Supplier Instability Score

WITH sup_instability AS (
SELECT 
	supplier_id,
    ing_id,
    ROUND(
		AVG(lead_time)
	, 2) AS avg_lead_time,
    ROUND(
		STDDEV_SAMP(lead_time)
	, 2) AS lead_time_volatility,
    ROUND(
		COALESCE(STDDEV_SAMP(lead_time) / AVG(lead_time), 0)
	, 2) AS supplier_instability_score
FROM v_lead_time
GROUP BY
	supplier_id,
    ing_id
)
SELECT 
	si.*,
	(1 - supplier_instability_score)*100 AS sup_reliability_score
FROM sup_instability si;
	
-- Result: All our Suppliers have Reliable Lead Time ( Score = 100% )

   
   
-- Contract Slippage = Actual Lead Time − Static Contract Lead Time
WITH sup_instability AS (
SELECT 
	supplier_id,
    ing_id,
    ROUND(
		AVG(lead_time)
	, 2) AS avg_lead_time,
    ROUND(
		STDDEV_SAMP(lead_time)
	, 2) AS lead_time_volatility,
    ROUND(
		COALESCE(STDDEV_SAMP(lead_time) / AVG(lead_time), 0)
	, 2) AS supplier_instability_score
FROM v_lead_time
GROUP BY
	supplier_id,
    ing_id
),

results AS (
SELECT 
	si.*,
	(1 - supplier_instability_score)*100 AS sup_reliability_score
FROM sup_instability si
)

SELECT
	r.*,
    ings.lead_time, -- Static Contract Lead Time
    r.avg_lead_time - ings.lead_time AS contract_slippage
FROM results r
JOIN ingredients_supplier ings
	ON r.supplier_id = ings.supplier_id
    AND r.ing_id = ings.ing_id;





-- 3. Purchase Order Burst Analysis:

-- Are there sudden spikes in procurement activity?
-- Procurement Burst is Reorder Cycle Velocity (Trigger Gaps).

WITH receipt_lookback AS (
SELECT 
	t.*,
    MAX(CASE WHEN transaction_type = "PURCHASE_RECEIPT" THEN transaction_date END)
			OVER (
				PARTITION BY ing_id
                ORDER BY transaction_date ASC, transaction_type ASC
                ROWS BETWEEN UNBOUNDED PRECEDING AND 1 PRECEDING  -- Looking in "reverse" !! e.g. Purchase Order --> Last Purchase Receipt
			) AS previous_receipt_date
FROM inventory_transactions t
)
SELECT 
	rl.*,
    DATEDIFF(transaction_date, previous_receipt_date) AS order_burst_days
FROM receipt_lookback rl
WHERE transaction_type = "PURCHASE_ORDER"
	AND previous_receipt_date IS NOT NULL
ORDER BY ing_id, transaction_date, transaction_id; 




-- 4. Supplier Switching Frequency per Ingredient:

-- How often do we switch suppliers for the same ingredient (i.e. Vendor Loyality)?

--  LAG() first, and then FILTER in 2nd cte
WITH ranked AS (
    SELECT
        ing_id,
        supplier_id,
        transaction_date,

        LAG(supplier_id, 1, 0) OVER (
            PARTITION BY ing_id
            ORDER BY transaction_date
        ) AS prev_supplier
    FROM inventory_transactions
    WHERE transaction_type = 'PURCHASE_ORDER'
)
SELECT
    ing_id,
	supplier_id,
    COUNT(*) AS total_orders,
    SUM(
        CASE 
            WHEN supplier_id != prev_supplier THEN 1 
            ELSE 0 
        END
    ) AS supplier_switches
FROM ranked
WHERE transaction_date >= DATE_SUB(
						DATE_FORMAT((SELECT MAX(transaction_date) FROM inventory_transactions), '%Y-%m-01'), 
						INTERVAL 1 MONTH)
GROUP BY 
	ing_id,
	supplier_id;




-- 5. Procurement Spend Concentration (Financial Risk View)
-- Which suppliers dominate procurement spend?


-- Procurement Spend Concentration:
WITH base AS (
SELECT 
	t.supplier_id,
    t.ing_id,
    SUM(t.change_qty) AS total_qty_purchased,  -- Purchase Volume
    ing.ing_price * SUM(t.change_qty) AS spend  -- Financials
FROM inventory_transactions t
JOIN ingredients ing
	ON t.ing_id = ing.ing_id
WHERE t.transaction_type = "PURCHASE_ORDER"
GROUP BY 
	t.supplier_id, 
    t.ing_id
)
SELECT
	supplier_id,
    SUM(spend) AS supplier_spend,
    SUM(SUM(spend)) OVER() AS total_spend,
    
	ROUND(
		(SUM(spend) /
			SUM(SUM(spend)) OVER()) * 100
	, 2) AS spend_percentage_share
    
FROM base b
GROUP BY 
	supplier_id
ORDER BY spend_percentage_share DESC;




-- ================================================
-- 	 MART 4 — Scenario Simulation Mart 
-- ================================================


-- 1. Demand Shock Simulation (Scenario Scaling): (What-if Demand Increase)

-- What happens to ingredient demand if Orders increase by X%? (Volume Increase)
-- Find MAX X% Growth Rate from across all years
-- So, (New Demand) = (1 + X) * (Base Demand)


-- Layer 1: Establish the atomic baseline consumption per year by exploding sales down to the recipe grain
WITH demand_base AS (
	SELECT
		YEAR(created_at) AS _year,
		r.ingredients,
        SUM(o.quantity * r.quantity_value) AS consumption
	FROM orders o
	JOIN items it
		ON o.item_id = it.item_id  -- 55163 Rows
	JOIN recipe r
		ON r.sku = it.sku  -- 170822 Rows (Non-Ambiguous Fan-Out)
	GROUP BY YEAR(created_at), r.ingredients
    ORDER BY ingredients, _year
),

-- Layer 2: Chronological lookback to pull the preceding year's volume for velocity comparison
base2 AS (
	SELECT
		db.*,
		LAG(consumption, 1) OVER (PARTITION BY ingredients ORDER BY _year) AS prev_consumption
	FROM demand_base db
),

-- Layer 3: Calculate the dynamic Year-over-Year (YoY) growth percentages
base3 AS (
SELECT
	b2.*,
    (consumption - prev_consumption) / prev_consumption AS yoy_consumption_rate,
    MAX((consumption - prev_consumption) / prev_consumption) OVER(PARTITION BY ingredients) AS optimal_yoy
FROM base2 b2
),

-- Layer 4: Capture the absolute highest historical growth rate per ingredient
optimal_yoy AS (
SELECT
	ingredients,
    MAX(optimal_yoy) AS optimal_yoy    -- Taking the absolute highest historical growth rate
FROM base3 b3
GROUP BY ingredients
),

-- Isolate the absolute latest full calendar year of demand 
latest_year AS (
	SELECT
		YEAR(created_at) AS _year,
		r.ingredients,
        SUM(o.quantity * r.quantity_value) AS consumption
	FROM orders o
	JOIN items it
		ON o.item_id = it.item_id  -- 55163 Rows
	JOIN recipe r
		ON r.sku = it.sku  -- 170822 Rows (Non-Ambiguous Fan-Out)
	WHERE YEAR(created_at) >= 
					(SELECT MAX(YEAR(created_at)) FROM orders)
	GROUP BY YEAR(created_at), r.ingredients
    ORDER BY ingredients, _year
)

-- Forecasting
SELECT
	ly.*,
    oy.optimal_yoy,
    
    ROUND(
		consumption * (1+optimal_yoy) 
	) AS predicted_consmption_annual,   -- The Predictive Forecasting
    
    ROUND(consumption * (1+optimal_yoy)) -
		consumption AS emergency_buffer_units
    
FROM optimal_yoy oy
JOIN latest_year ly
	ON oy.ingredients = ly.ingredients;






-- 2. Ingredient Price Inflation Impact Simulation:

-- What is the cost impact if ingredient prices increase? (Cost Increase)

-- Scenario: +15% price increase
-- So, (New Price) = 1.15 * (Base Price)


WITH cost_base AS (
    SELECT
        r.ingredients AS ing_id,
        ing.ing_price,
        ing.ing_weight,

        SUM(o.quantity * r.quantity_value) AS total_consumption
    FROM orders o
    JOIN items i 
		ON o.item_id = i.item_id
    JOIN recipe r 
		ON i.sku = r.sku
    JOIN ingredients ing 
		ON r.ingredients = ing.ing_id
	WHERE YEAR(created_at) >= 
				(SELECT MAX(YEAR(created_at)) FROM orders)
    GROUP BY r.ingredients, ing.ing_price, ing.ing_weight
)

SELECT
    ing_id,

    (ing_price / ing_weight) AS unit_cost,

    total_consumption,

    (total_consumption * (ing_price / ing_weight)) AS base_cost,

    (total_consumption * (ing_price * 1.15 / ing_weight)) AS inflated_cost, -- (New Price) = 1.15 * (Base Price)

    ((total_consumption * (ing_price * 1.15 / ing_weight)) 
     - (total_consumption * (ing_price / ing_weight))) AS cost_impact
FROM cost_base
ORDER BY cost_impact DESC;






-- ==============================================================
-- 	 MART 5 — Product Profitability Intelligence Mart 
-- ==============================================================

-- 1.1 Gross Product Margin:

-- Gross Profit Margin of Items
WITH base AS (
SELECT 
	o.order_id,
	it.item_id,
	ing.ing_id,
	o.quantity,
	it.item_price,
	o.quantity * it.item_price AS revenue_item,
	r.quantity_value,
	ing.ing_weight,
	ing.ing_price,
    (ing.ing_price / ing.ing_weight) * r.quantity_value * o.quantity AS cost_price_ingredient
    
FROM orders o
JOIN items it
	ON o.item_id = it.item_id
JOIN recipe r
	ON it.sku = r.sku
JOIN ingredients ing
	ON r.ingredients = ing.ing_id
),

base2 AS (
SELECT
	order_id,
	item_id, -- Collapse by item and remove it's division by ing_id
    MAX(revenue_item) AS revenue_item,
    
    ROUND(
		SUM(SUM(cost_price_ingredient))
			OVER(PARTITION BY order_id, item_id)
	,2)  AS cost_price_item,  -- OVER(...) is absolutely necessary

	MAX(revenue_item) -
			ROUND(
				SUM(SUM(cost_price_ingredient))
					OVER(PARTITION BY order_id, item_id)
			,2) 
		AS profit_item
FROM base
GROUP BY 
	order_id,
    item_id
)
SELECT 
	item_id,
    SUM(profit_item) AS total_profits,
    SUM(revenue_item) AS total_revenue,
    ROUND(
		SUM(profit_item) / SUM(revenue_item) 
	, 2) AS profit_margin
FROM base2
GROUP BY item_id;


-- Important: GROSS PRODUCT MARGIN OVER TIME - It remains constant owing to it's "nature"



-- 1.2 NET PROFIT MARGIN OVER TIME

-- PART 1: The "As-Is" Diagnostic Reality (Baseline Assessment) !
-- Monthly Labour Cost
WITH monthly_payroll AS (
SELECT
	DATE_FORMAT(`date`, "%Y-%m") AS _year_month,
    SUM(wages) AS monthly_wages
FROM `v_daily_payroll`
GROUP BY 
	DATE_FORMAT(`date`, "%Y-%m")
ORDER BY _year_month
),

-- REVENUE AND COST PRICE (monthly)
base AS (
SELECT
	DATE_FORMAT(o.created_at, "%Y-%m") AS _year_month,
    o.order_id,
	it.item_id,
	MAX(o.quantity * it.item_price) AS revenue_item, -- Revenue
    
	ROUND(
		SUM((ing.ing_price / ing.ing_weight) * r.quantity_value * o.quantity)  -- Cost
	, 2) AS cost_price_ingredient
FROM orders o
JOIN items it
	ON o.item_id = it.item_id
JOIN recipe r
	ON it.sku = r.sku
JOIN ingredients ing
	ON r.ingredients = ing.ing_id
GROUP BY 
	DATE_FORMAT(o.created_at, "%Y-%m"),
	o.order_id,
    it.item_id
),

-- JOIN monthly_payroll to base:
revenue_wages_base AS (
SELECT
	b.*,
    mp.monthly_wages
FROM base b
JOIN monthly_payroll mp
	ON b.`_year_month` = mp.`_year_month`
)

-- NET PROFIT MARGIN CALCULATION:
SELECT
	_year_month,
--     item_id,
	ROUND(SUM(revenue_item)) AS total_revenue_monthly, -- 1. monthly Revenue
    
    ROUND(SUM(cost_price_ingredient)) AS total_cost_price_monthly, -- 2. monthly Cost
    
    ROUND(MAX(monthly_wages)) AS total_monthly_wages, -- 3. monthly Wages
    
    ROUND(SUM(revenue_item) - SUM(cost_price_ingredient) - MAX(monthly_wages)) AS net_monthly_profit, -- (i)
    
    ROUND(
		(SUM(revenue_item) - SUM(cost_price_ingredient) - MAX(monthly_wages)) /
								NULLIF(SUM(revenue_item),0) 
	, 4)	AS 	net_profit_margin_over_time	

FROM revenue_wages_base
GROUP BY
	_year_month
ORDER BY _year_month;


-- (i) notes: 
-- If revenue_item = a, cost_price_ingredient = b, then
-- (a1 - b1) + (a2 - b2) + ... = (a1 + a2 + ..) - (b1 + b2 + ...) 
-- 		 = SUM(revenue_item) - SUM(cost_price_ingredient)




-- PART 2: The "To-Be" Optimization Model (Strategic Impact Analysis) !
/*
Notes/ Description:

It targets a +15.0% Net Profit Margin (NPM) to our Peak Operational Efficiency Month (July 2023). 
Our previous (historical) NPM for our Peak Operational Efficiency Month (July 2023) was -44.56% (-0.4456)

We Mathematically derived an exact "menu price optimization multiplier" of 1.70x 
to achieve this +15.0% NPM (used in code).
This 1.70x anchor successfully pulled the entire company out of the red.

Hence, we simulated a premium market re-positioning !

BUSINESS LOGIC FOR PEAK-MONTH PRICING OPTIMIZATION: 
  Instead of a blanket price hike, we'd anchor our optimization model to the 
  business's Peak Efficiency Month (2023-07). 
  
  ALGEBRAIC DERIVATION:
  
  Target NPM = (Revenue - Ingredient Cost - LABOR_Wages) / Revenue
			 = (total_revenue_July - total_cost_price_July - total_July_wages) / total_revenue_July

  0.15 = (x * 63792 - 11703 - 80512) / (x * 63792)
  or, x = 1.70 

  Below is it's Impact Assessment.
*/


-- Monthly Labour Cost: (PART -2)
WITH monthly_payroll AS (
SELECT
	DATE_FORMAT(`date`, "%Y-%m") AS _year_month,
    SUM(wages) AS monthly_wages
FROM `v_daily_payroll`
GROUP BY 
	DATE_FORMAT(`date`, "%Y-%m")
ORDER BY _year_month
),

-- REVENUE AND COST PRICE (monthly)
base AS (
SELECT
	DATE_FORMAT(o.created_at, "%Y-%m") AS _year_month,
    o.order_id,
	it.item_id,
	MAX(o.quantity * it.item_price * 1.70) AS revenue_item, -- MULTIPLYING item_price BY 1.70 Factor to achieve NPM = 15% as MAX NPM. 
    
	ROUND(
		SUM((ing.ing_price / ing.ing_weight) * r.quantity_value * o.quantity)
	, 2) AS cost_price_ingredient
FROM orders o
JOIN items it
	ON o.item_id = it.item_id
JOIN recipe r
	ON it.sku = r.sku
JOIN ingredients ing
	ON r.ingredients = ing.ing_id
GROUP BY 
	DATE_FORMAT(o.created_at, "%Y-%m"),
	o.order_id,
    it.item_id
),

-- JOIN monthly_payroll to base:
revenue_wages_base AS (
SELECT
	b.*,
    mp.monthly_wages
FROM base b
JOIN monthly_payroll mp
	ON b.`_year_month` = mp.`_year_month`
)

-- NET PROFIT MARGIN CALCULATION:
SELECT
	_year_month,
--     item_id,
	ROUND(SUM(revenue_item)) AS total_revenue_monthly, -- 1
    
    ROUND(SUM(cost_price_ingredient)) AS total_cost_price_monthly, -- 2
    
    ROUND(MAX(monthly_wages)) AS total_monthly_wages, -- 3
    
    ROUND(SUM(revenue_item) - SUM(cost_price_ingredient) - MAX(monthly_wages)) AS net_monthly_profit,
    
    ROUND(
		(SUM(revenue_item) - SUM(cost_price_ingredient) - MAX(monthly_wages)) /
								NULLIF(SUM(revenue_item),0) 
	, 4)	AS 	net_profit_margin_over_time	

FROM revenue_wages_base
GROUP BY
	_year_month
ORDER BY _year_month;





-- PART 3: Catalog Re-Pricing Strategy (Operational Deployment): 
-- Item's table Price hike to achieve NPM = +15 %

SELECT
	it.*,
    FORMAT(
		ROUND(it.item_price * 1.70 ,1)
	, 2) AS new_item_price
FROM items it;







-- 2. Profit Contribution Ranking (Pareto Analysis):

-- Which products drive most of the profit?

-- Notes:
-- We shall perform Pareto Analysis on Net Profits which includes Labor, than on
-- Gross Profits which does not incluse labor.
-- Also, we shall Factor in 1.70x on Item Prices to maintain NPM = 15 %
-- Because restaurant was loosing money (Negative NPM) due to high Labor overheads.
-- Also, Pareto Analysis will be performed on:
	-- Annual Cumulative Data ( Latest year) than Lifetime Cumulative Data. 

-- So when we are performing:
		-- Net Profit = (Revenue - Ingredient Cost - LABOR_Wages)
	-- If we keep Revenue Cumulating every day, and Ingredient Cost cumulating every day, 
	-- then we have to keep  LABOR_Wages cumulating as well !


-- Pareto Analysis for Latest Year only
SELECT MAX(YEAR(`date`)) FROM `v_daily_payroll`; -- Latest Year is "2025"




-- We'll introduce Weighting Vector to simulate an Activity-Based Costing (ABC) Model !

-- (PARETO QUERY)
WITH daily_payroll AS (  
SELECT
	`date` AS _date, -- Daily payroll and not Monthly for Pareto Analysis cumulation operation after Join
    SUM(wages) AS daily_wages
FROM `v_daily_payroll`
WHERE YEAR(`date`) >= 2025   -- Pareto Analysis for Latest Year only
GROUP BY 
	`date`
ORDER BY _date
),

-- REVENUE AND COST PRICE (daily)
base AS (      -- ingredients Grain removed
SELECT
	DATE(o.created_at) AS _date,
    o.order_id,
	it.item_id,

	MAX(o.quantity * it.item_price * 1.70) AS revenue_item, -- MULTIPLYING item_price BY 1.70 Factor to achieve NPM = 15% as MAX NPM. 
    
	ROUND(
		SUM((ing.ing_price / ing.ing_weight) * r.quantity_value * o.quantity)
	, 2) AS cost_price_ingredient
FROM orders o
JOIN items it
	ON o.item_id = it.item_id
JOIN recipe r
	ON it.sku = r.sku
JOIN ingredients ing
	ON r.ingredients = ing.ing_id
WHERE YEAR(o.created_at) >= 2025 -- Pareto Analysis for Latest Year only
-- 	AND order_id = "ORD_15347"
GROUP BY 
	DATE(o.created_at),
	o.order_id,
    it.item_id
ORDER BY _date
),

-- JOIN monthly_payroll to base:
revenue_wages_base AS (
SELECT
	b.*,
    dp.daily_wages
FROM base b
JOIN daily_payroll dp
	ON b.`_date` = dp.`_date`
ORDER BY _date
),

-- NET PROFIT = (Revenue - Ingredient Cost - Wages)
-- NET PROFIT MARGIN CALCULATION:
activity_based_costing AS (
SELECT
	_date,
    item_id, -- Pareto Analysis at Item Level
    
	ROUND(
		SUM(revenue_item) 
	, 2) AS total_revenue_daily, -- 1. Daily Revenue by item
    
	ROUND(
		SUM(revenue_item) / SUM(SUM(revenue_item)) OVER ( PARTITION BY _date) 
	, 2) AS weighting_vector, -- ABC Approach
    
    ROUND(SUM(cost_price_ingredient)) AS total_cost_price_daily, -- 2. Daily Cost by item
    
    ROUND(MAX(daily_wages)) AS total_daily_wages, -- 3. Wages
    
	ROUND(
		SUM(revenue_item) / SUM(SUM(revenue_item)) OVER ( PARTITION BY _date) 
	, 2) * 
		ROUND(MAX(daily_wages)) AS activity_based_costing   -- weighting_vector * total_daily_wages = ABC
    
FROM revenue_wages_base
GROUP BY
	_date,
    item_id
ORDER BY _date
),

net_profit AS (
SELECT
	abc._date,
    item_id,
    total_revenue_daily - total_cost_price_daily - activity_based_costing AS net_profit
    
FROM activity_based_costing abc
),

-- PARETO ANALYSIS Base:
base_pareto AS (
SELECT 
    YEAR(_date) AS max_year,
    item_id,
    SUM(net_profit) AS annual_net_profit
FROM net_profit np
WHERE net_profit > 0 
GROUP BY 
    YEAR(_date),
    item_id
),

-- PARETO ANALYSIS Percentage:
pareto_perc AS (
SELECT
	bp.*,
	SUM(annual_net_profit) OVER (PARTITION BY max_year 
						ORDER BY annual_net_profit DESC) as cum_sum, -- CUMULATIVE SUM
                        
	SUM(annual_net_profit) OVER () AS total_sum,
    
    SUM(annual_net_profit) OVER (PARTITION BY max_year 
						ORDER BY annual_net_profit DESC) /
			SUM(annual_net_profit) OVER () AS perc
    
FROM base_pareto bp
)

-- 80 % Pareto Items
SELECT
	*
FROM pareto_perc
WHERE perc <= 0.80
	  OR perc = (SELECT MIN(perc) FROM pareto_perc WHERE perc > 0.80)
ORDER BY annual_net_profit DESC;



-- =======================================
-- (The DIAGNOSTIC QUERY:
-- =======================================

-- Notes: We Filtered-out "Negative" annual_net_profit Items while doing Pareto Analysis !
-- We shall analyze those here in "The DIAGNOSTIC QUERY"
-- We address those Negatives for turning them into Positives.


-- (Taken from Pareto Query code and modified)
WITH daily_payroll AS (  
SELECT
	`date` AS _date, -- Daily payroll and not Monthly for Pareto Analysis cumulation operation after Join
    SUM(wages) AS daily_wages
FROM `v_daily_payroll`
WHERE YEAR(`date`) >= 2025   -- Pareto Analysis for Latest Year only
GROUP BY 
	`date`
ORDER BY _date
),

-- REVENUE AND COST PRICE (daily)
base AS (  
SELECT
	DATE(o.created_at) AS _date,
    o.order_id,
	it.item_id,
    
	MAX(o.quantity * it.item_price * 1.70) AS revenue_item, -- Multiplying item_price BY 1.70 Factor to achieve NPM = 15% as MAX NPM. 
    
	ROUND(
		SUM((ing.ing_price / ing.ing_weight) * r.quantity_value * o.quantity)
	, 2) AS cost_price_ingredient
FROM orders o
JOIN items it
	ON o.item_id = it.item_id
JOIN recipe r
	ON it.sku = r.sku
JOIN ingredients ing
	ON r.ingredients = ing.ing_id
WHERE YEAR(o.created_at) >= 2025 -- Pareto Analysis for Latest Year only
GROUP BY 
	DATE(o.created_at),
	o.order_id,
    it.item_id
ORDER BY _date
),

-- JOIN monthly_payroll to base:
revenue_wages_base AS (
SELECT
	b.*,
    dp.daily_wages
FROM base b
JOIN daily_payroll dp
	ON b.`_date` = dp.`_date`
ORDER BY _date
),

-- NET PROFIT = (Revenue - Ingredient Cost - Wages)
-- NET PROFIT MARGIN CALCULATION:
activity_based_costing AS (
SELECT
	_date,
    item_id, -- Pareto Analysis at Item Level
    
	ROUND(
		SUM(revenue_item) 
	, 2) AS total_revenue_daily, -- 1.
    
	ROUND(
		SUM(revenue_item) / SUM(SUM(revenue_item)) OVER ( PARTITION BY _date) 
	, 2) AS weighting_vector, -- ABC Approach
    
    ROUND(SUM(cost_price_ingredient)) AS total_cost_price_daily, -- 2.
    
    ROUND(MAX(daily_wages)) AS total_daily_wages, -- 3.
    
	ROUND(
		SUM(revenue_item) / SUM(SUM(revenue_item)) OVER ( PARTITION BY _date) 
	, 2) * 
		ROUND(MAX(daily_wages)) AS activity_based_costing   -- weighting_vector * total_daily_wages = ABC
    
FROM revenue_wages_base
GROUP BY
	_date,
    item_id
ORDER BY _date
),

net_profit AS (
SELECT
	abc._date,
    item_id,
    total_revenue_daily - total_cost_price_daily - activity_based_costing AS net_profit
    
FROM activity_based_costing abc
),

-- PARETO ANALYSIS Base:
base_pareto AS (
SELECT 
    YEAR(_date) AS max_year,
    item_id,
    SUM(net_profit) AS annual_net_profit
FROM net_profit np
GROUP BY 
    YEAR(_date),
    item_id
)
SELECT
	*
FROM base_pareto
WHERE annual_net_profit < 0 -- Filter Only the negative Numbers
ORDER BY annual_net_profit ASC ;


-- CONCLUSION:
-- MAX annual_net_profit = -3588.03 (loss) for it032

-- Target NPM = (Revenue - Ingredient Cost - LABOR_Wages) / Revenue
-- (Revenue - Ingredient Cost - LABOR_Wages) = -3588.03
-- There are 3 ways to Increase Profits to 0 (Break-Even):
	-- a. Increase Revenue
    -- b. Decrease Ingredient Cost
    -- c. Decrease Labor 
    
    -- a. We already Increased Revenue by 1.70 x Item_Price ( As Revenue = #Orders * Item_Price ) to get a 15% Max "Monthly" NPM
    -- We can "Preferentially" increase Item_Price of individual Items even further for Items incurring a loss. 
    -- LOSS ITEMS are (it032, it030, it028, it026, it027, it031, it029, it025)
    
    
	-- b. Decrease Ingredient Cost: (Ref. to (i) Exported csv)

/*
# _date	item_id	total_revenue_daily	total_cost_price_daily	activity_based_costing	net_profit
		2025-01-01	it032	118.83	50	145.28	-76.45
		2025-01-02	it032	83.18	35	49.92	-1.74
		2025-01-03	it032	11.88	5	0.00	6.88
		2025-01-04	it032	83.18	35	44.88	3.30
		2025-01-05	it032	130.71	55	54.40	21.31
		2025-01-06	it032	47.53	20	72.64	-45.11
		...

	Getting a NPM= 0 (Break-Even) is impossible by lowering Ingredient Cost ! 
    (Refer to Research document query: "SQL File 33".sql)
    So we have to adjust the Other Factor i.e. Wages (activity_based_costing) in tandem with "total_cost_price_daily"
    
    
*/   
    
    -- c. Decrease Labor is identified on Days for ITEM incuring MAX Loss( it032) AS:
    /*
			# _day	_dayNumber	annual_daywise_loss
			Mon			1		-1267.13
			Tue			2		-1254.79
			Wed			3		-1247.22
			Thu			4		-453.07
			Fri			5		15.63
			Sat			6		42.10
			Sun			7		576.45
            
	So, the Loss Days for the operations are primarily - Mon, Tue and Wed
    (Ref to "annual_daywise_loss" Research query file).
    
    */

    --  But decreasing Labor on  Mon, Tue and Wed could also impact Pareto Products.
    --  Hence, we will also conduct Impact Assessment.
      

	-- d. Another Alternative Way: Cost Price/ Revenue Analysis:
		-- total_cost_price_daily / total_revenue_daily = 50/ 118.83 = 42%
		-- A 42% food cost is very high for retail food operations (the industry standard target is 28% to 32%).
        /*
		   By simply substituting an expensive cheese brand or shrinking the portion size slightly
		   to bring that food cost down to 30%, 
		   we can inject $12 of pure profit back into every $100 of sales, 
		   instantly pushing it032 toward a positive net return.
		*/


	-- Exploring Further Options (c) and (d):
-- Also Tests reveal that (Ref to 'Tests on Scheduling' script):

-- Measure 1:
-- CUTTING workforce below leads to a Decrease in Daily Wages (on Mon, Tue and Wed) by 0.12 or 12% !!
	-- We have 3 Delivery Drivers on Monday
	   -- Let's cut it to 2 per shift. ( So, 1 x 2 = 2 cuts for every shift in a Day)
	-- We have 2 Kitchen Assistant on Monday
		-- Let's cut it to 1 per shift. ( So, 1 x 2 = 2 cuts for every shift in a Day )
-- So, we shall apply this 12% reduction on Daily wages on Mon, Tue and Wed


-- Measure 2:
-- CUTTING 'FOOD COST RATIO' (COST / REVENUE) to 0.30 and under, will Impact only these Items:
	/*
	item_id	avg_cost	avg_revenue	avg_food_cost_ratio
	it027	9.9040		25.171240		0.39
	it028	20.6080		52.463000		0.39
	it030	21.3927		49.914534		0.43
	it032	28.5141		67.766948		0.42
	*/
-- Hence, for COST / REVENUE >= 0.35, we shall tame the COST of these Items as under:
	/*
		total_cost_price_daily / total_revenue_daily = 0.35
        Or, total_cost_price_daily = 0.35 * total_revenue_daily

	*/



	-- IMPACT ANALYSIS applying Measure 1 and Measure 2:
-- SCENARIO 1:
-- Measure 1: 12% reduction on Daily wages on Mon, Tue and Wed
-- Measure 2: Setting a ceiling at 35 % for Food "Cost Ratio" i.e. Setting
		-- 	  total_cost_price_daily = 0.35 * total_revenue_daily, 
		--    for Items having (total_cost_price_daily / total_revenue_daily) >= 0.35
        
-- ADDITIONAL SCENARIOS ADDED:
-- SCENARIO 2:
-- Measure 1: 23% reduction on Daily wages on Mon, Tue and Wed
-- Measure 2: Setting a ceiling at 35 % for Food "Cost Ratio" i.e. Setting
		-- 	  total_cost_price_daily = 0.35 * total_revenue_daily, 
		--    for Items having (total_cost_price_daily / total_revenue_daily) >= 0.35


-- SCENARIO 3:
-- Measure 1: 23% reduction on Daily wages on Mon, Tue and Wed
-- Measure 2: Setting a ceiling at 30 % for Food "Cost Ratio" i.e. Setting
		-- 	  total_cost_price_daily = 0.30 * total_revenue_daily, 
		--    for Items having (total_cost_price_daily / total_revenue_daily) >= 0.30



-- PARETO ANALYSIS WITH SCENARIO ANALYSIS: 
WITH daily_payroll AS (  
SELECT
	`date` AS _date, -- Daily payroll and not Monthly for Pareto Analysis cumulation operation after Join
    SUM(wages) AS daily_wages
FROM `v_daily_payroll`
WHERE YEAR(`date`) >= 2025   -- Pareto Analysis for Latest Year only
GROUP BY 
	`date`
ORDER BY _date
),

-- REVENUE AND COST PRICE (daily)
base AS (  
SELECT
	DATE(o.created_at) AS _date,
    o.order_id,
	it.item_id,
    
	MAX(o.quantity * it.item_price * 1.70) AS revenue_item, -- MULTIPLYING item_price BY 1.70 Factor to achieve NPM = 15% as MAX NPM. 
    
	ROUND(
		SUM((ing.ing_price / ing.ing_weight) * r.quantity_value * o.quantity)
	, 2) AS cost_price_ingredient
FROM orders o
JOIN items it
	ON o.item_id = it.item_id
JOIN recipe r
	ON it.sku = r.sku
JOIN ingredients ing
	ON r.ingredients = ing.ing_id
WHERE YEAR(o.created_at) >= 2025 -- Pareto Analysis for Latest Year only

GROUP BY 
	DATE(o.created_at),
	o.order_id,
    it.item_id
ORDER BY _date
),

-- JOIN monthly_payroll to base:
revenue_wages_base AS (
SELECT
	b.*,
    dp.daily_wages
FROM base b
JOIN daily_payroll dp
	ON b.`_date` = dp.`_date`
ORDER BY _date
),

-- NET PROFIT = (Revenue - Ingredient Cost - Wages)
-- NET PROFIT MARGIN CALCULATION:
activity_based_costing AS (
SELECT
	_date,
    item_id, -- Pareto Analysis at Item Level
    
	ROUND(
		SUM(revenue_item) 
	, 2) AS total_revenue_daily, -- 1. Daily Revenue by item
    
	ROUND(
		SUM(revenue_item) / SUM(SUM(revenue_item)) OVER ( PARTITION BY _date) 
	, 2) AS weighting_vector, -- ABC Approach
    
    ROUND(SUM(cost_price_ingredient)) AS total_cost_price_daily, -- 2. Daily Cost by item
    
    ROUND(MAX(daily_wages)) AS total_daily_wages, -- 3. Wages
    
	ROUND(
		SUM(revenue_item) / SUM(SUM(revenue_item)) OVER ( PARTITION BY _date) 
	, 2) * 
		ROUND(MAX(daily_wages)) AS activity_based_costing   -- weighting_vector * total_daily_wages = ABC
    
FROM revenue_wages_base
GROUP BY
	_date,
    item_id
ORDER BY _date
),

net_profit AS (
SELECT
	abc._date,
    item_id,
    total_revenue_daily,
    total_cost_price_daily,
    activity_based_costing,
    total_revenue_daily - total_cost_price_daily - activity_based_costing AS net_profit
    
FROM activity_based_costing abc
),

-- Measure 1 and Measure 2: (For each Scenario 1, Scenario 2, Scenario 3)
measures_base_sc AS (
SELECT
	*,
    -- ===========
    -- SCENARIO 1 
    -- ===========
    
    -- Measure 1:
    CASE
		WHEN DATE_FORMAT(`_date`, '%a') IN ('Mon', 'Tue', 'Wed')
			THEN ROUND(activity_based_costing * 0.88, 2) 	-- 12 % Reduction
		ELSE activity_based_costing
	END AS sc1_activity_based_costing,
    
    -- Measure 2:
    CASE
		WHEN (total_cost_price_daily / total_revenue_daily) >= 0.35
			THEN ROUND(0.35 * total_revenue_daily, 2)		-- 35% Ceiling
		WHEN (total_cost_price_daily / total_revenue_daily) < 0.35
			THEN total_cost_price_daily
	END AS sc1_total_cost_price_daily,
    
    
    -- ===========
    -- SCENARIO 2 
    -- ===========
    
    -- Measure 1:
    CASE
		WHEN DATE_FORMAT(`_date`, '%a') IN ('Mon', 'Tue', 'Wed')
			THEN ROUND(activity_based_costing * 0.77, 2) -- 23 % Reduction
		ELSE activity_based_costing
	END AS sc2_activity_based_costing,
    
    -- Measure 2:
    CASE
		WHEN (total_cost_price_daily / total_revenue_daily) >= 0.35  
			THEN ROUND(0.35 * total_revenue_daily, 2)		-- 35% Ceiling
		WHEN (total_cost_price_daily / total_revenue_daily) < 0.35
			THEN total_cost_price_daily
	END AS sc2_total_cost_price_daily,
    
    -- ===========
    -- SCENARIO 3 
    -- ===========
    
    -- Measure 1:
    CASE
		WHEN DATE_FORMAT(`_date`, '%a') IN ('Mon', 'Tue', 'Wed')
			THEN ROUND(activity_based_costing * 0.77, 2) 	-- 23 % Reduction
		ELSE activity_based_costing
	END AS sc3_activity_based_costing,
    
    -- Measure 2:
    CASE
		WHEN (total_cost_price_daily / total_revenue_daily) >= 0.30
			THEN ROUND(0.30 * total_revenue_daily, 2) 		-- 30% Ceiling
		WHEN (total_cost_price_daily / total_revenue_daily) < 0.30
			THEN total_cost_price_daily
	END AS sc3_total_cost_price_daily  
    
    
FROM net_profit
),

results AS (
SELECT
	*,
    (total_revenue_daily - sc1_total_cost_price_daily - sc1_activity_based_costing) AS
		sc1_new_net_profit,
        
    (total_revenue_daily - sc2_total_cost_price_daily - sc2_activity_based_costing) AS
		sc2_new_net_profit,

    (total_revenue_daily - sc3_total_cost_price_daily - sc3_activity_based_costing) AS
		sc3_new_net_profit	
FROM measures_base_sc
)

SELECT
-- 	MONTH(_date) AS _month,
    item_id,
    SUM(net_profit) AS net_profit,
    SUM(sc1_new_net_profit) AS sc1_new_net_profit,
    SUM(sc2_new_net_profit) AS sc2_new_net_profit,
    SUM(sc3_new_net_profit) AS sc3_new_net_profit
    
FROM results
GROUP BY
-- 	MONTH(_date),
    item_id;






-- 3. Cohort-Based Profitability Analysis:

-- Value-Accumulation Cohort Matrix:
-- ( It tracks the volume footprint over time )

WITH RECURSIVE calendar_spine AS (
    -- Step 1: The Anchor - Establish the hardcoded start date of your dataset
    SELECT STR_TO_DATE('2023-02-01', '%Y-%m-%d') AS cohort_month
    
    UNION ALL
    
    -- Step 2: The Loop - Increment month-by-month until the termination boundary
    SELECT DATE_ADD(cohort_month, INTERVAL 1 MONTH)
    FROM calendar_spine
    WHERE cohort_month < STR_TO_DATE('2025-10-01', '%Y-%m-%d')
),

first_purchase_cohort AS ( 
SELECT
	cust_id,
    MIN(DATE(created_at)) AS first_purchase, -- logs First Purchase
	DATE_FORMAT(MIN(DATE(created_at)), '%Y-%m') AS acquisition_cohort -- Time Based Cohort
FROM orders
GROUP BY
	cust_id
),

relative_time_distance AS(
	SELECT
		fpc.*,
        o.quantity AS quantity,
        PERIOD_DIFF(
			DATE_FORMAT(o.`created_at`, '%Y%m'), 
            DATE_FORMAT(fpc.`first_purchase`, '%Y%m')
        ) AS months_since_signup
	FROM first_purchase_cohort fpc
    JOIN orders o
		ON o.cust_id = fpc.cust_id
),			-- (cust_id, first_purchase, acquisition_cohort, months_since_signup)

cohort_metrics AS (
SELECT
	acquisition_cohort,
    
    -- KPI 1: Headcount (Counts unique users generated per month)
	COUNT(DISTINCT cust_id) AS customer_acquisition,
    
	-- KPI 2: Collective Lifecycle Volume
    -- Range Segment 1: 	0 : ltv_month_0
    SUM(
		CASE
			WHEN months_since_signup = 0 THEN quantity ELSE 0
		END
	) AS ltv_month_0, -- cohort_quantity_ltv_month_0 (1st 30 Days)
    
    -- Range Segment 2: 	0-12 : cumulative_ltv_month_12
    SUM(
		CASE
			WHEN months_since_signup BETWEEN 0 AND 12 THEN quantity ELSE 0
		END
	) AS cumulative_ltv_month_12, -- cohort_quantity_ltv_month_12 (Cumulative)
    
    -- Range Segment 3: 	0-24 : cumulative_ltv_month_24
    SUM(
		CASE
			WHEN months_since_signup BETWEEN 0 AND 24 THEN quantity ELSE 0
		END
	) AS cumulative_ltv_month_24, -- cohort_quantity_ltv_month_24 (Cumulative)
    
    
    -- KPI 3: Normalized Engagement Ratio (Average lifecycle items purchased per acquired customer head)
        -- Range Segment 1:
    ROUND(
		SUM(CASE WHEN months_since_signup = 0 THEN quantity ELSE 0 END)
        / NULLIF(COUNT(DISTINCT cust_id), 0)   -- Volume / Headcount
	, 1) AS avg_month_0, -- avg_cohort_items_per_customer_month_0

		-- Range Segment 2:
    ROUND(
		SUM(CASE WHEN months_since_signup BETWEEN 0 AND 12 THEN quantity ELSE 0 END)
        / NULLIF(COUNT(DISTINCT cust_id), 0)   -- Volume / Headcount
	, 1) AS cumulative_avg_m12, -- avg_cohort_items_per_customer_month_12
    
        -- Range Segment 3:
    ROUND(
		SUM(CASE WHEN months_since_signup BETWEEN 0 AND 24 THEN quantity ELSE 0 END)
        / NULLIF(COUNT(DISTINCT cust_id), 0)   -- Volume / Headcount
	, 1) AS cumulative_avg_m24  -- avg_cohort_items_per_customer_month_24

FROM relative_time_distance rtd
GROUP BY
	acquisition_cohort
)

SELECT
	DATE_FORMAT(cs.cohort_month, '%b-%y') AS acquisition_cohort,
    COALESCE(customer_acquisition, 0) AS customer_acquisition,
    COALESCE(ltv_month_0, 0) AS ltv_m0,
    COALESCE(cumulative_ltv_month_12, 0) AS cumulative_ltv_m12,
    COALESCE(cumulative_ltv_month_24, 0) AS cumulative_ltv_m24,
    avg_month_0 AS avg_m0, -- Do not coalesce percentages
    cumulative_avg_m12, -- Do not coalesce percentages
    cumulative_avg_m24 --  NULLs can be formatted as clean blanks/dashes in Streamlit.

FROM calendar_spine cs
LEFT JOIN cohort_metrics cm
	ON DATE_FORMAT(cs.cohort_month, '%Y-%m') = cm.acquisition_cohort
ORDER BY cs.cohort_month ASC;




-- USER RETENTION HEATMAP: i.e. "RETURNING CUSTOMERS" HEADCOUNT COHORT MATRIX
-- RETURNING CUSTOMERS

WITH RECURSIVE calendar_spine AS (
    -- Step 1: The Anchor - Establish the hardcoded start date of your dataset
    SELECT STR_TO_DATE('2023-02-01', '%Y-%m-%d') AS cohort_month
    
    UNION ALL
    
    -- Step 2: The Loop - Increment month-by-month until the termination boundary
    SELECT DATE_ADD(cohort_month, INTERVAL 1 MONTH)
    FROM calendar_spine
    WHERE cohort_month < STR_TO_DATE('2025-10-01', '%Y-%m-%d')
),

first_purchase_cohort AS ( 
SELECT
	cust_id,
    MIN(DATE(created_at)) AS first_purchase, -- logs First Purchase
	DATE_FORMAT(MIN(DATE(created_at)), '%Y-%m') AS acquisition_cohort -- Time Based Cohort
FROM orders
GROUP BY
	cust_id
),

relative_time_distance AS(
	SELECT
		fpc.*,
        o.quantity AS quantity,
        PERIOD_DIFF(
			DATE_FORMAT(o.`created_at`, '%Y%m'), 
            DATE_FORMAT(fpc.`first_purchase`, '%Y%m')
        ) AS months_since_signup
	FROM first_purchase_cohort fpc
    JOIN orders o
		ON o.cust_id = fpc.cust_id
), 			-- (cust_id, first_purchase, acquisition_cohort, months_since_signup)

cohort_metrics AS (
SELECT
	acquisition_cohort,
    
    -- KPI 1: HEADCOUNT (Counts unique users generated per month)
	COUNT(DISTINCT cust_id) AS customer_acquisition, -- New Customers (equivalent to months_since_signup = 0)
    
	-- KPI 2: RETURNING CUSTOMERS
    
    -- Range Segment 2:
    COUNT(DISTINCT CASE WHEN months_since_signup = 12 THEN cust_id END) AS cust_retained_m12,

    -- Range Segment 3:
    COUNT(DISTINCT CASE WHEN months_since_signup = 24 THEN cust_id END) AS cust_retained_m24,
	
    
	-- KPI 3: RATIOS (HeadCount_12/ HeadCount_m0) i.e. wrt base count (of New Customers)
    
    -- Ratio at m12:

		ROUND(
			(COUNT(DISTINCT CASE WHEN months_since_signup = 12 THEN cust_id END) 
			/ COUNT(DISTINCT cust_id)) *100
		, 2) AS year_2_retention_rate,
    
    
    -- Ratio at m24:
    
		ROUND(
			(COUNT(DISTINCT CASE WHEN months_since_signup = 24 THEN cust_id END) 
			/ COUNT(DISTINCT cust_id)) *100
		, 2) AS year_3_retention_rate

    
FROM relative_time_distance rtd
GROUP BY
	acquisition_cohort
    
)

SELECT
	DATE_FORMAT(cs.cohort_month, '%b-%y') AS acquisition_cohort,
    COALESCE(customer_acquisition, 0) AS new_customers,
    COALESCE(cust_retained_m12, 0) AS cust_retained_m12,
    COALESCE(cust_retained_m24, 0) AS cust_retained_m24,
    year_2_retention_rate AS year_2_retention_percentage, -- Do not coalesce percentages
    year_3_retention_rate AS year_3_retention_percentage --  NULLs can be formatted as clean blanks/dashes in Streamlit.
    
FROM calendar_spine cs
LEFT JOIN cohort_metrics cm
	ON DATE_FORMAT(cs.cohort_month, '%Y-%m') = cm.acquisition_cohort
ORDER BY cs.cohort_month ASC;






-- 4. Discount Sensitivity Profit Impact:

-- How sensitive is profit to price changes?
-- Impact of "Runnng a 10% off coupon campaign this weekend to drive up traffic!" 

-- DISCOUNT SENSITIVITY PROFIT IMPACT
WITH order_level_base AS (
    -- STEP 1: Aggregate sales and ingredients to block relational fan-out
    SELECT 
        DATE(o.created_at) AS _date,
        o.order_id,
        o.item_id,
        MAX(o.quantity * it.item_price * 1.70) AS baseline_item_revenue,
        ROUND(SUM((ing.ing_price / ing.ing_weight) * r.quantity_value * o.quantity), 2) AS item_ingredient_cost
    FROM orders o
    JOIN items it        ON o.item_id = it.item_id
    JOIN recipe r        ON it.sku = r.sku
    JOIN ingredients ing ON r.ingredients = ing.ing_id
    GROUP BY 
		DATE(o.created_at), 
        o.order_id, 
        o.item_id
),

daily_store_revenue_dictionary AS (
    -- STEP 2: Isolate the true, absolute global revenue generated by the store per day
    SELECT 
        _date,
        SUM(baseline_item_revenue) AS global_revenue_daily -- Global Revenue by Date
    FROM order_level_base
    GROUP BY _date
),

daily_payroll_pool AS (  
    SELECT 
        `date` AS _date, 
        SUM(wages) AS daily_wages  -- Global Wages by Date
    FROM `v_daily_payroll` 
    GROUP BY `date`
),

order_line_financial_ledger AS (
    -- STEP 3: Safe M:1 Allocation Layer (Calculates precise item slice of global daily labor)
    SELECT
        ob.item_id,
        ob.baseline_item_revenue, -- 1. Revenue
        ob.item_ingredient_cost,  -- 2. Cost
        
        -- Safe Fraction: (Transaction Line Revenue / Global Store Revenue for that Day) * Daily Wages
        ROUND(
            (ob.baseline_item_revenue / NULLIF(dr.global_revenue_daily, 0)) * dp.daily_wages   -- 3. Wages: (Line Level Revenue / Global Revenue by Date) * Global Wages By Date 
        , 2) AS allocated_labor -- Revenue-Contribution Weighting Vector
    FROM order_level_base ob
    JOIN daily_store_revenue_dictionary dr 
		ON ob._date = dr._date
    JOIN daily_payroll_pool dp             
		ON ob._date = dp._date
)

-- STEP 4: THE HORIZONTAL SENSITIVITY SIMULATION MATRIX
SELECT
    i.item_id,
    i.item_name,
    
    -- Baseline Universe (No Discounts)
    ROUND(SUM(fl.baseline_item_revenue), 2) AS baseline_gross_revenue,
    ROUND(SUM(fl.baseline_item_revenue - fl.item_ingredient_cost - fl.allocated_labor), 2) AS baseline_true_net_profit,
    
    -- Scenario A: Universal 10% Price Discount Impact
    ROUND(SUM(fl.baseline_item_revenue * 0.90), 2) AS discounted_revenue_10pct,
    ROUND(SUM((fl.baseline_item_revenue * 0.90) - fl.item_ingredient_cost - fl.allocated_labor), 2) AS profit_after_10pct_discount,
    
    -- The Sensitivity Velocity Multiplier
    ROUND(
		(SUM((fl.baseline_item_revenue * 0.90) - fl.item_ingredient_cost - fl.allocated_labor) - 
        SUM(fl.baseline_item_revenue - fl.item_ingredient_cost - fl.allocated_labor)) 
        / NULLIF(SUM(fl.baseline_item_revenue - fl.item_ingredient_cost - fl.allocated_labor), 0) * 100
	, 1) AS profit_sensitivity_variance_pct

FROM order_line_financial_ledger fl
JOIN items i ON fl.item_id = i.item_id
GROUP BY 
	i.item_id, 
    i.item_name
ORDER BY 
	baseline_true_net_profit DESC;
    
    
    
    
    
-- ==========================================================
-- 	 MART 6 — Executive Decision Intelligence Mart
-- ===========================================================

-- 1. Revenue Growth Rate (Trend-Based KPI):

-- Business Queston: 
-- Is the business growing, and at what rate over time ?


WITH daily_revenue AS (
    SELECT
        DATE(o.created_at) AS order_date,
        SUM(o.quantity * i.item_price * 1.70) AS revenue
    FROM orders o
    JOIN items i
        ON o.item_id = i.item_id
    GROUP BY DATE(o.created_at)
),

growth AS (
    SELECT
        order_date,
        revenue,

        LAG(revenue) OVER (ORDER BY order_date) AS prev_revenue
    FROM daily_revenue
)

SELECT
    order_date,
    revenue,
    prev_revenue,

    (revenue - prev_revenue) AS revenue_change,

    (revenue - prev_revenue) / NULLIF(prev_revenue, 0) AS growth_rate
FROM growth;




-- 2. ORDER THROUGHPUT VELOCITY (Operational Throughput):

-- Business Question: How fast is the system processing orders over time?

-- ORDER THROUGHPUT VELOCITY:
SELECT
    DATE(created_at) AS order_date,
    
    COUNT(DISTINCT order_id) AS total_orders,
    
    COUNT(*) AS total_order_lines,
    
	 -- Order Density:
    ROUND(COUNT(*) / NULLIF(COUNT(DISTINCT order_id), 0), 2) AS order_line_density_velocity, -- Order DENSITY aka Avg. "Basket Size"

     -- True Velocity: The average number of items packed inside a single order ticket
	COUNT(DISTINCT order_id) AS order_velocity 

FROM orders
GROUP BY 
    DATE(created_at)
ORDER BY 
    order_date ASC;






-- 3. Product Concentration Risk (HHI Index):

-- i.e. GLOBAL ENTERPRISE REVENUE CONCENTRATION (HHI)

-- CREATE VIEW product_risk_exposure AS
WITH product_revenue_contributions AS (
    -- STEP 1:
    SELECT
        o.item_id,
        SUM(o.quantity * i.item_price * 1.70) AS item_lifetime_revenue
    FROM orders o
    JOIN items i ON o.item_id = i.item_id
    GROUP BY o.item_id
),

market_share_matrix AS (
    -- STEP 2: Calculate every item's percentage fraction of the whole company's revenue
    SELECT
        item_id,
        item_lifetime_revenue,
        (item_lifetime_revenue / (SELECT SUM(item_lifetime_revenue) FROM product_revenue_contributions)) * 100 AS market_share_percentage
    FROM product_revenue_contributions
)

-- STEP 3: THE GLOBAL HHI BOARDROOM CALCULATOR
SELECT
	item_id,
    POWER(market_share_percentage, 2) AS risk_component

FROM market_share_matrix;

SELECT
	
    ROUND(
		SUM(risk_component) 
	) AS hhi_product,

    -- Structural Risk Interpretation (DOJ Guidelines)
    CASE 
        WHEN SUM(risk_component) < 1500 THEN 'SAFE: Highly diversified revenue portfolio.'
        WHEN SUM(risk_component) BETWEEN 1500 AND 2500 THEN 'MODERATE CONCENTRATION: Monitor menu dependencies.'
        ELSE 'CRITICAL SYSTEMIC RISK: Revenue highly concentrated! Single point of failure imminent.'
    END AS portfolio_concentration_risk_profile
    
FROM product_risk_exposure;   -- HHI score = 417






-- 4. Supplier Risk Exposure Index:

-- SUPPLY CHAIN RISK EXPOSURE INDEX

-- CREATE VIEW supplier_risk_exposure AS
WITH supplier_spend AS (
    SELECT
        supplier_id,
        SUM(change_qty) AS total_qty
    FROM inventory_transactions
    WHERE transaction_type = 'PURCHASE_ORDER'
    GROUP BY supplier_id
),

total AS (
    SELECT SUM(total_qty) AS grand_total
    FROM supplier_spend
)

SELECT
    s.supplier_id,
    s.total_qty,

    (s.total_qty / t.grand_total) AS supplier_share,  -- supply share is Not used as a Percentage

    POWER((s.total_qty / t.grand_total), 2) AS risk_component  -- Note: We left out SUM() to preserve Row_Wise calculation (Unlike HHI)
FROM supplier_spend s
CROSS JOIN total t;


SELECT
	ROUND(
		SUM(risk_component) * 10000
	) AS hhi_supplier
FROM supplier_risk_exposure sre;  -- HHI score = 2771





-- 5. Business Momentum Score (Composite KPI):

-- Business Question: Is the business growing, and at what rate over time?
-- What is the overall health of the business?


-- ENTERPRISE BUSINESS MOMENTUM SCORECARD
WITH raw_monthly_metrics AS (
    -- STEP 1: Aggregate baseline financial and operational metrics month-by-month
    SELECT
        DATE_FORMAT(DATE(o.created_at), '%Y-%m') AS fiscal_month,
        ROUND(SUM(o.quantity * i.item_price * 1.70), 2) AS gross_sales, -- Metric 1
        COUNT(DISTINCT o.order_id) AS ticket_velocity, -- Metric 2
        COUNT(o.item_id) AS physical_items_cooked -- Metric 3
    FROM orders o
    JOIN items i ON o.item_id = i.item_id
    GROUP BY DATE_FORMAT(DATE(o.created_at), '%Y-%m')
),

historical_momentum_shifts AS (
    -- STEP 2: Use window functions to track month-over-month growth directions
    SELECT
        fiscal_month,
        gross_sales,
        ticket_velocity,
        -- Pull previous month data sideways
        LAG(gross_sales) OVER (ORDER BY fiscal_month ASC) AS prev_sales, -- Metric 1 LAG
        LAG(ticket_velocity) OVER (ORDER BY fiscal_month ASC) AS prev_tickets -- Metric 2 LAG
    FROM raw_monthly_metrics
)

-- STEP 3: THE COMPOSITE CORPORATE HEALTH GRADE MATRIX
SELECT
    fiscal_month,
    gross_sales,  -- Metric 1
    ticket_velocity,  -- Metric 2
    
    -- THE BLENDED PERFORMANCE COMPOSITE SCORE (Standardized scale out of 100)
	-- ax + by + c; a= sales growth rate; b = order volume growth rate; x = 40%, y = 60%, c = +50 (neutral center anchor)
    ROUND(
        ( ( (gross_sales - prev_sales) / NULLIF(prev_sales, 0) * 40 ) + 
          ( (ticket_velocity - prev_tickets) / NULLIF(prev_tickets, 0) * 60 ) + 50 )
    , 1) AS corporate_momentum_index_score, 
    
    -- The Absolute Health Grade
    CASE 
        WHEN ( ( (gross_sales - prev_sales) / NULLIF(prev_sales, 0) * 40 ) + 
			( (ticket_velocity - prev_tickets) / NULLIF(prev_tickets, 0) * 60 ) 
            + 50 ) >= 65.0 
				THEN 'GRADE A: Strong Market Acceleration'
            
        WHEN ( ( (gross_sales - prev_sales) / NULLIF(prev_sales, 0) * 40 ) + 
			( (ticket_velocity - prev_tickets) / NULLIF(prev_tickets, 0) * 60 ) 
            + 50 ) BETWEEN 45.0 AND 64.9 
				THEN 'GRADE B: Stable Maintenance Pace'
        ELSE 'GRADE F: Severe Capital De-acceleration! Review Strategy Dashboard.'
    END AS overall_enterprise_health_grade

FROM historical_momentum_shifts
WHERE prev_sales IS NOT NULL -- Strips the initial baseline setup month for accurate trend plotting
ORDER BY fiscal_month ASC;

-- Metric-3 was omitted from equation to prevent multi-collinearity and tracking redundancy.
-- This metric is heavily co-linear with Metric 2 (ticket_velocity) 
