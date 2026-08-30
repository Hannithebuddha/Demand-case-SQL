-- ============================================================
-- 03_promo_analysis.sql
-- FMCG Food Sales & Demand Forecast Analysis
--
-- Цель:
--   Оценить, насколько продажи категорий и SKU зависят от промо.
--
-- Для бизнес-KPI используем очищенный факт:
--   - исключаем NULL, нулевые и отрицательные объёмы;
--   - удаляем exact duplicates через SELECT DISTINCT.
-- ============================================================

-- ------------------------------------------------------------
-- 1. Общий объём: promo vs regular
-- ------------------------------------------------------------
WITH clean_sales AS (
    SELECT DISTINCT sale_date, product_id, customer_id, quantity, promo_flag
    FROM sales
    WHERE quantity > 0
)
SELECT
    promo_flag,
    SUM(quantity) AS total_quantity
FROM clean_sales
GROUP BY promo_flag
ORDER BY promo_flag;

-- ------------------------------------------------------------
-- 2. Promo vs regular по категориям
-- ------------------------------------------------------------
WITH clean_sales AS (
    SELECT DISTINCT sale_date, product_id, customer_id, quantity, promo_flag
    FROM sales
    WHERE quantity > 0
)
SELECT
    p.category,
    s.promo_flag,
    SUM(s.quantity) AS total_quantity
FROM clean_sales s
LEFT JOIN products p
    ON s.product_id = p.product_id
GROUP BY p.category, s.promo_flag
ORDER BY p.category, s.promo_flag;

-- ------------------------------------------------------------
-- 3. Доля промо-объёма по категориям
-- ------------------------------------------------------------
WITH clean_sales AS (
    SELECT DISTINCT sale_date, product_id, customer_id, quantity, promo_flag
    FROM sales
    WHERE quantity > 0
)
SELECT
    p.category,
    SUM(CASE WHEN s.promo_flag = 1 THEN s.quantity ELSE 0 END) AS promo_quantity,
    SUM(s.quantity) AS total_quantity,
    ROUND(
        100.0 * SUM(CASE WHEN s.promo_flag = 1 THEN s.quantity ELSE 0 END)
        / NULLIF(SUM(s.quantity), 0),
        2
    ) AS promo_share_pct
FROM clean_sales s
LEFT JOIN products p
    ON s.product_id = p.product_id
GROUP BY p.category
ORDER BY promo_share_pct DESC;

-- ------------------------------------------------------------
-- 4. Доля промо-объёма по SKU
-- ------------------------------------------------------------
WITH clean_sales AS (
    SELECT DISTINCT sale_date, product_id, customer_id, quantity, promo_flag
    FROM sales
    WHERE quantity > 0
)
SELECT
    p.product_id,
    p.product_name,
    p.category,
    SUM(CASE WHEN s.promo_flag = 1 THEN s.quantity ELSE 0 END) AS promo_quantity,
    SUM(s.quantity) AS total_quantity,
    ROUND(
        100.0 * SUM(CASE WHEN s.promo_flag = 1 THEN s.quantity ELSE 0 END)
        / NULLIF(SUM(s.quantity), 0),
        2
    ) AS promo_share_pct
FROM clean_sales s
LEFT JOIN products p
    ON s.product_id = p.product_id
GROUP BY p.product_id, p.product_name, p.category
ORDER BY promo_share_pct DESC;

-- ------------------------------------------------------------
-- 5. Динамика promo / regular по месяцам
-- ------------------------------------------------------------
WITH clean_sales AS (
    SELECT DISTINCT sale_date, product_id, customer_id, quantity, promo_flag
    FROM sales
    WHERE quantity > 0
)
SELECT
    DATE_TRUNC('month', sale_date) AS month,
    promo_flag,
    SUM(quantity) AS total_quantity
FROM clean_sales
GROUP BY DATE_TRUNC('month', sale_date), promo_flag
ORDER BY month, promo_flag;

-- Важно: promo share показывает зависимость объёма от промо,
-- но сам по себе не является оценкой причинного promo uplift.
