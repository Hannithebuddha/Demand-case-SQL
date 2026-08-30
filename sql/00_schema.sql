-- PostgreSQL schema для портфельного FMCG SQL-кейса

CREATE TABLE products (
    product_id INTEGER PRIMARY KEY,
    product_name VARCHAR(150),
    category VARCHAR(50),
    sub_category VARCHAR(50),
    brand VARCHAR(50),
    pack_size INTEGER,
    launch_date DATE,
    status VARCHAR(30)
);

CREATE TABLE customers (
    customer_id INTEGER PRIMARY KEY,
    customer_name VARCHAR(100),
    channel VARCHAR(50),
    region VARCHAR(50),
    customer_type VARCHAR(30)
);

CREATE TABLE sales (
    sale_date DATE,
    product_id INTEGER,
    customer_id INTEGER,
    quantity INTEGER,
    promo_flag INTEGER
);

CREATE TABLE forecast (
    forecast_month DATE,
    product_id INTEGER,
    customer_id INTEGER,
    forecast_quantity INTEGER,
    forecast_version VARCHAR(20)
);

CREATE TABLE calendar (
    date DATE PRIMARY KEY,
    year INTEGER,
    month INTEGER,
    month_name VARCHAR(20),
    quarter VARCHAR(2)
);
