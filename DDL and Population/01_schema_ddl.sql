-- RESTAURANT ANALYSIS

USE `restaurant_operations_analytics`;

CREATE TABLE `orders` (
    `order_id` int  NOT NULL ,
    `created_at` datetime  NOT NULL ,
    `item_id` varchar(20)  NOT NULL ,
    `quantity` int  NOT NULL ,
    `delivery` varchar(10)  NOT NULL ,
    `cust_id` int  NOT NULL ,
    `add_id` int  NOT NULL ,
    `shift_id` varchar(20)  NOT NULL ,
    PRIMARY KEY (
        `order_id`
    )
);

CREATE TABLE `items` (
    `item_id` varchar(20)  NOT NULL ,
    `sku` varchar(20)  NOT NULL ,
    `item_name` varchar(50)  NOT NULL ,
    `item_cat` varchar(50)  NOT NULL ,
    `item_size` varchar(50)  NOT NULL ,
    PRIMARY KEY (
        `item_id`
    )
);

CREATE TABLE `ingredients` (
    `ing_id` varchar(70)  NOT NULL ,
    `ing_name` varchar(50)  NOT NULL ,
    `ing_weight` int  NOT NULL ,
    `ing_meas` varchar(10)  NOT NULL ,
    `ing_price` int  NOT NULL ,
    PRIMARY KEY (
        `ing_id`
    )
);

CREATE TABLE `recipe` (
    `row_id` int  NOT NULL ,
    `sku` varchar(20)  NOT NULL ,
    `ingredients` varchar(70)  NOT NULL ,
    `quantity_value` int  NOT NULL ,
    `quantity_unit` varchar(20)  NOT NULL ,
    PRIMARY KEY (
        `row_id`
    )
);

CREATE TABLE `inventory` (
    `inv_id` varchar(20)  NOT NULL ,
    `ing_id` varchar(70)  NOT NULL ,
    `stock_levels` int  NOT NULL ,
    `reorder_point_packages` int  NOT NULL ,
    PRIMARY KEY (
        `inv_id`
    )
);

CREATE TABLE `customers` (
    `cust_id` int  NOT NULL ,
    `cust_firstname` varchar(50)  NOT NULL ,
    `cust_lastname` varchar(50)  NOT NULL ,
    PRIMARY KEY (
        `cust_id`
    )
);

CREATE TABLE `address` (
    `add_id` int  NOT NULL ,
    `delivery_address` varchar(100)  NOT NULL ,
    `delivery_city` varchar(50)  NOT NULL ,
    `delivery_zipcode` varchar(10)  NOT NULL ,
    PRIMARY KEY (
        `add_id`
    )
);

CREATE TABLE `shift` (
    `shift_id` varchar(20)  NOT NULL ,
    `day_of_week` varchar(20)  NOT NULL ,
    `start_time` TIME  NOT NULL ,
    `end_time` TIME  NOT NULL ,
    PRIMARY KEY (
        `shift_id`
    )
);

CREATE TABLE `staff` (
    `staff_id` varchar(20)  NOT NULL ,
    `first_name` varchar(50)  NOT NULL ,
    `last_name` varchar(50)  NOT NULL ,
    `position` varchar(50)  NOT NULL ,
    `hourly_rate` int  NOT NULL ,
    `employment_type` varchar(50)  NOT NULL ,
    `max_hours_per_week` int  NOT NULL ,
    PRIMARY KEY (
        `staff_id`
    )
);

CREATE TABLE `rota` (
    `row_id` int  NOT NULL ,
    `rota_id` varchar(20)  NOT NULL ,
    `date` DATE  NOT NULL ,
    `shift_id` varchar(20)  NOT NULL ,
    `staff_id` varchar(20)  NOT NULL ,
    PRIMARY KEY (
        `row_id`
    )
);

CREATE TABLE `suppliers` (
    `supplier_id` varchar(70)  NOT NULL ,
    `supplier_name` varchar(70)  NOT NULL ,
    `specialization` varchar(100)  NOT NULL ,
    PRIMARY KEY (
        `supplier_id`
    )
);

CREATE TABLE `ingredients_supplier` (
    `ing_sup_id` varchar(70)  NOT NULL ,
    `ing_id` varchar(70)  NOT NULL ,
    `ing_name` varchar(70)  NOT NULL ,
    `supplier_id` varchar(70)  NOT NULL ,
    `lead_time` int  NOT NULL ,
    PRIMARY KEY (
        `ing_sup_id`
    )
);

CREATE TABLE `inventory_transactions` (
    `transaction_id` varchar(20)  NOT NULL ,
    `ing_id` varchar(70)  NOT NULL ,
    `transaction_date` date  NOT NULL ,
    `transaction_type` varchar(50)  NOT NULL ,
    `change_qty` int  NOT NULL ,
    `supplier_id` varchar(70)  NOT NULL ,
    PRIMARY KEY (
        `transaction_id`
    )
);

CREATE TABLE `inventory_daily_snapshot` (
    `snap_id` varchar(20)  NOT NULL ,
    `snapshot_date` date  NOT NULL ,
    `ing_id` varchar(70)  NOT NULL ,
    `ing_name` varchar(50)  NOT NULL ,
    `opening_stock` int  NOT NULL ,
    `consumed_packages` int  NOT NULL ,
    `closing_stock` int  NOT NULL ,
    `pending_order` varchar(10)  NOT NULL ,
    PRIMARY KEY (
        `snap_id`
    )
);



ALTER TABLE `orders` ADD CONSTRAINT `fk-orders-items-item_id` FOREIGN KEY(`item_id`)
REFERENCES `items` (`item_id`);

ALTER TABLE `orders` ADD CONSTRAINT `fk-orders-customers-cust_id` FOREIGN KEY(`cust_id`)
REFERENCES `customers` (`cust_id`);

ALTER TABLE `orders` ADD CONSTRAINT `fk-orders-address-add_id` FOREIGN KEY(`add_id`)
REFERENCES `address` (`add_id`);

ALTER TABLE `orders` ADD CONSTRAINT `fk-orders-shift-shift_id` FOREIGN KEY(`shift_id`)
REFERENCES `shift` (`shift_id`);

ALTER TABLE `recipe` ADD CONSTRAINT `fk-recipe-items-sku` FOREIGN KEY(`sku`)
REFERENCES `items` (`sku`);

ALTER TABLE `recipe` ADD CONSTRAINT `fk-recipe-ingredients-ingredients\ing_id` FOREIGN KEY(`ingredients`)
REFERENCES `ingredients` (`ing_id`);

ALTER TABLE `inventory` ADD CONSTRAINT `fk-inventory-ingredients-ing_id` FOREIGN KEY(`ing_id`)
REFERENCES `ingredients` (`ing_id`);

ALTER TABLE `rota` ADD CONSTRAINT `fk-rota-shift-shift_id` FOREIGN KEY(`shift_id`)
REFERENCES `shift` (`shift_id`);

ALTER TABLE `rota` ADD CONSTRAINT `fk-rota-staff-staff_id` FOREIGN KEY(`staff_id`)
REFERENCES `staff` (`staff_id`);

ALTER TABLE `ingredients_supplier` ADD CONSTRAINT `fk-ingredients_supplier-ingredients-ing_id` FOREIGN KEY(`ing_id`)
REFERENCES `ingredients` (`ing_id`);

ALTER TABLE `ingredients_supplier` ADD CONSTRAINT `fk-ingredients_supplier-suppliers-supplier_id` FOREIGN KEY(`supplier_id`)
REFERENCES `suppliers` (`supplier_id`);

ALTER TABLE `inventory_transactions` ADD CONSTRAINT `fk-inventory_transactions-ingredients-ing_id` FOREIGN KEY(`ing_id`)
REFERENCES `ingredients` (`ing_id`);

ALTER TABLE `inventory_transactions` ADD CONSTRAINT `fk-inventory_transactions-suppliers-supplier_id` FOREIGN KEY(`supplier_id`)
REFERENCES `suppliers` (`supplier_id`);

ALTER TABLE `inventory_daily_snapshot` ADD CONSTRAINT `fk-inventory_daily_snapshot-ingredients-ing_id` FOREIGN KEY(`ing_id`)
REFERENCES `ingredients` (`ing_id`);

