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