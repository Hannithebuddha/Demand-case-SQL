-- ============================================================
-- 05_business_insights.sql
-- FMCG Food Sales & Demand Forecast Analysis
--
-- Цель:
--   Собрать несколько финальных выборок, на основании которых
--   формулируются бизнес-выводы проекта.
--
-- Важно:
--   2026 год содержит факт только за январь-июнь.
--   Поэтому годовую динамику 2024 vs 2025 сравниваем на полном году,
--   а forecast accuracy анализируем отдельно на закрытом периоде.
-- ============================================================


-- ------------------------------------------------------------
-- 1. Полный год: 2024 vs 2025 по категориям
-- ------------------------------------------------------------

SELECT
    EXTRACT(YEAR FROM s.sale_date) AS year,
    p.category,
    SUM(s.quantity) AS total_quantity
FROM sales s
LEFT JOIN products p
    ON s.product_id = p.product_id
WHERE
    s.quantity > 0
    AND EXTRACT(YEAR FROM s.sale_date) IN (2024, 2025)
GROUP BY
    EXTRACT(YEAR FROM s.sale_date),
    p.category
ORDER BY
    p.category,
    year;


-- ------------------------------------------------------------
-- 2. Промо-зависимость категорий
-- ------------------------------------------------------------

SELECT
    p.category,
    SUM(CASE WHEN s.promo_flag = 1 THEN s.quantity ELSE 0 END) AS promo_quantity,
    SUM(s.quantity) AS total_quantity,

    ROUND(
        100.0 * SUM(CASE WHEN s.promo_flag = 1 THEN s.quantity ELSE 0 END)
        / NULLIF(SUM(s.quantity), 0),
        2
    ) AS promo_share_pct

FROM sales s
LEFT JOIN products p
    ON s.product_id = p.product_id
WHERE s.quantity > 0
GROUP BY
    p.category
ORDER BY
    promo_share_pct DESC;


-- ------------------------------------------------------------
-- 3. Forecast accuracy по категориям
-- ------------------------------------------------------------

WITH forecast_vs_actual AS (

    SELECT
        f.product_id,
        f.forecast_quantity,
        s.quantity AS actual_quantity

    FROM forecast f
    INNER JOIN sales s
        ON f.forecast_month = s.sale_date
        AND f.product_id = s.product_id
        AND f.customer_id = s.customer_id

    WHERE
        f.forecast_version = 'Current'
        AND f.forecast_month >= DATE '2025-01-01'
        AND f.forecast_month <= DATE '2026-06-01'
        AND s.quantity > 0
)

SELECT
    p.category,
    SUM(f.actual_quantity) AS total_actual,
    SUM(f.forecast_quantity) AS total_forecast,

    ROUND(
        100.0 * SUM(f.forecast_quantity - f.actual_quantity)
        / NULLIF(SUM(f.actual_quantity), 0),
        2
    ) AS bias_pct,

    ROUND(
        100.0 * SUM(ABS(f.forecast_quantity - f.actual_quantity))
        / NULLIF(SUM(f.actual_quantity), 0),
        2
    ) AS wape_pct

FROM forecast_vs_actual f
LEFT JOIN products p
    ON f.product_id = p.product_id
GROUP BY
    p.category
ORDER BY
    wape_pct DESC;


-- ------------------------------------------------------------
-- 4. Promo vs Regular: качество прогноза
-- ------------------------------------------------------------

WITH forecast_vs_actual AS (

    SELECT
        f.forecast_quantity,
        s.quantity AS actual_quantity,
        s.promo_flag

    FROM forecast f
    INNER JOIN sales s
        ON f.forecast_month = s.sale_date
        AND f.product_id = s.product_id
        AND f.customer_id = s.customer_id

    WHERE
        f.forecast_version = 'Current'
        AND f.forecast_month >= DATE '2025-01-01'
        AND f.forecast_month <= DATE '2026-06-01'
        AND s.quantity > 0
)

SELECT
    promo_flag,

    ROUND(
        100.0 * SUM(forecast_quantity - actual_quantity)
        / NULLIF(SUM(actual_quantity), 0),
        2
    ) AS bias_pct,

    ROUND(
        100.0 * SUM(ABS(forecast_quantity - actual_quantity))
        / NULLIF(SUM(actual_quantity), 0),
        2
    ) AS wape_pct

FROM forecast_vs_actual
GROUP BY
    promo_flag
ORDER BY
    promo_flag;


-- ------------------------------------------------------------
-- 5. Топ-10 SKU по абсолютной ошибке прогноза
-- ------------------------------------------------------------

WITH forecast_vs_actual AS (

    SELECT
        f.product_id,
        f.forecast_quantity,
        s.quantity AS actual_quantity

    FROM forecast f
    INNER JOIN sales s
        ON f.forecast_month = s.sale_date
        AND f.product_id = s.product_id
        AND f.customer_id = s.customer_id

    WHERE
        f.forecast_version = 'Current'
        AND f.forecast_month >= DATE '2025-01-01'
        AND f.forecast_month <= DATE '2026-06-01'
        AND s.quantity > 0
)

SELECT
    p.product_id,
    p.product_name,
    p.category,
    SUM(ABS(f.forecast_quantity - f.actual_quantity)) AS total_absolute_error,

    ROUND(
        100.0 * SUM(ABS(f.forecast_quantity - f.actual_quantity))
        / NULLIF(SUM(f.actual_quantity), 0),
        2
    ) AS wape_pct

FROM forecast_vs_actual f
LEFT JOIN products p
    ON f.product_id = p.product_id
GROUP BY
    p.product_id,
    p.product_name,
    p.category
ORDER BY
    total_absolute_error DESC
LIMIT 10;
