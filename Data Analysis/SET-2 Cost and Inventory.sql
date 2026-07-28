
-------------------------------------
-- SET B: COST AND INVENTORY
-------------------------------------


USE `restaurant_operations_analytics`;


-- 1. TOTAL QUANTITY CONSUMPTION BY INGREDIENT

SELECT
	it.item_id, -- enrichment
	r.sku, -- enrichment
	r.ingredients AS ing_id,
	SUM(o.quantity * r.quantity_value) AS total_quantity_consumed
FROM orders o
INNER JOIN items it
	ON o.item_id = it.item_id
INNER JOIN recipe r
	ON it.sku = r.sku
GROUP BY
	it.item_id, -- enrichment
	r.ingredients,
    r.sku
ORDER BY it.item_id, r.ingredients;



-- 2. PROCUREMENT DEMAND COST BY INGREDIENT

SELECT
	o.item_id,
	r.ingredients AS ing_id,
	r.quantity_value,
	ing.ing_weight,
	ing.ing_price,
    SUM(o.quantity * r.quantity_value) AS consumed_weight,
    ing_price / ing_weight AS package_cost,
    CEIL(SUM(o.quantity * r.quantity_value) / ing_weight)  * (ing_price ) AS procurement_demand_cost
FROM orders o 
INNER JOIN items it
	ON o.item_id = it.item_id
INNER JOIN recipe r
	ON it.sku = r.sku
INNER JOIN ingredients ing
	ON r.ingredients = ing.ing_id
GROUP BY
	o.item_id,
	r.ingredients,
	r.quantity_value,
	ing.ing_weight,
	ing.ing_price;


-- 3. CALCULATED COST OF PIZZA

SELECT
    it.item_id,
    it.sku,
    it.item_cat,
    r.ingredients AS ing_id,
    SUM((ing_price / ing_weight) * quantity_value) AS row_fract_cost
FROM items it
INNER JOIN recipe r
	ON it.sku = r.sku
INNER JOIN ingredients ing
	ON r.ingredients = ing.ing_id
GROUP BY
    it.item_id,
    it.sku,
    it.item_cat,
    r.ingredients;



-- 4.a PERCENTAGE STOCK REMAINING BY INGREDIENT
-- &&
-- 4.b STOCK UTILIZATION RATE

SELECT
	invd.snapshot_date,
	invd.ing_id,
    invd.ing_name,
    ROUND((invd.closing_stock / invt.stock_levels) * 100, 2) AS percentage_stock_remaining,
    ROUND((invd.consumed_packages / invt.stock_levels) * 100, 2) AS stock_utilization_rate
FROM inventory_daily_snapshot invd
INNER JOIN ingredients ing
	ON invd.ing_id = ing.ing_id  -- '48413'
INNER JOIN inventory invt
	ON ing.ing_id = invt.ing_id  -- '48413'
ORDER BY 
    invd.snapshot_date ASC, 
    invd.ing_id;

-- WHERE snapshot_date IN (
-- 	SELECT MAX(invd.snapshot_date) FROM inventory_daily_snapshot) -- Filtered in Streamlit


-- 5. LIST OF INGREDIENTS TO REORDER (<= 60%)

SELECT
	invd.snapshot_date,
	invd.ing_id,
    invd.ing_name,
    ROUND((invd.closing_stock / invt.stock_levels) * 100, 2) AS percentage_stock_remaining,
    
    CASE
		WHEN ROUND((invd.closing_stock / invt.stock_levels) * 100, 2) <= 60
			AND invd.pending_order = "Y"
			THEN "Order In-Transit"
		WHEN ROUND((invd.closing_stock / invt.stock_levels) * 100, 2) <= 60
			AND invd.pending_order = "N"
			THEN "Re-Order Required"	
        ELSE "OK"
	END AS reorder_flag
        
FROM inventory_daily_snapshot invd
INNER JOIN ingredients ing
	ON invd.ing_id = ing.ing_id  -- '48413'
INNER JOIN inventory invt
	ON ing.ing_id = invt.ing_id  -- '48413'
ORDER BY 
    invd.snapshot_date ASC, 
    invd.ing_id;


    

-- 6. STAFF COST:

CREATE OR REPLACE VIEW v_daily_payroll AS
WITH cte_raw_duration AS (
SELECT 
	ro.`date`,
	sh.shift_id,
	st.staff_id,
	st.first_name,
	st.last_name,
	sh.start_time,
	sh.end_time,
	st.hourly_rate,
	st.max_hours_per_week,
    
    CASE
		WHEN sh.start_time < sh.end_time
        THEN TIMEDIFF(sh.end_time, sh.start_time)
        WHEN sh.start_time > sh.end_time
			AND sh.end_time = '00:00:00'
		THEN TIMEDIFF('24:00:00', sh.start_time)
        ELSE 0
	END AS worked_hours
    
FROM shift sh
INNER JOIN rota ro
	ON sh.shift_id = ro.shift_id
INNER JOIN staff st 
	ON ro.staff_id = st.staff_id
),

cte_payroll_components AS (
SELECT
	cte_raw_duration.*,
    HOUR(worked_hours) AS hours,
    
    FLOOR(
		MINUTE(worked_hours)/15
    ) AS quarters,
    
    -- Round up to an extra quarter if they worked more than 10 minutes past the last quarter
    CASE
		WHEN MINUTE(worked_hours)%15 > 10
		THEN 1
		ELSE 0
	END AS extra_quarters
    
FROM cte_raw_duration
)

SELECT
	`date`,
	shift_id,
	staff_id,
	first_name,
	last_name,
	start_time,
	end_time,
	hourly_rate,
--     max_hours_per_week,
    
    (`hours` + quarters/4 + extra_quarters/4) AS total_hours,
    
    ROUND(
		(`hours` + quarters/4 + extra_quarters/4) * hourly_rate,
	2) AS wages
    
FROM cte_payroll_components -- 15849 Rows
ORDER BY `date`, shift_id, staff_id ASC;




-- 6.b STAFF COST: ALL Weekly Payroll

SELECT
	YEARWEEK(`date`, 1) AS year_week_id,
    staff_id, 
    first_name, 
    last_name, 
	
    SUM(total_hours) AS weekly_hours,
    SUM(wages) AS weekly_wages
    
FROM v_daily_payroll
GROUP BY
	YEARWEEK(`date`, 1),
    staff_id, 
    first_name, 
    last_name; -- '4715' Rows


	
    

-- 6.c STAFF COST: Recent/Latest Weekly Payroll

SELECT
	YEARWEEK(`date`, 1) AS year_week_id,
    staff_id, 
    first_name, 
    last_name, 
	
    SUM(total_hours) AS weekly_hours,
    SUM(wages) AS weekly_wages
    
FROM v_daily_payroll
WHERE YEARWEEK(`date`, 1) = (SELECT MAX(YEARWEEK(`date`, 1)) FROM v_daily_payroll)  -- Recent Payroll 
GROUP BY
	YEARWEEK(`date`, 1),
    staff_id, 
    first_name, 
    last_name; -- '4715' Rows





