-- ============================================================
-- 02_sales_analysis.sql
-- FMCG Food Sales & Demand Forecast Analysis
--
-- Цель:
--   Исследовать динамику объёмов продаж по времени,
--   категориям, каналам, продуктам и клиентам.
-- ============================================================


-- ------------------------------------------------------------
-- 1. Динамика объёма продаж по месяцам
-- ------------------------------------------------------------

SELECT
    DATE_TRUNC('month', sale_date) AS month,
    SUM(quantity) AS total_quantity
FROM sales
WHERE quantity IS NOT NULL
GROUP BY
    DATE_TRUNC('month', sale_date)
ORDER BY
    month;


-- ------------------------------------------------------------
-- 2. Объём продаж по категориям
-- ------------------------------------------------------------

SELECT
    p.category,
    SUM(s.quantity) AS total_quantity
FROM sales s
LEFT JOIN products p
    ON s.product_id = p.product_id
WHERE s.quantity IS NOT NULL
GROUP BY
    p.category
ORDER BY
    total_quantity DESC;


-- ------------------------------------------------------------
-- 3. Динамика категорий по месяцам
-- ------------------------------------------------------------
-- Используется для поиска сезонности и изменения тренда.

SELECT
    DATE_TRUNC('month', s.sale_date) AS month,
    p.category,
    SUM(s.quantity) AS total_quantity
FROM sales s
LEFT JOIN products p
    ON s.product_id = p.product_id
WHERE s.quantity IS NOT NULL
GROUP BY
    DATE_TRUNC('month', s.sale_date),
    p.category
ORDER BY
    month,
    p.category;


-- ------------------------------------------------------------
-- 4. Объём продаж по каналам
-- ------------------------------------------------------------

SELECT
    c.channel,
    SUM(s.quantity) AS total_quantity
FROM sales s
LEFT JOIN customers c
    ON s.customer_id = c.customer_id
WHERE s.quantity IS NOT NULL
GROUP BY
    c.channel
ORDER BY
    total_quantity DESC;


-- ------------------------------------------------------------
-- 5. Объём продаж по категории и каналу
-- ------------------------------------------------------------

SELECT
    p.category,
    c.channel,
    SUM(s.quantity) AS total_quantity
FROM sales s
LEFT JOIN products p
    ON s.product_id = p.product_id
LEFT JOIN customers c
    ON s.customer_id = c.customer_id
WHERE s.quantity IS NOT NULL
GROUP BY
    p.category,
    c.channel
ORDER BY
    p.category,
    total_quantity DESC;


-- ------------------------------------------------------------
-- 6. Топ-10 SKU по объёму
-- ------------------------------------------------------------

SELECT
    p.product_id,
    p.product_name,
    p.category,
    SUM(s.quantity) AS total_quantity
FROM sales s
LEFT JOIN products p
    ON s.product_id = p.product_id
WHERE s.quantity IS NOT NULL
GROUP BY
    p.product_id,
    p.product_name,
    p.category
ORDER BY
    total_quantity DESC
LIMIT 10;


-- ------------------------------------------------------------
-- 7. Годовой объём по категориям
-- ------------------------------------------------------------
-- YoY не рассчитываем через LAG.
-- Получаем годовые агрегаты, которые можно сравнить
-- в итоговом аналитическом выводе.

SELECT
    EXTRACT(YEAR FROM s.sale_date) AS year,
    p.category,
    SUM(s.quantity) AS total_quantity
FROM sales s
LEFT JOIN products p
    ON s.product_id = p.product_id
WHERE s.quantity IS NOT NULL
GROUP BY
    EXTRACT(YEAR FROM s.sale_date),
    p.category
ORDER BY
    year,
    p.category;


-- ------------------------------------------------------------
-- 8. Годовой объём по SKU
-- ------------------------------------------------------------

SELECT
    EXTRACT(YEAR FROM s.sale_date) AS year,
    p.product_id,
    p.product_name,
    p.category,
    SUM(s.quantity) AS total_quantity
FROM sales s
LEFT JOIN products p
    ON s.product_id = p.product_id
WHERE s.quantity IS NOT NULL
GROUP BY
    EXTRACT(YEAR FROM s.sale_date),
    p.product_id,
    p.product_name,
    p.category
ORDER BY
    p.product_id,
    year;


-- ------------------------------------------------------------
-- 9. Новые продукты
-- ------------------------------------------------------------

SELECT
    product_id,
    product_name,
    category,
    launch_date,
    status
FROM products
WHERE launch_date >= DATE '2025-01-01'
ORDER BY
    launch_date,
    category,
    product_id;


-- ------------------------------------------------------------
-- 10. Discontinued продукты
-- ------------------------------------------------------------

SELECT
    product_id,
    product_name,
    category,
    launch_date,
    status
FROM products
WHERE status = 'Discontinued'
ORDER BY
    category,
    product_id;


-- ------------------------------------------------------------
-- 11. Годовая динамика клиентов
-- ------------------------------------------------------------
-- Помогает увидеть клиентов с растущим или падающим объёмом.

SELECT
    EXTRACT(YEAR FROM s.sale_date) AS year,
    c.customer_id,
    c.customer_name,
    c.channel,
    SUM(s.quantity) AS total_quantity
FROM sales s
LEFT JOIN customers c
    ON s.customer_id = c.customer_id
WHERE s.quantity IS NOT NULL
GROUP BY
    EXTRACT(YEAR FROM s.sale_date),
    c.customer_id,
    c.customer_name,
    c.channel
ORDER BY
    c.customer_id,
    year;


-- ------------------------------------------------------------
-- Что показывает этот блок
-- ------------------------------------------------------------
-- JOIN
-- SUM
-- GROUP BY
-- ORDER BY
-- LIMIT
-- DATE_TRUNC
-- EXTRACT
-- анализ в нескольких бизнес-разрезах
-- ============================================================
