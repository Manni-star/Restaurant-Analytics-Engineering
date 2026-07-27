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

