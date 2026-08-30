-- ============================================================
-- 03_promo_analysis.sql
-- FMCG Food Sales & Demand Forecast Analysis
--
-- Цель:
--   Оценить, насколько продажи категорий и SKU зависят от промо.
-- ============================================================


-- ------------------------------------------------------------
-- 1. Общий объём: promo vs regular
-- ------------------------------------------------------------

SELECT
    promo_flag,
    SUM(quantity) AS total_quantity
FROM sales
WHERE quantity IS NOT NULL
GROUP BY
    promo_flag
ORDER BY
    promo_flag;


-- ------------------------------------------------------------
-- 2. Promo vs regular по категориям
-- ------------------------------------------------------------

SELECT
    p.category,
    s.promo_flag,
    SUM(s.quantity) AS total_quantity
FROM sales s
LEFT JOIN products p
    ON s.product_id = p.product_id
WHERE s.quantity IS NOT NULL
GROUP BY
    p.category,
    s.promo_flag
ORDER BY
    p.category,
    s.promo_flag;


-- ------------------------------------------------------------
-- 3. Доля промо-объёма по категориям
-- ------------------------------------------------------------
-- Conditional aggregation:
-- в числителе суммируем только строки promo_flag = 1,
-- в знаменателе — весь объём категории.
--
-- NULLIF защищает от деления на ноль.

SELECT
    p.category,

    SUM(
        CASE
            WHEN s.promo_flag = 1 THEN s.quantity
            ELSE 0
        END
    ) AS promo_quantity,

    SUM(s.quantity) AS total_quantity,

    ROUND(
        100.0
        * SUM(
            CASE
                WHEN s.promo_flag = 1 THEN s.quantity
                ELSE 0
            END
        )
        / NULLIF(SUM(s.quantity), 0),
        2
    ) AS promo_share_pct

FROM sales s
LEFT JOIN products p
    ON s.product_id = p.product_id
WHERE s.quantity IS NOT NULL
GROUP BY
    p.category
ORDER BY
    promo_share_pct DESC;


-- ------------------------------------------------------------
-- 4. Доля промо-объёма по SKU
-- ------------------------------------------------------------
-- Позволяет найти продукты с наиболее высокой
-- зависимостью от промо-продаж.

SELECT
    p.product_id,
    p.product_name,
    p.category,

    SUM(
        CASE
            WHEN s.promo_flag = 1 THEN s.quantity
            ELSE 0
        END
    ) AS promo_quantity,

    SUM(s.quantity) AS total_quantity,

    ROUND(
        100.0
        * SUM(
            CASE
                WHEN s.promo_flag = 1 THEN s.quantity
                ELSE 0
            END
        )
        / NULLIF(SUM(s.quantity), 0),
        2
    ) AS promo_share_pct

FROM sales s
LEFT JOIN products p
    ON s.product_id = p.product_id
WHERE s.quantity IS NOT NULL
GROUP BY
    p.product_id,
    p.product_name,
    p.category
ORDER BY
    promo_share_pct DESC;


-- ------------------------------------------------------------
-- 5. Динамика promo / regular по месяцам
-- ------------------------------------------------------------

SELECT
    DATE_TRUNC('month', sale_date) AS month,
    promo_flag,
    SUM(quantity) AS total_quantity
FROM sales
WHERE quantity IS NOT NULL
GROUP BY
    DATE_TRUNC('month', sale_date),
    promo_flag
ORDER BY
    month,
    promo_flag;


-- ------------------------------------------------------------
-- Что показывает этот блок
-- ------------------------------------------------------------
-- CASE WHEN
-- conditional aggregation
-- GROUP BY
-- JOIN
-- NULLIF
-- ROUND
-- DATE_TRUNC
-- анализ промо-зависимости
-- ============================================================
