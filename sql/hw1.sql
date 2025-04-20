-- Създаване новата база
CREATE DATABASE WOODCHUCK_ECOMERSE_DB; 
USE DATABASE WOODCHUCK_ECOMERSE_DB; 
-- 

-- Създаване схемата за външни данни
CREATE SCHEMA WOODCHUCK_ECOMERSE_DB.STAGE_EXTERNAL;
USE SCHEMA WOODCHUCK_ECOMERSE_DB.STAGE_EXTERNAL;
-- 

-- Създаване на stage (папка) за файла
CREATE STAGE WOODCHUCK_ECOMERSE_DB.STAGE_EXTERNAL.stage_orders;
-- 

-- Създаване на схемата с началните стойности на таблиците
CREATE SCHEMA WOODCHUCK_ECOMERSE_DB.INIT_DATA;

USE SCHEMA WOODCHUCK_ECOMERSE_DB.STAGE_EXTERNAL;
-- 


-- Създаване на файлов формат, защото Shipping_Address е гаден
CREATE OR REPLACE FILE FORMAT WOODCHUCK_ECOMERSE_DB.STAGE_EXTERNAL.csv_orders
    TYPE = 'CSV'
    FIELD_OPTIONALLY_ENCLOSED_BY = '"'
    SKIP_HEADER = 1;
-- 

-- Тествам дали и как работи файлов формат
SELECT $1, $2, $3
FROM @stage_orders/ecommerce_orders
(FILE_FORMAT => 'csv_orders');
-- 

-- Създаване на таблица директно от csv файла с данни.
CREATE OR REPLACE TABLE WOODCHUCK_ECOMERSE_DB.INIT_DATA.ecommerce_orders AS
    SELECT  $1 AS order_id, 
            $2 AS customer_id, 
            $3 AS customer_name, 
            $4 AS order_date, 
            $5 AS product, 
            $6 AS quantity,
            $7 AS price, 
            $8 AS discount, 
            $9 AS total_amount, 
            $10 AS payment_method, 
            $11 AS shipping_address, 
            $12 AS status
    FROM @stage_orders/ecommerce_orders
    (FILE_FORMAT => 'csv_orders');
-- 

-- Проверявам дали заявката ще сработи 
SELECT order_id,shipping_address,status
FROM WOODCHUCK_ECOMERSE_DB.INIT_DATA.ECOMMERCE_ORDERS
WHERE shipping_address is null and status = 'Delivered';
-- 

-- Поставям работещата заявка в нова таблица, за решение на задачата
CREATE OR REPLACE TABLE WOODCHUCK_ECOMERSE_DB.INIT_DATA.td_for_review AS
    SELECT *
    FROM WOODCHUCK_ECOMERSE_DB.INIT_DATA.ECOMMERCE_ORDERS
    WHERE shipping_address is null and status = 'Delivered'
-- 
    
-- Проверявам дали таблицата работи
SELECT *
FROM WOODCHUCK_ECOMERSE_DB.INIT_DATA.td_for_review;
-- 

-- Създавам нова таблица, за съмнителни потребители.
CREATE OR REPLACE TABLE WOODCHUCK_ECOMERSE_DB.INIT_DATA.td_suspisios_records AS
    SELECT *
    FROM WOODCHUCK_ECOMERSE_DB.INIT_DATA.ECOMMERCE_ORDERS
    WHERE customer_name is null;
-- 

-- Проверявам отново дали работи.
SELECT *
FROM WOODCHUCK_ECOMERSE_DB.INIT_DATA.td_suspisios_records
-- 

-- Създавам нова схема и нова таблица, за предстоящото модифициране на данни.
CREATE SCHEMA WOODCHUCK_ECOMERSE_DB.MODIFIED_DATA;
CREATE TABLE WOODCHUCK_ECOMERSE_DB.MODIFIED_DATA.ECOMMERCE_ORDERS CLONE WOODCHUCK_ECOMERSE_DB.INIT_DATA.ECOMMERCE_ORDERS;
-- 

-- Обновявам данните в базата, да показва Unknown за неналична информация за плащане.
UPDATE WOODCHUCK_ECOMERSE_DB.MODIFIED_DATA.ECOMMERCE_ORDERS  
    SET PAYMENT_METHOD = 'Unknown' 
    WHERE PAYMENT_METHOD is null;
-- 
    
-- Създавам таблица за невалидна цена на поръчката
CREATE TABLE WOODCHUCK_ECOMERSE_DB.MODIFIED_DATA.NEGATIVE_PRICE_ORDERS AS
    SELECT *
    FROM WOODCHUCK_ECOMERSE_DB.MODIFIED_DATA.ECOMMERCE_ORDERS
    WHERE total_amount < 0 AND quantity < 0;
-- 
    
-- Трия от таблицата полетата с невалидни цени на поръчките.
DELETE FROM WOODCHUCK_ECOMERSE_DB.MODIFIED_DATA.ECOMMERCE_ORDERS
WHERE total_amount < 0 AND quantity < 0;
-- 

-- Проверявам за грешни намаления, и ако има, ги поправям.
SELECT *
FROM WOODCHUCK_ECOMERSE_DB.MODIFIED_DATA.ECOMMERCE_ORDERS
WHERE discount < 0 or discount>0.5

UPDATE WOODCHUCK_ECOMERSE_DB.MODIFIED_DATA.ECOMMERCE_ORDERS
SET DISCOUNT = 0.50
WHERE discount > 0.5;

UPDATE WOODCHUCK_ECOMERSE_DB.MODIFIED_DATA.ECOMMERCE_ORDERS
SET DISCOUNT = 0
WHERE discount < 0;
-- 

-- Оправям цената на поръчките.
UPDATE WOODCHUCK_ECOMERSE_DB.MODIFIED_DATA.ECOMMERCE_ORDERS
SET TOTAL_AMOUNT = QUANTITY*PRICE*DISCOUNT
WHERE DISCOUNT != 0;
-- 

-- Оправяне на грешно "доставени" поръчки
SELECT *
FROM WOODCHUCK_ECOMERSE_DB.MODIFIED_DATA.ECOMMERCE_ORDERS
WHERE SHIPPING_ADDRESS is null AND status = 'Pending';

UPDATE WOODCHUCK_ECOMERSE_DB.MODIFIED_DATA.ECOMMERCE_ORDERS
SET STATUS = 'Pending'
WHERE SHIPPING_ADDRESS is null AND status = 'Delivered';
-- 

-- Премахване на дублиращи се редове
CREATE TABLE WOODCHUCK_ECOMERSE_DB.MODIFIED_DATA.td_clean_records AS
SELECT DISTINCT *
FROM WOODCHUCK_ECOMERSE_DB.MODIFIED_DATA.ECOMMERCE_ORDERS;

SELECT count(*)
FROM WOODCHUCK_ECOMERSE_DB.MODIFIED_DATA.ECOMMERCE_ORDERS;

SELECT count(*)
FROM WOODCHUCK_ECOMERSE_DB.MODIFIED_DATA.td_clean_records
WHERE ORDER_DATE not like '____-__-__'
