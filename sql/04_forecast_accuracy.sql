-- ============================================================
-- 04_forecast_accuracy.sql
-- FMCG Food Sales & Demand Forecast Analysis
--
-- Цель:
--   Сравнить Current forecast с фактическими продажами
--   и оценить качество прогноза.
--
-- Budget хранится в данных, но для forecast accuracy
-- используется Current — актуальная рабочая версия прогноза.
--
-- Для расчёта KPI используем clean_sales:
--   - quantity > 0;
--   - exact duplicates удаляются через SELECT DISTINCT.
-- ============================================================

-- ------------------------------------------------------------
-- 1. Диагностика: Current forecast без actual
-- ------------------------------------------------------------
-- Это диагностический показатель, а не автоматическая ошибка:
-- sales является sparse fact, поэтому отсутствие строки actual
-- может означать отсутствие продаж в конкретной комбинации.
WITH clean_sales AS (
    SELECT DISTINCT sale_date, product_id, customer_id, quantity, promo_flag
    FROM sales
    WHERE quantity > 0
)
SELECT
    f.forecast_month,
    f.product_id,
    f.customer_id,
    f.forecast_quantity
FROM forecast f
LEFT JOIN clean_sales s
    ON f.forecast_month = s.sale_date
    AND f.product_id = s.product_id
    AND f.customer_id = s.customer_id
WHERE
    f.forecast_version = 'Current'
    AND f.forecast_month >= DATE '2025-01-01'
    AND f.forecast_month <= DATE '2026-06-01'
    AND s.product_id IS NULL
ORDER BY f.forecast_month, f.product_id, f.customer_id;

-- ------------------------------------------------------------
-- 2. Диагностика: actual без Current forecast
-- ------------------------------------------------------------
WITH clean_sales AS (
    SELECT DISTINCT sale_date, product_id, customer_id, quantity, promo_flag
    FROM sales
    WHERE quantity > 0
)
SELECT
    s.sale_date,
    s.product_id,
    s.customer_id,
    s.quantity AS actual_quantity
FROM clean_sales s
LEFT JOIN forecast f
    ON s.sale_date = f.forecast_month
    AND s.product_id = f.product_id
    AND s.customer_id = f.customer_id
    AND f.forecast_version = 'Current'
WHERE
    s.sale_date >= DATE '2025-01-01'
    AND s.sale_date <= DATE '2026-06-01'
    AND f.product_id IS NULL
ORDER BY s.sale_date, s.product_id, s.customer_id;

-- ------------------------------------------------------------
-- 3. Forecast vs Actual + ошибка на уровне строки
-- ------------------------------------------------------------
-- Forecast Error = Forecast - Actual
-- positive -> overforecast; negative -> underforecast.
WITH clean_sales AS (
    SELECT DISTINCT sale_date, product_id, customer_id, quantity, promo_flag
    FROM sales
    WHERE quantity > 0
),
forecast_vs_actual AS (
    SELECT
        f.forecast_month,
        f.product_id,
        f.customer_id,
        f.forecast_quantity,
        s.quantity AS actual_quantity,
        s.promo_flag
    FROM forecast f
    INNER JOIN clean_sales s
        ON f.forecast_month = s.sale_date
        AND f.product_id = s.product_id
        AND f.customer_id = s.customer_id
    WHERE
        f.forecast_version = 'Current'
        AND f.forecast_month >= DATE '2025-01-01'
        AND f.forecast_month <= DATE '2026-06-01'
)
SELECT
    forecast_month,
    product_id,
    customer_id,
    forecast_quantity,
    actual_quantity,
    forecast_quantity - actual_quantity AS forecast_error,
    ABS(forecast_quantity - actual_quantity) AS absolute_error,
    CASE
        WHEN forecast_quantity > actual_quantity THEN 'Overforecast'
        WHEN forecast_quantity < actual_quantity THEN 'Underforecast'
        ELSE 'Exact'
    END AS error_direction
FROM forecast_vs_actual
ORDER BY forecast_month, product_id, customer_id;

-- ------------------------------------------------------------
-- 4. Общий Bias и WAPE
-- ------------------------------------------------------------
-- Bias = SUM(Forecast - Actual) / SUM(Actual) * 100
-- WAPE = SUM(ABS(Forecast - Actual)) / SUM(Actual) * 100
WITH clean_sales AS (
    SELECT DISTINCT sale_date, product_id, customer_id, quantity, promo_flag
    FROM sales
    WHERE quantity > 0
),
forecast_vs_actual AS (
    SELECT f.forecast_quantity, s.quantity AS actual_quantity
    FROM forecast f
    INNER JOIN clean_sales s
        ON f.forecast_month = s.sale_date
        AND f.product_id = s.product_id
        AND f.customer_id = s.customer_id
    WHERE
        f.forecast_version = 'Current'
        AND f.forecast_month >= DATE '2025-01-01'
        AND f.forecast_month <= DATE '2026-06-01'
)
SELECT
    SUM(forecast_quantity) AS total_forecast,
    SUM(actual_quantity) AS total_actual,
    ROUND(100.0 * SUM(forecast_quantity - actual_quantity)
        / NULLIF(SUM(actual_quantity), 0), 2) AS bias_pct,
    ROUND(100.0 * SUM(ABS(forecast_quantity - actual_quantity))
        / NULLIF(SUM(actual_quantity), 0), 2) AS wape_pct
FROM forecast_vs_actual;

-- ------------------------------------------------------------
-- 5. WAPE и Bias по категориям
-- ------------------------------------------------------------
WITH clean_sales AS (
    SELECT DISTINCT sale_date, product_id, customer_id, quantity, promo_flag
    FROM sales
    WHERE quantity > 0
),
forecast_vs_actual AS (
    SELECT f.product_id, f.forecast_quantity, s.quantity AS actual_quantity
    FROM forecast f
    INNER JOIN clean_sales s
        ON f.forecast_month = s.sale_date
        AND f.product_id = s.product_id
        AND f.customer_id = s.customer_id
    WHERE
        f.forecast_version = 'Current'
        AND f.forecast_month >= DATE '2025-01-01'
        AND f.forecast_month <= DATE '2026-06-01'
)
SELECT
    p.category,
    SUM(f.actual_quantity) AS total_actual,
    SUM(f.forecast_quantity) AS total_forecast,
    ROUND(100.0 * SUM(f.forecast_quantity - f.actual_quantity)
        / NULLIF(SUM(f.actual_quantity), 0), 2) AS bias_pct,
    ROUND(100.0 * SUM(ABS(f.forecast_quantity - f.actual_quantity))
        / NULLIF(SUM(f.actual_quantity), 0), 2) AS wape_pct
FROM forecast_vs_actual f
LEFT JOIN products p ON f.product_id = p.product_id
GROUP BY p.category
ORDER BY wape_pct DESC;

-- ------------------------------------------------------------
-- 6. Топ-10 проблемных SKU по абсолютной ошибке
-- ------------------------------------------------------------
WITH clean_sales AS (
    SELECT DISTINCT sale_date, product_id, customer_id, quantity, promo_flag
    FROM sales
    WHERE quantity > 0
),
forecast_vs_actual AS (
    SELECT f.product_id, f.forecast_quantity, s.quantity AS actual_quantity
    FROM forecast f
    INNER JOIN clean_sales s
        ON f.forecast_month = s.sale_date
        AND f.product_id = s.product_id
        AND f.customer_id = s.customer_id
    WHERE
        f.forecast_version = 'Current'
        AND f.forecast_month >= DATE '2025-01-01'
        AND f.forecast_month <= DATE '2026-06-01'
)
SELECT
    p.product_id,
    p.product_name,
    p.category,
    SUM(f.actual_quantity) AS total_actual,
    SUM(f.forecast_quantity) AS total_forecast,
    SUM(ABS(f.forecast_quantity - f.actual_quantity)) AS total_absolute_error,
    ROUND(100.0 * SUM(ABS(f.forecast_quantity - f.actual_quantity))
        / NULLIF(SUM(f.actual_quantity), 0), 2) AS wape_pct
FROM forecast_vs_actual f
LEFT JOIN products p ON f.product_id = p.product_id
GROUP BY p.product_id, p.product_name, p.category
ORDER BY total_absolute_error DESC
LIMIT 10;

-- ------------------------------------------------------------
-- 7. Forecast accuracy: Promo vs Regular
-- ------------------------------------------------------------
WITH clean_sales AS (
    SELECT DISTINCT sale_date, product_id, customer_id, quantity, promo_flag
    FROM sales
    WHERE quantity > 0
),
forecast_vs_actual AS (
    SELECT
        f.forecast_quantity,
        s.quantity AS actual_quantity,
        s.promo_flag
    FROM forecast f
    INNER JOIN clean_sales s
        ON f.forecast_month = s.sale_date
        AND f.product_id = s.product_id
        AND f.customer_id = s.customer_id
    WHERE
        f.forecast_version = 'Current'
        AND f.forecast_month >= DATE '2025-01-01'
        AND f.forecast_month <= DATE '2026-06-01'
)
SELECT
    promo_flag,
    SUM(actual_quantity) AS total_actual,
    SUM(forecast_quantity) AS total_forecast,
    ROUND(100.0 * SUM(forecast_quantity - actual_quantity)
        / NULLIF(SUM(actual_quantity), 0), 2) AS bias_pct,
    ROUND(100.0 * SUM(ABS(forecast_quantity - actual_quantity))
        / NULLIF(SUM(actual_quantity), 0), 2) AS wape_pct
FROM forecast_vs_actual
GROUP BY promo_flag
ORDER BY promo_flag;
