-- ============================================================
-- 04_forecast_accuracy.sql
-- FMCG Food Sales & Demand Forecast Analysis
--
-- Цель:
--   Сравнить Current forecast с фактическими продажами
--   и оценить качество прогноза.
--
-- Важно:
--   Budget хранится в данных, но для forecast accuracy
--   используется Current — актуальная рабочая версия прогноза.
-- ============================================================


-- ------------------------------------------------------------
-- 1. Соединение Current forecast с фактом
-- ------------------------------------------------------------
-- Гранулярность сравнения:
-- месяц x продукт x клиент.
--
-- JOIN выполняется сразу по трём ключам.

SELECT
    f.forecast_month,
    f.product_id,
    f.customer_id,
    f.forecast_quantity,
    s.quantity AS actual_quantity
FROM forecast f
LEFT JOIN sales s
    ON f.forecast_month = s.sale_date
    AND f.product_id = s.product_id
    AND f.customer_id = s.customer_id
WHERE
    f.forecast_version = 'Current'
ORDER BY
    f.forecast_month,
    f.product_id,
    f.customer_id;


-- ------------------------------------------------------------
-- 2. Проверка forecast без actual
-- ------------------------------------------------------------
-- Такие строки нельзя автоматически считать ошибкой прогноза:
-- отсутствие факта может быть связано с будущим периодом,
-- отсутствием продаж или проблемой данных.
--
-- Для анализа accuracy ниже используем только закрытый
-- исторический период до 2026-06-01 включительно.

SELECT
    f.forecast_month,
    f.product_id,
    f.customer_id,
    f.forecast_quantity
FROM forecast f
LEFT JOIN sales s
    ON f.forecast_month = s.sale_date
    AND f.product_id = s.product_id
    AND f.customer_id = s.customer_id
WHERE
    f.forecast_version = 'Current'
    AND f.forecast_month <= DATE '2026-06-01'
    AND s.quantity IS NULL
ORDER BY
    f.forecast_month,
    f.product_id,
    f.customer_id;


-- ------------------------------------------------------------
-- 3. Проверка actual без Current forecast
-- ------------------------------------------------------------
-- Здесь меняем направление JOIN:
-- сохраняем весь факт и ищем строки без прогноза.

SELECT
    s.sale_date,
    s.product_id,
    s.customer_id,
    s.quantity AS actual_quantity
FROM sales s
LEFT JOIN forecast f
    ON s.sale_date = f.forecast_month
    AND s.product_id = f.product_id
    AND s.customer_id = f.customer_id
    AND f.forecast_version = 'Current'
WHERE
    s.sale_date >= DATE '2025-01-01'
    AND s.sale_date <= DATE '2026-06-01'
    AND s.quantity IS NOT NULL
    AND f.product_id IS NULL
ORDER BY
    s.sale_date,
    s.product_id,
    s.customer_id;


-- ------------------------------------------------------------
-- 4. Forecast vs Actual + ошибка на уровне строки
-- ------------------------------------------------------------
-- Forecast Error = Forecast - Actual
--
-- Положительная ошибка:
-- forecast > actual -> overforecast
--
-- Отрицательная ошибка:
-- forecast < actual -> underforecast
--
-- Absolute Error показывает размер ошибки без направления.

WITH forecast_vs_actual AS (

    SELECT
        f.forecast_month,
        f.product_id,
        f.customer_id,
        f.forecast_quantity,
        s.quantity AS actual_quantity

    FROM forecast f

    INNER JOIN sales s
        ON f.forecast_month = s.sale_date
        AND f.product_id = s.product_id
        AND f.customer_id = s.customer_id

    WHERE
        f.forecast_version = 'Current'
        AND f.forecast_month <= DATE '2026-06-01'
        AND s.quantity IS NOT NULL
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
ORDER BY
    forecast_month,
    product_id,
    customer_id;


-- ------------------------------------------------------------
-- 5. Общий Bias и WAPE
-- ------------------------------------------------------------
--
-- BIAS:
-- SUM(Forecast - Actual) / SUM(Actual) * 100
--
-- Bias > 0  -> систематический overforecast
-- Bias < 0  -> систематический underforecast
--
-- WAPE:
-- SUM(ABS(Forecast - Actual)) / SUM(Actual) * 100
--
-- Чем ниже WAPE, тем точнее прогноз.
--
-- В отличие от MAPE, WAPE не рассчитывает процентную
-- ошибку отдельно для каждой строки. Поэтому отдельные
-- строки с очень маленьким actual не получают
-- непропорционально большой вес.

WITH forecast_vs_actual AS (

    SELECT
        f.forecast_month,
        f.product_id,
        f.customer_id,
        f.forecast_quantity,
        s.quantity AS actual_quantity

    FROM forecast f

    INNER JOIN sales s
        ON f.forecast_month = s.sale_date
        AND f.product_id = s.product_id
        AND f.customer_id = s.customer_id

    WHERE
        f.forecast_version = 'Current'
        AND f.forecast_month <= DATE '2026-06-01'
        AND s.quantity IS NOT NULL
)

SELECT
    SUM(forecast_quantity) AS total_forecast,
    SUM(actual_quantity) AS total_actual,

    ROUND(
        100.0
        * SUM(forecast_quantity - actual_quantity)
        / NULLIF(SUM(actual_quantity), 0),
        2
    ) AS bias_pct,

    ROUND(
        100.0
        * SUM(ABS(forecast_quantity - actual_quantity))
        / NULLIF(SUM(actual_quantity), 0),
        2
    ) AS wape_pct

FROM forecast_vs_actual;


-- ------------------------------------------------------------
-- 6. WAPE и Bias по категориям
-- ------------------------------------------------------------
-- Это основной диагностический разрез forecast accuracy:
-- он позволяет определить категории, которые создают
-- наибольшую проблему для процесса прогнозирования.

WITH forecast_vs_actual AS (

    SELECT
        f.forecast_month,
        f.product_id,
        f.customer_id,
        f.forecast_quantity,
        s.quantity AS actual_quantity

    FROM forecast f

    INNER JOIN sales s
        ON f.forecast_month = s.sale_date
        AND f.product_id = s.product_id
        AND f.customer_id = s.customer_id

    WHERE
        f.forecast_version = 'Current'
        AND f.forecast_month <= DATE '2026-06-01'
        AND s.quantity IS NOT NULL
)

SELECT
    p.category,
    SUM(f.actual_quantity) AS total_actual,
    SUM(f.forecast_quantity) AS total_forecast,

    ROUND(
        100.0
        * SUM(f.forecast_quantity - f.actual_quantity)
        / NULLIF(SUM(f.actual_quantity), 0),
        2
    ) AS bias_pct,

    ROUND(
        100.0
        * SUM(ABS(f.forecast_quantity - f.actual_quantity))
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
-- 7. Проблемные SKU по абсолютной ошибке
-- ------------------------------------------------------------
-- Для приоритизации используем не только процентную метрику.
-- SKU с небольшой процентной ошибкой, но большим объёмом
-- может создавать больше абсолютной ошибки для бизнеса.

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
        AND f.forecast_month <= DATE '2026-06-01'
        AND s.quantity IS NOT NULL
)

SELECT
    p.product_id,
    p.product_name,
    p.category,
    SUM(f.actual_quantity) AS total_actual,
    SUM(f.forecast_quantity) AS total_forecast,
    SUM(
        ABS(f.forecast_quantity - f.actual_quantity)
    ) AS total_absolute_error,

    ROUND(
        100.0
        * SUM(ABS(f.forecast_quantity - f.actual_quantity))
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


-- ------------------------------------------------------------
-- 8. Forecast accuracy: Promo vs Regular
-- ------------------------------------------------------------
-- Проверяем гипотезу:
-- промо-периоды прогнозируются хуже регулярных продаж.

WITH forecast_vs_actual AS (

    SELECT
        f.forecast_month,
        f.product_id,
        f.customer_id,
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
        AND f.forecast_month <= DATE '2026-06-01'
        AND s.quantity IS NOT NULL
)

SELECT
    promo_flag,
    SUM(actual_quantity) AS total_actual,
    SUM(forecast_quantity) AS total_forecast,

    ROUND(
        100.0
        * SUM(forecast_quantity - actual_quantity)
        / NULLIF(SUM(actual_quantity), 0),
        2
    ) AS bias_pct,

    ROUND(
        100.0
        * SUM(ABS(forecast_quantity - actual_quantity))
        / NULLIF(SUM(actual_quantity), 0),
        2
    ) AS wape_pct

FROM forecast_vs_actual
GROUP BY
    promo_flag
ORDER BY
    promo_flag;


-- ------------------------------------------------------------
-- Что показывает этот блок
-- ------------------------------------------------------------
-- JOIN по нескольким ключам
-- INNER JOIN / LEFT JOIN
-- CTE
-- CASE WHEN
-- ABS
-- SUM
-- GROUP BY
-- NULLIF
-- ROUND
-- фильтрация исторического периода
-- Forecast Error
-- Bias
-- WAPE
-- бизнес-приоритизация ошибок прогноза
-- ============================================================
