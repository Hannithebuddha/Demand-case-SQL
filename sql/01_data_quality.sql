-- ============================================================
-- 01_data_quality.sql
-- FMCG Food Sales & Demand Forecast Analysis
--
-- Цель:
--   1. Понять покрытие и объём данных
--   2. Проверить ключевые поля на пропуски и некорректные значения
--   3. Проверить ожидаемую гранулярность таблицы
--   4. Проверить соответствие справочникам продуктов и клиентов
-- ============================================================


-- ------------------------------------------------------------
-- 1. Базовый профиль таблицы sales
-- ------------------------------------------------------------
-- Смотрим:
--   - минимальную и максимальную дату продаж
--   - количество строк
--   - количество уникальных продуктов
--   - количество уникальных клиентов
--   - NULL в quantity
--   - нулевые и отрицательные quantity

SELECT
    MIN(sale_date) AS min_sale_date,
    MAX(sale_date) AS max_sale_date,
    COUNT(*) AS row_count,
    COUNT(DISTINCT product_id) AS unique_products,
    COUNT(DISTINCT customer_id) AS unique_customers,

    SUM(
        CASE
            WHEN quantity IS NULL THEN 1
            ELSE 0
        END
    ) AS null_quantity_rows,

    SUM(
        CASE
            WHEN quantity = 0 THEN 1
            ELSE 0
        END
    ) AS zero_quantity_rows,

    SUM(
        CASE
            WHEN quantity < 0 THEN 1
            ELSE 0
        END
    ) AS negative_quantity_rows

FROM sales;


-- ------------------------------------------------------------
-- 2. Строки с отсутствующим объёмом
-- ------------------------------------------------------------
-- NULL не удаляем автоматически.
-- Сначала нужно понять, является ли это ошибкой загрузки
-- или отсутствием значения в источнике.

SELECT
    *
FROM sales
WHERE quantity IS NULL
ORDER BY
    sale_date,
    product_id,
    customer_id;


-- ------------------------------------------------------------
-- 3. Нулевые и отрицательные объёмы
-- ------------------------------------------------------------
-- Отрицательный объём не обязательно является ошибкой:
-- это может быть возврат, сторно или корректировка.

SELECT
    *
FROM sales
WHERE quantity <= 0
ORDER BY
    sale_date,
    product_id,
    customer_id;


-- ------------------------------------------------------------
-- 4. Проверка дублей на ожидаемой гранулярности
-- ------------------------------------------------------------
-- Ожидаемая гранулярность sales:
-- одна строка на комбинацию
-- месяц x продукт x клиент

SELECT
    sale_date,
    product_id,
    customer_id,
    COUNT(*) AS row_count
FROM sales
GROUP BY
    sale_date,
    product_id,
    customer_id
HAVING COUNT(*) > 1
ORDER BY
    row_count DESC,
    sale_date,
    product_id,
    customer_id;


-- ------------------------------------------------------------
-- 5. Продукты из sales, которых нет в справочнике products
-- ------------------------------------------------------------

SELECT DISTINCT
    s.product_id
FROM sales s
LEFT JOIN products p
    ON s.product_id = p.product_id
WHERE p.product_id IS NULL
ORDER BY
    s.product_id;


-- ------------------------------------------------------------
-- 6. Клиенты из sales, которых нет в справочнике customers
-- ------------------------------------------------------------

SELECT DISTINCT
    s.customer_id
FROM sales s
LEFT JOIN customers c
    ON s.customer_id = c.customer_id
WHERE c.customer_id IS NULL
ORDER BY
    s.customer_id;


-- ------------------------------------------------------------
-- 7. Продажи до даты запуска продукта
-- ------------------------------------------------------------
-- Проверяем временную логику между sales и products.

SELECT
    s.sale_date,
    s.product_id,
    p.product_name,
    p.launch_date,
    s.customer_id,
    s.quantity
FROM sales s
LEFT JOIN products p
    ON s.product_id = p.product_id
WHERE s.sale_date < p.launch_date
ORDER BY
    s.sale_date,
    s.product_id;


-- ------------------------------------------------------------
-- 8. Проверка версий прогноза
-- ------------------------------------------------------------

SELECT
    forecast_version,
    COUNT(*) AS row_count
FROM forecast
GROUP BY
    forecast_version
ORDER BY
    forecast_version;


-- ------------------------------------------------------------
-- 9. Forecast с отсутствующим продуктом или клиентом в справочниках
-- ------------------------------------------------------------

SELECT
    f.forecast_month,
    f.product_id,
    f.customer_id,
    f.forecast_version
FROM forecast f
LEFT JOIN products p
    ON f.product_id = p.product_id
LEFT JOIN customers c
    ON f.customer_id = c.customer_id
WHERE
    p.product_id IS NULL
    OR c.customer_id IS NULL
ORDER BY
    f.forecast_month,
    f.product_id,
    f.customer_id;


-- ------------------------------------------------------------
-- Что показывает этот блок
-- ------------------------------------------------------------
-- SELECT
-- WHERE
-- COUNT / COUNT DISTINCT
-- MIN / MAX
-- CASE WHEN
-- GROUP BY
-- HAVING
-- LEFT JOIN
-- работа с NULL
-- проверка гранулярности данных
-- ============================================================
