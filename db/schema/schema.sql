--
-- PostgreSQL database dump
--


-- Dumped from database version 17.11 (Homebrew)
-- Dumped by pg_dump version 17.11 (Homebrew)

-- Started on 2026-11-13 20:22:59 MSK

SET statement_timeout = 0;
SET lock_timeout = 0;
SET idle_in_transaction_session_timeout = 0;
SET transaction_timeout = 0;
SET client_encoding = 'UTF8';
SET standard_conforming_strings = on;
SELECT pg_catalog.set_config('search_path', '', false);
SET check_function_bodies = false;
SET xmloption = content;
SET client_min_messages = warning;
SET row_security = off;

--
-- TOC entry 9 (class 2615 OID 16785)
-- Name: levichev_food; Type: SCHEMA; Schema: -
--

CREATE SCHEMA levichev_food;


--
-- TOC entry 904 (class 1247 OID 16800)
-- Name: courier_status; Type: TYPE; Schema: levichev_food
--

CREATE TYPE levichev_food.courier_status AS ENUM (
    'свободен',
    'занят',
    'на_доставке',
    'уволен'
);


--
-- TOC entry 910 (class 1247 OID 16822)
-- Name: order_pay_status; Type: TYPE; Schema: levichev_food
--

CREATE TYPE levichev_food.order_pay_status AS ENUM (
    'ожидает',
    'оплачен',
    'ошибка'
);


--
-- TOC entry 907 (class 1247 OID 16810)
-- Name: order_status; Type: TYPE; Schema: levichev_food
--

CREATE TYPE levichev_food.order_status AS ENUM (
    'создан',
    'готовится',
    'в_доставке',
    'доставлен',
    'отменён'
);


--
-- TOC entry 916 (class 1247 OID 16838)
-- Name: payment_status; Type: TYPE; Schema: levichev_food
--

CREATE TYPE levichev_food.payment_status AS ENUM (
    'успех',
    'ошибка',
    'в_обработке'
);


--
-- TOC entry 913 (class 1247 OID 16830)
-- Name: payment_type; Type: TYPE; Schema: levichev_food
--

CREATE TYPE levichev_food.payment_type AS ENUM (
    'карта',
    'наличные',
    'безнал'
);


--
-- TOC entry 901 (class 1247 OID 16792)
-- Name: product_status; Type: TYPE; Schema: levichev_food
--

CREATE TYPE levichev_food.product_status AS ENUM (
    'доступно',
    'нет_в_наличии',
    'архив'
);


--
-- TOC entry 898 (class 1247 OID 16787)
-- Name: restaurant_status; Type: TYPE; Schema: levichev_food
--

CREATE TYPE levichev_food.restaurant_status AS ENUM (
    'активен',
    'неактивен'
);


--
-- TOC entry 919 (class 1247 OID 16846)
-- Name: review_entity_type; Type: TYPE; Schema: levichev_food
--

CREATE TYPE levichev_food.review_entity_type AS ENUM (
    'блюдо',
    'ресторан',
    'заказ'
);


--
-- TOC entry 277 (class 1255 OID 17241)
-- Name: add_product(character varying, uuid, numeric, uuid, text, numeric, levichev_food.product_status, text); Type: PROCEDURE; Schema: levichev_food
--

CREATE PROCEDURE levichev_food.add_product(IN p_product_name character varying, IN p_product_category_id uuid, IN p_price numeric, IN p_restaurant_id uuid, IN p_photo_url text, IN p_rating numeric, IN p_status levichev_food.product_status, IN p_description text)
    LANGUAGE plpgsql
    AS $$
BEGIN
    IF NOT EXISTS (
        SELECT 1
        FROM levichev_food.restaurant
        WHERE restaurant_id = p_restaurant_id
    ) THEN
        RAISE EXCEPTION
            'Ресторан с ID % не существует',
            p_restaurant_id;
    END IF;

    IF NOT EXISTS (
        SELECT 1
        FROM levichev_food.product_category
        WHERE product_category_id = p_product_category_id
    ) THEN
        RAISE EXCEPTION
            'Категория с ID % не существует',
            p_product_category_id;
    END IF;

    IF p_price IS NULL OR p_price < 0 THEN
        RAISE EXCEPTION
            'Цена блюда должна быть неотрицательной';
    END IF;

    IF p_rating IS NOT NULL
       AND (p_rating < 0 OR p_rating > 5) THEN
        RAISE EXCEPTION
            'Рейтинг блюда должен быть от 0 до 5';
    END IF;

    INSERT INTO levichev_food.product (
        product_name,
        product_category_id,
        price,
        restaurant_id,
        photo_url,
        rating,
        status,
        description
    )
    VALUES (
        p_product_name,
        p_product_category_id,
        p_price,
        p_restaurant_id,
        p_photo_url,
        p_rating,
        p_status,
        p_description
    );
END;
$$;


--
-- TOC entry 268 (class 1255 OID 17048)
-- Name: check_order_address(); Type: FUNCTION; Schema: levichev_food
--

CREATE FUNCTION levichev_food.check_order_address() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
BEGIN
    IF NOT EXISTS (
        SELECT 1
        FROM levichev_food.client_address
        WHERE client_id = NEW.client_id
          AND address_id = NEW.address_id
    ) THEN
        RAISE EXCEPTION 'Адрес доставки не принадлежит клиенту';
    END IF;

    RETURN NEW;
END;
$$;


--
-- TOC entry 269 (class 1255 OID 17050)
-- Name: check_order_product_restaurant(); Type: FUNCTION; Schema: levichev_food
--

CREATE FUNCTION levichev_food.check_order_product_restaurant() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
BEGIN
    IF NOT EXISTS (
        SELECT 1
        FROM levichev_food."order" o
        JOIN levichev_food.product p
            ON p.restaurant_id = o.restaurant_id
        WHERE o.order_id = NEW.order_id
          AND p.product_id = NEW.product_id
    ) THEN
        RAISE EXCEPTION 'Блюдо не принадлежит ресторану заказа';
    END IF;

    RETURN NEW;
END;
$$;


--
-- TOC entry 270 (class 1255 OID 17052)
-- Name: check_order_restaurant_change(); Type: FUNCTION; Schema: levichev_food
--

CREATE FUNCTION levichev_food.check_order_restaurant_change() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
BEGIN
    IF EXISTS (
        SELECT 1
        FROM levichev_food.order_structure os
        JOIN levichev_food.product p
            ON p.product_id = os.product_id
        WHERE os.order_id = NEW.order_id
          AND p.restaurant_id <> NEW.restaurant_id
    ) THEN
        RAISE EXCEPTION 'В заказе есть блюда из другого ресторана';
    END IF;

    RETURN NEW;
END;
$$;


--
-- TOC entry 264 (class 1255 OID 17016)
-- Name: check_payment_amount(); Type: FUNCTION; Schema: levichev_food
--

CREATE FUNCTION levichev_food.check_payment_amount() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
BEGIN
    IF NOT EXISTS (
        SELECT 1
        FROM levichev_food."order"
        WHERE order_id = NEW.order_id
          AND total_amount = NEW.amount
    ) THEN
        RAISE EXCEPTION 'Сумма платежа не совпадает с суммой заказа';
    END IF;

    RETURN NEW;
END;
$$;


--
-- TOC entry 271 (class 1255 OID 17054)
-- Name: check_product_restaurant_change(); Type: FUNCTION; Schema: levichev_food
--

CREATE FUNCTION levichev_food.check_product_restaurant_change() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
BEGIN
    IF EXISTS (
        SELECT 1
        FROM levichev_food.order_structure os
        JOIN levichev_food."order" o
            ON o.order_id = os.order_id
        WHERE os.product_id = NEW.product_id
          AND o.restaurant_id <> NEW.restaurant_id
    ) THEN
        RAISE EXCEPTION 'Нельзя перенести блюдо в другой ресторан: оно используется в заказах';
    END IF;

    RETURN NEW;
END;
$$;


--
-- TOC entry 266 (class 1255 OID 17042)
-- Name: check_review_client(); Type: FUNCTION; Schema: levichev_food
--

CREATE FUNCTION levichev_food.check_review_client() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
BEGIN
    IF NOT EXISTS (
        SELECT 1
        FROM levichev_food."order"
        WHERE order_id = NEW.order_id
          AND client_id = NEW.client_id
    ) THEN
        RAISE EXCEPTION 'Отзыв может оставить только клиент, оформивший заказ';
    END IF;

    RETURN NEW;
END;
$$;


--
-- TOC entry 267 (class 1255 OID 17044)
-- Name: check_review_product(); Type: FUNCTION; Schema: levichev_food
--

CREATE FUNCTION levichev_food.check_review_product() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
BEGIN
    IF NEW.entity_type = 'блюдо'
       AND NOT EXISTS (
           SELECT 1
           FROM levichev_food.order_structure
           WHERE order_id = NEW.order_id
             AND product_id = NEW.entity_id
       )
    THEN
        RAISE EXCEPTION 'Нельзя оставить отзыв на блюдо, которого нет в заказе';
    END IF;

    IF NEW.entity_type = 'ресторан'
       AND NOT EXISTS (
           SELECT 1
           FROM levichev_food."order"
           WHERE order_id = NEW.order_id
             AND restaurant_id = NEW.entity_id
       )
    THEN
        RAISE EXCEPTION 'Нельзя оставить отзыв на ресторан, не связанный с заказом';
    END IF;

    IF NEW.entity_type = 'заказ'
       AND NEW.entity_id <> NEW.order_id
    THEN
        RAISE EXCEPTION 'Объект отзыва должен совпадать с указанным заказом';
    END IF;

    RETURN NEW;
END;
$$;


--
-- TOC entry 279 (class 1255 OID 17246)
-- Name: courier_salary(); Type: PROCEDURE; Schema: levichev_food
--

CREATE PROCEDURE levichev_food.courier_salary()
    LANGUAGE plpgsql
    AS $$
DECLARE
    v_year INTEGER := EXTRACT(YEAR FROM CURRENT_DATE)::INTEGER;
    v_month INTEGER := EXTRACT(MONTH FROM CURRENT_DATE)::INTEGER;
    v_courier RECORD;
    v_deliveries INTEGER;
    v_commission NUMERIC;
    v_new_coefficient NUMERIC;
BEGIN
    FOR v_courier IN
        SELECT courier_id, coefficient, status
        FROM levichev_food.courier
    LOOP
        SELECT
            COUNT(*),
            COALESCE(SUM(commission), 0)
        INTO v_deliveries, v_commission
        FROM levichev_food."order"
        WHERE courier_id = v_courier.courier_id
          AND status = 'доставлен'
          AND EXTRACT(YEAR FROM delivery_timestamp) = v_year
          AND EXTRACT(MONTH FROM delivery_timestamp) = v_month;

        INSERT INTO levichev_food.courier_pay (
            year, month, courier_id, amount, coefficient_used
        )
        VALUES (
            v_year,
            v_month,
            v_courier.courier_id,
            v_commission * v_courier.coefficient,
            v_courier.coefficient
        )
        ON CONFLICT (year, month, courier_id)
        DO UPDATE SET
            amount = EXCLUDED.amount,
            coefficient_used = EXCLUDED.coefficient_used;

        v_new_coefficient := CASE
            WHEN v_deliveries <= 150 THEN 0.1
            WHEN v_deliveries <= 250 THEN 0.2
            WHEN v_deliveries <= 500 THEN 0.3
            ELSE 0.5
        END;

        IF v_courier.status <> 'уволен' THEN
            UPDATE levichev_food.courier
            SET coefficient = v_new_coefficient
            WHERE courier_id = v_courier.courier_id;
        END IF;
    END LOOP;
END;
$$;


--
-- TOC entry 263 (class 1255 OID 17171)
-- Name: erase_test_data(); Type: PROCEDURE; Schema: levichev_food
--

CREATE PROCEDURE levichev_food.erase_test_data()
    LANGUAGE plpgsql
    AS $$
BEGIN
    TRUNCATE TABLE
        levichev_food.review,
        levichev_food.payment,
        levichev_food.courier_pay,
        levichev_food.order_structure,
        levichev_food."order",
        levichev_food.client_address,
        levichev_food.product,
        levichev_food.product_category,
        levichev_food.restaurant,
        levichev_food.courier,
        levichev_food.client,
        levichev_food.address;
END;
$$;


--
-- TOC entry 259 (class 1255 OID 17074)
-- Name: generate_client_addresses(); Type: PROCEDURE; Schema: levichev_food
--

CREATE PROCEDURE levichev_food.generate_client_addresses()
    LANGUAGE plpgsql
    AS $$
DECLARE
    v_client RECORD;
    i INTEGER;
    v_address_id UUID;
BEGIN
    FOR v_client IN
        SELECT client_id
        FROM pg_temp.generated_clients
    LOOP
        FOR i IN 1..4 LOOP
            INSERT INTO levichev_food.address (
                street,
                house_number,
                apartment_office
            )
            VALUES (
                'Тестовая улица ' ||
                    replace(exts.uuid_generate_v4()::text, '-', ''),
                i::text,
                CASE
                    WHEN i = 4 THEN NULL
                    ELSE i::text
                END
            )
            RETURNING address_id INTO v_address_id;

            INSERT INTO levichev_food.client_address (
                client_id,
                address_id
            )
            VALUES (
                v_client.client_id,
                v_address_id
            );
        END LOOP;
    END LOOP;
END;
$$;


--
-- TOC entry 274 (class 1255 OID 17145)
-- Name: generate_courier_pay(); Type: PROCEDURE; Schema: levichev_food
--

CREATE PROCEDURE levichev_food.generate_courier_pay()
    LANGUAGE plpgsql
    AS $$
DECLARE
    v_courier RECORD;
    v_month DATE;
    v_month_start DATE;
    v_month_end DATE;
    v_coefficient NUMERIC;
    v_next_coefficient NUMERIC;
    v_delivery_count INTEGER;
    v_commission_sum NUMERIC;
    i INTEGER;
BEGIN
    FOR v_courier IN
        SELECT courier_id
        FROM pg_temp.generated_couriers
    LOOP
        v_coefficient := 0.1;

        FOR i IN REVERSE 5..0 LOOP
            v_month := (
                date_trunc('month', CURRENT_DATE)
                - i * INTERVAL '1 month'
            )::date;

            v_month_start := v_month;
            v_month_end := (
                v_month + INTERVAL '1 month'
            )::date;

            SELECT
                COUNT(*),
                COALESCE(SUM(commission), 0)
            INTO
                v_delivery_count,
                v_commission_sum
            FROM levichev_food."order"
            WHERE courier_id = v_courier.courier_id
              AND status = 'доставлен'
              AND delivery_timestamp >= v_month_start
              AND delivery_timestamp < v_month_end;

            v_next_coefficient := CASE
                WHEN v_delivery_count <= 150 THEN 0.1
                WHEN v_delivery_count <= 250 THEN 0.2
                WHEN v_delivery_count <= 500 THEN 0.3
                ELSE 0.5
            END;

            INSERT INTO levichev_food.courier_pay (
                year,
                month,
                courier_id,
                amount,
                coefficient_used
            )
            VALUES (
                EXTRACT(YEAR FROM v_month)::integer,
                EXTRACT(MONTH FROM v_month)::integer,
                v_courier.courier_id,
                ROUND(v_coefficient * v_commission_sum, 2),
                v_coefficient
            )
            ON CONFLICT (year, month, courier_id)
            DO UPDATE SET
                amount = EXCLUDED.amount,
                coefficient_used = EXCLUDED.coefficient_used;

            v_coefficient := v_next_coefficient;
        END LOOP;

        UPDATE levichev_food.courier
        SET coefficient = v_coefficient
        WHERE courier_id = v_courier.courier_id
          AND status <> 'уволен';
    END LOOP;
END;
$$;


--
-- TOC entry 276 (class 1255 OID 17094)
-- Name: generate_couriers(integer); Type: PROCEDURE; Schema: levichev_food
--

CREATE PROCEDURE levichev_food.generate_couriers(IN value integer)
    LANGUAGE plpgsql
    AS $$
DECLARE
    i INTEGER;
    v_courier_id UUID;
BEGIN
    CREATE TEMP TABLE IF NOT EXISTS generated_couriers (
        courier_id UUID PRIMARY KEY
    ) ON COMMIT DELETE ROWS;

    TRUNCATE TABLE pg_temp.generated_couriers;

    FOR i IN 1..value LOOP
        INSERT INTO levichev_food.courier (
            fio,
            phone_number,
            status,
            hire_date,
            dismissal_date,
            coefficient
        )
        VALUES (
            'Курьер ' || replace(exts.uuid_generate_v4()::text, '-', ''),
            '7' || lpad(
                (floor(random() * 10000000000)::bigint)::text,
                10, '0'
            ),
            (
                SELECT s
                FROM unnest(
                    enum_range(NULL::levichev_food.courier_status)
                ) AS s
                WHERE s <> 'уволен'
                ORDER BY random()
                LIMIT 1
            ),
            CURRENT_DATE - (floor(random() * 180)::integer),
            NULL,
            0.1
        )
        RETURNING courier_id INTO v_courier_id;

        INSERT INTO pg_temp.generated_couriers (courier_id)
        VALUES (v_courier_id);
    END LOOP;
END;
$$;


--
-- TOC entry 260 (class 1255 OID 17113)
-- Name: generate_order_structure(); Type: PROCEDURE; Schema: levichev_food
--

CREATE PROCEDURE levichev_food.generate_order_structure()
    LANGUAGE plpgsql
    AS $$
DECLARE
    v_order RECORD;
BEGIN
    FOR v_order IN
        SELECT o.order_id, o.restaurant_id
        FROM levichev_food."order" o
        JOIN pg_temp.generated_clients gc
            ON gc.client_id = o.client_id
    LOOP
        INSERT INTO levichev_food.order_structure (
            order_id,
            product_id,
            quantity
        )
        SELECT
            v_order.order_id,
            p.product_id,
            3
        FROM levichev_food.product p
        WHERE p.restaurant_id = v_order.restaurant_id
        ORDER BY random()
        LIMIT 3;
    END LOOP;
END;
$$;


--
-- TOC entry 272 (class 1255 OID 17102)
-- Name: generate_orders(); Type: PROCEDURE; Schema: levichev_food
--

CREATE PROCEDURE levichev_food.generate_orders()
    LANGUAGE plpgsql
    AS $$
DECLARE
    v_client RECORD;
    v_address_id UUID;
    v_restaurant_id UUID;
    v_courier_id UUID;
    v_amount NUMERIC(12, 2);
    v_commission NUMERIC(12, 2);
    v_order_time TIMESTAMP;
    v_status levichev_food.order_status;
    i INTEGER;
BEGIN
    FOR v_client IN
        SELECT client_id
        FROM pg_temp.generated_clients
    LOOP
        FOR i IN 1..5 LOOP
            SELECT address_id
            INTO v_address_id
            FROM levichev_food.client_address
            WHERE client_id = v_client.client_id
            ORDER BY random()
            LIMIT 1;

            SELECT restaurant_id
            INTO v_restaurant_id
            FROM pg_temp.generated_restaurants
            ORDER BY random()
            LIMIT 1;

            SELECT courier_id
            INTO v_courier_id
            FROM pg_temp.generated_couriers
            ORDER BY random()
            LIMIT 1;

            SELECT s
            INTO v_status
            FROM unnest(
                enum_range(NULL::levichev_food.order_status)
            ) AS s
            ORDER BY random()
            LIMIT 1;

            v_amount := (floor(random() * 2000) + 1000)::numeric;
            v_commission := round(v_amount * 0.10, 2);

            v_order_time := CURRENT_TIMESTAMP
                - (floor(random() * 180) + 1) * INTERVAL '1 day';

            INSERT INTO levichev_food."order" (
                courier_id,
                client_id,
                address_id,
                restaurant_id,
                order_timestamp,
                delivery_timestamp,
                order_amount,
                commission,
                total_amount,
                status,
                pay_status,
                description
            )
            VALUES (
                v_courier_id,
                v_client.client_id,
                v_address_id,
                v_restaurant_id,
                v_order_time,
                CASE
                    WHEN v_status = 'доставлен'
                    THEN v_order_time + INTERVAL '45 minutes'
                    ELSE NULL
                END,
                v_amount,
                v_commission,
                v_amount + v_commission,
                v_status,
                'ожидает',
                'Тестовый заказ FoodExpress'
            );
        END LOOP;
    END LOOP;
END;
$$;


--
-- TOC entry 262 (class 1255 OID 17128)
-- Name: generate_payments(); Type: PROCEDURE; Schema: levichev_food
--

CREATE PROCEDURE levichev_food.generate_payments()
    LANGUAGE plpgsql
    AS $$
BEGIN
    INSERT INTO levichev_food.payment (
        order_id,
        payment_type,
        amount,
        transaction_id,
        transaction_timestamp,
        status
    )
    SELECT
        o.order_id,
        'карта',
        o.total_amount,
        'test_' || replace(exts.uuid_generate_v4()::text, '-', ''),
        o.order_timestamp,
        'успех'
    FROM levichev_food."order" o
    JOIN pg_temp.generated_clients gc
        ON gc.client_id = o.client_id;
END;
$$;


--
-- TOC entry 280 (class 1255 OID 17084)
-- Name: generate_product_categories(integer); Type: PROCEDURE; Schema: levichev_food
--

CREATE PROCEDURE levichev_food.generate_product_categories(IN value integer)
    LANGUAGE plpgsql
    AS $$
DECLARE
    v_categories TEXT[] := ARRAY[
        'Пицца',
        'Суши и роллы',
        'Бургеры',
        'Супы',
        'Салаты',
        'Паста',
        'Горячие блюда',
        'Закуски',
        'Десерты',
        'Напитки',
        'Завтраки',
        'Гарниры',
        'Морепродукты',
        'Блюда на гриле',
        'Выпечка'
    ];
    i INTEGER;
    v_name TEXT;
BEGIN
    IF value IS NULL OR value <= 0 THEN
        RAISE EXCEPTION 'Количество категорий должно быть положительным';
    END IF;

    FOR i IN 1..value LOOP
        v_name := v_categories[
            ((i - 1) % array_length(v_categories, 1)) + 1
        ];

        IF i > array_length(v_categories, 1) THEN
            v_name := v_name || ' №' ||
                ((i - 1) / array_length(v_categories, 1) + 1)::TEXT;
        END IF;

        INSERT INTO levichev_food.product_category (
            product_category_name
        )
        VALUES (v_name)
        ON CONFLICT (product_category_name) DO NOTHING;
    END LOOP;
END;
$$;


--
-- TOC entry 258 (class 1255 OID 17085)
-- Name: generate_products(integer); Type: PROCEDURE; Schema: levichev_food
--

CREATE PROCEDURE levichev_food.generate_products(IN value integer)
    LANGUAGE plpgsql
    AS $$
DECLARE
    v_restaurant RECORD;
    v_product RECORD;
    v_category_id UUID;
BEGIN
    FOR v_restaurant IN
        SELECT restaurant_id
        FROM pg_temp.generated_restaurants
    LOOP
        FOR v_product IN
            SELECT *
            FROM (
                VALUES
                    ('Пицца Маргарита', 'Пицца'),
                    ('Пицца Пепперони', 'Пицца'),
                    ('Паста Карбонара', 'Паста'),
                    ('Паста Болоньезе', 'Паста'),
                    ('Бургер Классический', 'Бургеры'),
                    ('Чизбургер', 'Бургеры'),
                    ('Картофель фри', 'Гарниры'),
                    ('Салат Цезарь', 'Салаты'),
                    ('Греческий салат', 'Салаты'),
                    ('Суп Том Ям', 'Супы'),
                    ('Борщ домашний', 'Супы'),
                    ('Куриный суп', 'Супы'),
                    ('Ролл Филадельфия', 'Суши и роллы'),
                    ('Ролл Калифорния', 'Суши и роллы'),
                    ('Суши с лососем', 'Суши и роллы'),
                    ('Стейк из говядины', 'Блюда на гриле'),
                    ('Курица на гриле', 'Блюда на гриле'),
                    ('Лапша с овощами', 'Горячие блюда'),
                    ('Рис с курицей', 'Горячие блюда'),
                    ('Пельмени домашние', 'Горячие блюда'),
                    ('Сырники со сметаной', 'Десерты'),
                    ('Шоколадный чизкейк', 'Десерты'),
                    ('Тирамису', 'Десерты'),
                    ('Морс ягодный', 'Напитки'),
                    ('Лимонад домашний', 'Напитки')
            ) AS dishes(product_name, category_name)
            ORDER BY random()
            LIMIT 5
        LOOP
            SELECT pc.product_category_id
            INTO v_category_id
            FROM levichev_food.product_category pc
            WHERE pc.product_category_name = v_product.category_name;

            IF v_category_id IS NULL THEN
                INSERT INTO levichev_food.product_category (
                    product_category_name
                )
                VALUES (v_product.category_name)
                ON CONFLICT (product_category_name)
                DO UPDATE SET
                    product_category_name = EXCLUDED.product_category_name
                RETURNING product_category_id INTO v_category_id;
            END IF;

            INSERT INTO levichev_food.product (
                product_name,
                product_category_id,
                price,
                restaurant_id,
                photo_url,
                status,
                description
            )
            VALUES (
                v_product.product_name,
                v_category_id,
                (floor(random() * 800) + 200)::NUMERIC,
                v_restaurant.restaurant_id,
                NULL,
                'доступно',
                'Блюдо из меню ресторана FoodExpress'
            );
        END LOOP;
    END LOOP;
END;
$$;


--
-- TOC entry 257 (class 1255 OID 17078)
-- Name: generate_restaurants(integer); Type: PROCEDURE; Schema: levichev_food
--

CREATE PROCEDURE levichev_food.generate_restaurants(IN value integer)
    LANGUAGE plpgsql
    AS $$
DECLARE
    i INTEGER;
    v_address_id UUID;
    v_restaurant_id UUID;

    v_names TEXT[] := ARRAY[
        'Итальянский дворик',
        'Восточный базар',
        'Тёплая кухня',
        'Суши Хаус',
        'Пицца Палас',
        'Городской гриль',
        'Вкусный уголок',
        'Морская гавань',
        'Домашний обед',
        'Золотой дракон',
        'Бургерная №1',
        'Пряный сад',
        'Семейное кафе',
        'Лавка вкуса',
        'Московские традиции'
    ];

    v_streets TEXT[] := ARRAY[
        'Лесная',
        'Центральная',
        'Садовая',
        'Парковая',
        'Молодёжная',
        'Школьная',
        'Новая',
        'Набережная'
    ];
BEGIN
    CREATE TEMP TABLE IF NOT EXISTS generated_restaurants (
        restaurant_id UUID PRIMARY KEY
    ) ON COMMIT DELETE ROWS;

    TRUNCATE TABLE pg_temp.generated_restaurants;

    FOR i IN 1..value LOOP

        INSERT INTO levichev_food.address (
            street,
            house_number,
            apartment_office
        )
        VALUES (
            v_streets[
                ((i - 1) % array_length(v_streets, 1)) + 1
            ] || ' улица',
            i::TEXT,
            NULL
        )
        RETURNING address_id INTO v_address_id;

        INSERT INTO levichev_food.restaurant (
            restaurant_name,
            address_id,
            description,
            work_start,
            work_end,
            company_details,
            status
        )
        VALUES (
            v_names[
                ((i - 1) % array_length(v_names, 1)) + 1
            ] || CASE
                WHEN i > array_length(v_names, 1)
                THEN ' №' || (
                    (i - 1) / array_length(v_names, 1) + 1
                )::TEXT
                ELSE ''
            END,
            v_address_id,
            'Ресторан с разнообразным меню и доставкой еды',
            '09:00',
            '22:00',
            'Тестовые реквизиты',
            'активен'
        )
        RETURNING restaurant_id INTO v_restaurant_id;

        INSERT INTO pg_temp.generated_restaurants (
            restaurant_id
        )
        VALUES (v_restaurant_id);

    END LOOP;
END;
$$;


--
-- TOC entry 261 (class 1255 OID 17139)
-- Name: generate_reviews(); Type: PROCEDURE; Schema: levichev_food
--

CREATE PROCEDURE levichev_food.generate_reviews()
    LANGUAGE plpgsql
    AS $$
BEGIN
    INSERT INTO levichev_food.review (
        client_id,
        entity_id,
        entity_type,
        order_id,
        description,
        rating
    )
    SELECT
        o.client_id,
        CASE
            WHEN t.review_type = 1 THEN o.order_id
            WHEN t.review_type = 2 THEN o.restaurant_id
            ELSE p.product_id
        END,
        CASE
            WHEN t.review_type = 1 THEN 'заказ'
            WHEN t.review_type = 2 THEN 'ресторан'
            ELSE 'блюдо'
        END::levichev_food.review_entity_type,
        o.order_id,
        'Тестовый отзыв FoodExpress',
        (floor(random() * 5) + 1)::numeric
    FROM levichev_food."order" o
    JOIN pg_temp.generated_clients gc
        ON gc.client_id = o.client_id
    CROSS JOIN LATERAL (
        SELECT (floor(random() * 3) + 1)::integer AS review_type
        WHERE o.order_id IS NOT NULL
    ) t
    LEFT JOIN LATERAL (
        SELECT os.product_id
        FROM levichev_food.order_structure os
        WHERE os.order_id = o.order_id
        ORDER BY random()
        LIMIT 1
    ) p ON TRUE;
END;
$$;


--
-- TOC entry 278 (class 1255 OID 17245)
-- Name: get_statistic(); Type: FUNCTION; Schema: levichev_food
--

CREATE FUNCTION levichev_food.get_statistic() RETURNS TABLE(restaurant_name character varying, best_product_name character varying, total_amount numeric, avg_amount numeric, best_user character varying)
    LANGUAGE sql
    AS $$
    WITH delivered_orders AS (
        SELECT
            o.order_id,
            o.restaurant_id,
            o.client_id,
            o.total_amount
        FROM levichev_food."order" o
        WHERE o.status = 'доставлен'
    ),
    order_stats AS (
        SELECT
            restaurant_id,
            SUM(total_amount) AS total_amount,
            AVG(total_amount) AS avg_amount
        FROM delivered_orders
        GROUP BY restaurant_id
    ),
    product_stats AS (
        SELECT
            d.restaurant_id,
            p.product_name,
            SUM(os.quantity) AS total_quantity,
            ROW_NUMBER() OVER (
                PARTITION BY d.restaurant_id
                ORDER BY SUM(os.quantity) DESC, RANDOM()
            ) AS rn
        FROM delivered_orders d
        JOIN levichev_food.order_structure os
            ON os.order_id = d.order_id
        JOIN levichev_food.product p
            ON p.product_id = os.product_id
        GROUP BY d.restaurant_id, p.product_id, p.product_name
    ),
    client_stats AS (
        SELECT
            d.restaurant_id,
            c.login,
            COUNT(*) AS orders_count,
            ROW_NUMBER() OVER (
                PARTITION BY d.restaurant_id
                ORDER BY COUNT(*) DESC, RANDOM()
            ) AS rn
        FROM delivered_orders d
        JOIN levichev_food.client c
            ON c.client_id = d.client_id
        GROUP BY d.restaurant_id, c.client_id, c.login
    )
    SELECT
        r.restaurant_name,
        ps.product_name AS best_product_name,
        s.total_amount,
        s.avg_amount,
        cs.login AS best_user
    FROM levichev_food.restaurant r
    LEFT JOIN order_stats s
        ON s.restaurant_id = r.restaurant_id
    LEFT JOIN product_stats ps
        ON ps.restaurant_id = r.restaurant_id
       AND ps.rn = 1
    LEFT JOIN client_stats cs
        ON cs.restaurant_id = r.restaurant_id
       AND cs.rn = 1;
$$;


--
-- TOC entry 275 (class 1255 OID 17056)
-- Name: insert_test_data(integer); Type: PROCEDURE; Schema: levichev_food
--

CREATE PROCEDURE levichev_food.insert_test_data(IN value integer)
    LANGUAGE plpgsql
    AS $$
DECLARE
    i INTEGER;
    v_client_id UUID;
BEGIN
    IF value IS NULL OR value <= 0 THEN
        RAISE EXCEPTION 'Количество записей должно быть положительным';
    END IF;

    CREATE TEMP TABLE IF NOT EXISTS generated_clients (
        client_number INTEGER PRIMARY KEY,
        client_id UUID NOT NULL UNIQUE
    ) ON COMMIT DELETE ROWS;

    TRUNCATE TABLE pg_temp.generated_clients;

    FOR i IN 1..value LOOP
        INSERT INTO levichev_food.client (
            login,
            password,
            phone_number
        )
        VALUES (
            'test_' || replace(exts.uuid_generate_v4()::text, '-', ''),
            md5(random()::text),
            '7' || lpad(
                (floor(random() * 10000000000)::bigint)::text,
                10, '0'
            )
        )
        RETURNING client_id INTO v_client_id;

        INSERT INTO pg_temp.generated_clients (
            client_number,
            client_id
        )
        VALUES (i, v_client_id);
    END LOOP;

    CALL levichev_food.generate_client_addresses();
    CALL levichev_food.generate_restaurants(value);
    CALL levichev_food.generate_product_categories(value);
    CALL levichev_food.generate_products(value);
    CALL levichev_food.generate_couriers(value);
    CALL levichev_food.generate_orders();
    CALL levichev_food.generate_order_structure();
    CALL levichev_food.recalculate_order_amounts();
    CALL levichev_food.generate_payments();
    CALL levichev_food.generate_reviews();

    CALL levichev_food.generate_courier_pay();
END;
$$;


--
-- TOC entry 245 (class 1255 OID 17242)
-- Name: rating_change(); Type: FUNCTION; Schema: levichev_food
--

CREATE FUNCTION levichev_food.rating_change() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
BEGIN
    -- При удалении или изменении пересчитываем старую сущность
    IF TG_OP IN ('DELETE', 'UPDATE') THEN
        IF OLD.entity_type = 'блюдо' THEN
            UPDATE levichev_food.product
            SET rating = (
                SELECT AVG(r.rating)
                FROM levichev_food.review r
                WHERE r.entity_type = 'блюдо'
                  AND r.entity_id = OLD.entity_id
            )
            WHERE product_id = OLD.entity_id;

        ELSIF OLD.entity_type = 'ресторан' THEN
            UPDATE levichev_food.restaurant
            SET rating = (
                SELECT AVG(r.rating)
                FROM levichev_food.review r
                WHERE r.entity_type = 'ресторан'
                  AND r.entity_id = OLD.entity_id
            )
            WHERE restaurant_id = OLD.entity_id;
        END IF;
    END IF;

    -- При добавлении или изменении пересчитываем новую сущность
    IF TG_OP IN ('INSERT', 'UPDATE') THEN
        IF NEW.entity_type = 'блюдо' THEN
            UPDATE levichev_food.product
            SET rating = (
                SELECT AVG(r.rating)
                FROM levichev_food.review r
                WHERE r.entity_type = 'блюдо'
                  AND r.entity_id = NEW.entity_id
            )
            WHERE product_id = NEW.entity_id;

        ELSIF NEW.entity_type = 'ресторан' THEN
            UPDATE levichev_food.restaurant
            SET rating = (
                SELECT AVG(r.rating)
                FROM levichev_food.review r
                WHERE r.entity_type = 'ресторан'
                  AND r.entity_id = NEW.entity_id
            )
            WHERE restaurant_id = NEW.entity_id;
        END IF;
    END IF;

    IF TG_OP = 'DELETE' THEN
        RETURN OLD;
    END IF;

    RETURN NEW;
END;
$$;


--
-- TOC entry 273 (class 1255 OID 17122)
-- Name: recalculate_order_amounts(); Type: PROCEDURE; Schema: levichev_food
--

CREATE PROCEDURE levichev_food.recalculate_order_amounts()
    LANGUAGE plpgsql
    AS $$
BEGIN
    UPDATE levichev_food."order" o
    SET
        order_amount = s.amount,
        commission = round(s.amount * 0.10, 2),
        total_amount = s.amount + round(s.amount * 0.10, 2)
    FROM (
        SELECT
            os.order_id,
            round(SUM(p.price * os.quantity), 2) AS amount
        FROM levichev_food.order_structure os
        JOIN levichev_food.product p
            ON p.product_id = os.product_id
        GROUP BY os.order_id
    ) s
    WHERE o.order_id = s.order_id
      AND s.amount + round(s.amount * 0.10, 2) >= 1000;
END;
$$;


--
-- TOC entry 265 (class 1255 OID 17018)
-- Name: sync_order_pay_status(); Type: FUNCTION; Schema: levichev_food
--

CREATE FUNCTION levichev_food.sync_order_pay_status() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
DECLARE
    v_order_id UUID;
BEGIN
    IF TG_OP = 'DELETE' THEN
        v_order_id := OLD.order_id;
    ELSE
        v_order_id := NEW.order_id;
    END IF;

    UPDATE levichev_food."order"
    SET pay_status = CASE
        WHEN EXISTS (
            SELECT 1
            FROM levichev_food.payment
            WHERE order_id = v_order_id
              AND status = 'успех'
        ) THEN 'оплачен'::levichev_food.order_pay_status

        WHEN EXISTS (
            SELECT 1
            FROM levichev_food.payment
            WHERE order_id = v_order_id
              AND status = 'в_обработке'
        ) THEN 'ожидает'::levichev_food.order_pay_status

        WHEN EXISTS (
            SELECT 1
            FROM levichev_food.payment
            WHERE order_id = v_order_id
        ) THEN 'ошибка'::levichev_food.order_pay_status

        ELSE 'ожидает'::levichev_food.order_pay_status
    END
    WHERE order_id = v_order_id;

    IF TG_OP = 'UPDATE' AND OLD.order_id <> NEW.order_id THEN
        UPDATE levichev_food."order"
        SET pay_status = CASE
            WHEN EXISTS (
                SELECT 1 FROM levichev_food.payment
                WHERE order_id = OLD.order_id AND status = 'успех'
            ) THEN 'оплачен'::levichev_food.order_pay_status

            WHEN EXISTS (
                SELECT 1 FROM levichev_food.payment
                WHERE order_id = OLD.order_id AND status = 'в_обработке'
            ) THEN 'ожидает'::levichev_food.order_pay_status

            WHEN EXISTS (
                SELECT 1 FROM levichev_food.payment
                WHERE order_id = OLD.order_id
            ) THEN 'ошибка'::levichev_food.order_pay_status

            ELSE 'ожидает'::levichev_food.order_pay_status
        END
        WHERE order_id = OLD.order_id;
    END IF;

    RETURN NULL;
END;
$$;


SET default_tablespace = '';

SET default_table_access_method = heap;

--
-- TOC entry 222 (class 1259 OID 16853)
-- Name: address; Type: TABLE; Schema: levichev_food
--

CREATE TABLE levichev_food.address (
    address_id uuid DEFAULT exts.uuid_generate_v4() NOT NULL,
    street character varying(255) NOT NULL,
    house_number character varying(20) NOT NULL,
    apartment_office character varying(20)
);


--
-- TOC entry 223 (class 1259 OID 16859)
-- Name: client; Type: TABLE; Schema: levichev_food
--

CREATE TABLE levichev_food.client (
    client_id uuid DEFAULT exts.uuid_generate_v4() NOT NULL,
    login character varying(100) NOT NULL,
    password character varying(255) NOT NULL,
    phone_number character(11) NOT NULL
);


--
-- TOC entry 228 (class 1259 OID 16921)
-- Name: client_address; Type: TABLE; Schema: levichev_food
--

CREATE TABLE levichev_food.client_address (
    client_id uuid NOT NULL,
    address_id uuid NOT NULL
);


--
-- TOC entry 227 (class 1259 OID 16910)
-- Name: courier; Type: TABLE; Schema: levichev_food
--

CREATE TABLE levichev_food.courier (
    courier_id uuid DEFAULT exts.uuid_generate_v4() NOT NULL,
    fio character varying(255) NOT NULL,
    phone_number character(11) NOT NULL,
    status levichev_food.courier_status NOT NULL,
    hire_date date NOT NULL,
    dismissal_date date,
    coefficient numeric(5,2) DEFAULT 0.1 NOT NULL,
    CONSTRAINT courier_check CHECK (((dismissal_date IS NULL) OR (dismissal_date >= hire_date))),
    CONSTRAINT courier_coefficient_check CHECK (((coefficient >= 0.1) AND (coefficient <= 0.5))),
    CONSTRAINT courier_dismissal_status_check CHECK (((status <> 'уволен'::levichev_food.courier_status) OR (dismissal_date IS NOT NULL)))
);


--
-- TOC entry 229 (class 1259 OID 16936)
-- Name: courier_pay; Type: TABLE; Schema: levichev_food
--

CREATE TABLE levichev_food.courier_pay (
    year integer NOT NULL,
    month integer NOT NULL,
    courier_id uuid NOT NULL,
    amount numeric(12,2) NOT NULL,
    coefficient_used numeric(5,2) NOT NULL,
    CONSTRAINT courier_pay_amount_check CHECK ((amount >= (0)::numeric)),
    CONSTRAINT courier_pay_coefficient_used_check CHECK (((coefficient_used >= 0.1) AND (coefficient_used <= 0.5))),
    CONSTRAINT courier_pay_month_check CHECK (((month >= 1) AND (month <= 12))),
    CONSTRAINT courier_pay_year_check CHECK ((year >= 2000))
);


--
-- TOC entry 230 (class 1259 OID 16950)
-- Name: order; Type: TABLE; Schema: levichev_food
--

CREATE TABLE levichev_food."order" (
    order_id uuid DEFAULT exts.uuid_generate_v4() NOT NULL,
    courier_id uuid,
    client_id uuid NOT NULL,
    address_id uuid NOT NULL,
    restaurant_id uuid NOT NULL,
    order_timestamp timestamp without time zone DEFAULT CURRENT_TIMESTAMP NOT NULL,
    delivery_timestamp timestamp without time zone,
    order_amount numeric(12,2) NOT NULL,
    commission numeric(12,2) NOT NULL,
    total_amount numeric(12,2) NOT NULL,
    status levichev_food.order_status NOT NULL,
    pay_status levichev_food.order_pay_status NOT NULL,
    description text,
    CONSTRAINT order_check CHECK (((delivery_timestamp IS NULL) OR (delivery_timestamp >= order_timestamp))),
    CONSTRAINT order_check1 CHECK ((total_amount = (order_amount + commission))),
    CONSTRAINT order_commission_10_percent_check CHECK ((commission = round((order_amount * 0.10), 2))),
    CONSTRAINT order_commission_check CHECK ((commission >= (0)::numeric)),
    CONSTRAINT order_min_total_amount_check CHECK ((total_amount >= (1000)::numeric)),
    CONSTRAINT order_order_amount_check CHECK ((order_amount >= (0)::numeric)),
    CONSTRAINT order_total_amount_check CHECK ((total_amount >= (0)::numeric))
);


--
-- TOC entry 234 (class 1259 OID 17247)
-- Name: how_much_money; Type: VIEW; Schema: levichev_food
--

CREATE VIEW levichev_food.how_much_money AS
 WITH RECURSIVE date_bounds AS (
         SELECT (date_trunc('month'::text, min("order".delivery_timestamp)))::date AS first_month,
            (date_trunc('month'::text, max("order".delivery_timestamp)))::date AS last_month
           FROM levichev_food."order"
          WHERE ("order".status = 'доставлен'::levichev_food.order_status)
        ), months AS (
         SELECT date_bounds.first_month AS month_start
           FROM date_bounds
          WHERE (date_bounds.first_month IS NOT NULL)
        UNION ALL
         SELECT ((m.month_start + '1 mon'::interval))::date AS date
           FROM (months m
             CROSS JOIN date_bounds b)
          WHERE (m.month_start < b.last_month)
        ), order_stats AS (
         SELECT (date_trunc('month'::text, "order".delivery_timestamp))::date AS month_start,
            sum("order".order_amount) AS sum_no_commission,
            sum("order".total_amount) AS sum_with_commission,
            sum("order".commission) AS commission
           FROM levichev_food."order"
          WHERE ("order".status = 'доставлен'::levichev_food.order_status)
          GROUP BY ((date_trunc('month'::text, "order".delivery_timestamp))::date)
        ), salary_stats AS (
         SELECT make_date(courier_pay.year, courier_pay.month, 1) AS month_start,
            sum(courier_pay.amount) AS courier_pay
           FROM levichev_food.courier_pay
          GROUP BY courier_pay.year, courier_pay.month
        ), monthly_stats AS (
         SELECT m.month_start,
            COALESCE(o.sum_no_commission, (0)::numeric) AS sum_no_commission,
            COALESCE(o.sum_with_commission, (0)::numeric) AS sum_with_commission,
            COALESCE(o.commission, (0)::numeric) AS commission,
            COALESCE(s.courier_pay, (0)::numeric) AS courier_pay
           FROM ((months m
             LEFT JOIN order_stats o ON ((o.month_start = m.month_start)))
             LEFT JOIN salary_stats s ON ((s.month_start = m.month_start)))
        )
 SELECT to_char((month_start)::timestamp with time zone, 'YYYY-MM'::text) AS year_month,
    sum_no_commission,
    sum_with_commission,
    commission,
    lag(commission, 1, (0)::numeric) OVER (ORDER BY month_start) AS prev_commission,
    (commission - lag(commission, 1, (0)::numeric) OVER (ORDER BY month_start)) AS commission_diff,
    courier_pay,
    (commission - courier_pay) AS net_profit
   FROM monthly_stats;


--
-- TOC entry 231 (class 1259 OID 16984)
-- Name: order_structure; Type: TABLE; Schema: levichev_food
--

CREATE TABLE levichev_food.order_structure (
    order_id uuid NOT NULL,
    product_id uuid NOT NULL,
    quantity numeric(10,2) NOT NULL,
    CONSTRAINT order_structure_quantity_check CHECK ((quantity > (0)::numeric))
);


--
-- TOC entry 232 (class 1259 OID 17000)
-- Name: payment; Type: TABLE; Schema: levichev_food
--

CREATE TABLE levichev_food.payment (
    payment_id uuid DEFAULT exts.uuid_generate_v4() NOT NULL,
    order_id uuid NOT NULL,
    payment_type levichev_food.payment_type NOT NULL,
    amount numeric(12,2) NOT NULL,
    transaction_id character varying(255) NOT NULL,
    transaction_timestamp timestamp without time zone DEFAULT CURRENT_TIMESTAMP NOT NULL,
    status levichev_food.payment_status NOT NULL,
    CONSTRAINT payment_amount_check CHECK ((amount >= (0)::numeric))
);


--
-- TOC entry 226 (class 1259 OID 16890)
-- Name: product; Type: TABLE; Schema: levichev_food
--

CREATE TABLE levichev_food.product (
    product_id uuid DEFAULT exts.uuid_generate_v4() NOT NULL,
    product_name character varying(255) NOT NULL,
    product_category_id uuid NOT NULL,
    price numeric(12,2) NOT NULL,
    restaurant_id uuid NOT NULL,
    photo_url text,
    rating numeric(3,2),
    status levichev_food.product_status NOT NULL,
    description text NOT NULL,
    CONSTRAINT product_price_check CHECK ((price >= (0)::numeric)),
    CONSTRAINT product_rating_check CHECK (((rating >= (0)::numeric) AND (rating <= (5)::numeric)))
);


--
-- TOC entry 225 (class 1259 OID 16882)
-- Name: product_category; Type: TABLE; Schema: levichev_food
--

CREATE TABLE levichev_food.product_category (
    product_category_id uuid DEFAULT exts.uuid_generate_v4() NOT NULL,
    product_category_name character varying(100) NOT NULL
);


--
-- TOC entry 224 (class 1259 OID 16869)
-- Name: restaurant; Type: TABLE; Schema: levichev_food
--

CREATE TABLE levichev_food.restaurant (
    restaurant_id uuid DEFAULT exts.uuid_generate_v4() NOT NULL,
    restaurant_name character varying(255) NOT NULL,
    address_id uuid NOT NULL,
    description text NOT NULL,
    work_start time without time zone NOT NULL,
    work_end time without time zone NOT NULL,
    company_details text NOT NULL,
    rating numeric(3,2),
    status levichev_food.restaurant_status NOT NULL,
    CONSTRAINT restaurant_rating_check CHECK (((rating >= (0)::numeric) AND (rating <= (5)::numeric))),
    CONSTRAINT restaurant_work_time_check CHECK ((work_end > work_start))
);


--
-- TOC entry 233 (class 1259 OID 17020)
-- Name: review; Type: TABLE; Schema: levichev_food
--

CREATE TABLE levichev_food.review (
    review_id uuid DEFAULT exts.uuid_generate_v4() NOT NULL,
    client_id uuid NOT NULL,
    review_timestamp timestamp without time zone DEFAULT CURRENT_TIMESTAMP NOT NULL,
    entity_id uuid NOT NULL,
    entity_type levichev_food.review_entity_type NOT NULL,
    order_id uuid NOT NULL,
    description text NOT NULL,
    photo_url text,
    rating numeric(2,1) NOT NULL,
    CONSTRAINT review_rating_check CHECK (((rating >= (1)::numeric) AND (rating <= (5)::numeric)))
);


--
-- TOC entry 3826 (class 2606 OID 16858)
-- Name: address address_pkey; Type: CONSTRAINT; Schema: levichev_food
--

ALTER TABLE ONLY levichev_food.address
    ADD CONSTRAINT address_pkey PRIMARY KEY (address_id);


--
-- TOC entry 3848 (class 2606 OID 16925)
-- Name: client_address client_address_pkey; Type: CONSTRAINT; Schema: levichev_food
--

ALTER TABLE ONLY levichev_food.client_address
    ADD CONSTRAINT client_address_pkey PRIMARY KEY (client_id, address_id);


--
-- TOC entry 3828 (class 2606 OID 16866)
-- Name: client client_login_key; Type: CONSTRAINT; Schema: levichev_food
--

ALTER TABLE ONLY levichev_food.client
    ADD CONSTRAINT client_login_key UNIQUE (login);


--
-- TOC entry 3830 (class 2606 OID 16868)
-- Name: client client_phone_number_key; Type: CONSTRAINT; Schema: levichev_food
--

ALTER TABLE ONLY levichev_food.client
    ADD CONSTRAINT client_phone_number_key UNIQUE (phone_number);


--
-- TOC entry 3832 (class 2606 OID 16864)
-- Name: client client_pkey; Type: CONSTRAINT; Schema: levichev_food
--

ALTER TABLE ONLY levichev_food.client
    ADD CONSTRAINT client_pkey PRIMARY KEY (client_id);


--
-- TOC entry 3850 (class 2606 OID 16944)
-- Name: courier_pay courier_pay_pkey; Type: CONSTRAINT; Schema: levichev_food
--

ALTER TABLE ONLY levichev_food.courier_pay
    ADD CONSTRAINT courier_pay_pkey PRIMARY KEY (year, month, courier_id);


--
-- TOC entry 3844 (class 2606 OID 16920)
-- Name: courier courier_phone_number_key; Type: CONSTRAINT; Schema: levichev_food
--

ALTER TABLE ONLY levichev_food.courier
    ADD CONSTRAINT courier_phone_number_key UNIQUE (phone_number);


--
-- TOC entry 3846 (class 2606 OID 16918)
-- Name: courier courier_pkey; Type: CONSTRAINT; Schema: levichev_food
--

ALTER TABLE ONLY levichev_food.courier
    ADD CONSTRAINT courier_pkey PRIMARY KEY (courier_id);


--
-- TOC entry 3852 (class 2606 OID 16963)
-- Name: order order_pkey; Type: CONSTRAINT; Schema: levichev_food
--

ALTER TABLE ONLY levichev_food."order"
    ADD CONSTRAINT order_pkey PRIMARY KEY (order_id);


--
-- TOC entry 3854 (class 2606 OID 16989)
-- Name: order_structure order_structure_pkey; Type: CONSTRAINT; Schema: levichev_food
--

ALTER TABLE ONLY levichev_food.order_structure
    ADD CONSTRAINT order_structure_pkey PRIMARY KEY (order_id, product_id);


--
-- TOC entry 3857 (class 2606 OID 17007)
-- Name: payment payment_pkey; Type: CONSTRAINT; Schema: levichev_food
--

ALTER TABLE ONLY levichev_food.payment
    ADD CONSTRAINT payment_pkey PRIMARY KEY (payment_id);


--
-- TOC entry 3859 (class 2606 OID 17009)
-- Name: payment payment_transaction_id_key; Type: CONSTRAINT; Schema: levichev_food
--

ALTER TABLE ONLY levichev_food.payment
    ADD CONSTRAINT payment_transaction_id_key UNIQUE (transaction_id);


--
-- TOC entry 3838 (class 2606 OID 16887)
-- Name: product_category product_category_pkey; Type: CONSTRAINT; Schema: levichev_food
--

ALTER TABLE ONLY levichev_food.product_category
    ADD CONSTRAINT product_category_pkey PRIMARY KEY (product_category_id);


--
-- TOC entry 3840 (class 2606 OID 16889)
-- Name: product_category product_category_product_category_name_key; Type: CONSTRAINT; Schema: levichev_food
--

ALTER TABLE ONLY levichev_food.product_category
    ADD CONSTRAINT product_category_product_category_name_key UNIQUE (product_category_name);


--
-- TOC entry 3842 (class 2606 OID 16899)
-- Name: product product_pkey; Type: CONSTRAINT; Schema: levichev_food
--

ALTER TABLE ONLY levichev_food.product
    ADD CONSTRAINT product_pkey PRIMARY KEY (product_id);


--
-- TOC entry 3834 (class 2606 OID 17355)
-- Name: restaurant restaurant_address_id_unique; Type: CONSTRAINT; Schema: levichev_food
--

ALTER TABLE ONLY levichev_food.restaurant
    ADD CONSTRAINT restaurant_address_id_unique UNIQUE (address_id);


--
-- TOC entry 3836 (class 2606 OID 16876)
-- Name: restaurant restaurant_pkey; Type: CONSTRAINT; Schema: levichev_food
--

ALTER TABLE ONLY levichev_food.restaurant
    ADD CONSTRAINT restaurant_pkey PRIMARY KEY (restaurant_id);


--
-- TOC entry 3861 (class 2606 OID 17031)
-- Name: review review_order_id_entity_type_entity_id_key; Type: CONSTRAINT; Schema: levichev_food
--

ALTER TABLE ONLY levichev_food.review
    ADD CONSTRAINT review_order_id_entity_type_entity_id_key UNIQUE (order_id, entity_type, entity_id);


--
-- TOC entry 3863 (class 2606 OID 17029)
-- Name: review review_pkey; Type: CONSTRAINT; Schema: levichev_food
--

ALTER TABLE ONLY levichev_food.review
    ADD CONSTRAINT review_pkey PRIMARY KEY (review_id);


--
-- TOC entry 3855 (class 1259 OID 17015)
-- Name: payment_one_success_per_order; Type: INDEX; Schema: levichev_food
--

CREATE UNIQUE INDEX payment_one_success_per_order ON levichev_food.payment USING btree (order_id) WHERE (status = 'успех'::levichev_food.payment_status);


--
-- TOC entry 3880 (class 2620 OID 17049)
-- Name: order order_address_check_trigger; Type: TRIGGER; Schema: levichev_food
--

CREATE TRIGGER order_address_check_trigger BEFORE INSERT OR UPDATE OF client_id, address_id ON levichev_food."order" FOR EACH ROW EXECUTE FUNCTION levichev_food.check_order_address();


--
-- TOC entry 3882 (class 2620 OID 17051)
-- Name: order_structure order_product_restaurant_check_trigger; Type: TRIGGER; Schema: levichev_food
--

CREATE TRIGGER order_product_restaurant_check_trigger BEFORE INSERT OR UPDATE OF order_id, product_id ON levichev_food.order_structure FOR EACH ROW EXECUTE FUNCTION levichev_food.check_order_product_restaurant();


--
-- TOC entry 3881 (class 2620 OID 17053)
-- Name: order order_restaurant_change_trigger; Type: TRIGGER; Schema: levichev_food
--

CREATE TRIGGER order_restaurant_change_trigger BEFORE UPDATE OF restaurant_id ON levichev_food."order" FOR EACH ROW EXECUTE FUNCTION levichev_food.check_order_restaurant_change();


--
-- TOC entry 3883 (class 2620 OID 17017)
-- Name: payment payment_amount_check_trigger; Type: TRIGGER; Schema: levichev_food
--

CREATE TRIGGER payment_amount_check_trigger BEFORE INSERT OR UPDATE OF order_id, amount ON levichev_food.payment FOR EACH ROW EXECUTE FUNCTION levichev_food.check_payment_amount();


--
-- TOC entry 3884 (class 2620 OID 17019)
-- Name: payment payment_status_sync_trigger; Type: TRIGGER; Schema: levichev_food
--

CREATE TRIGGER payment_status_sync_trigger AFTER INSERT OR DELETE OR UPDATE ON levichev_food.payment FOR EACH ROW EXECUTE FUNCTION levichev_food.sync_order_pay_status();


--
-- TOC entry 3879 (class 2620 OID 17055)
-- Name: product product_restaurant_change_trigger; Type: TRIGGER; Schema: levichev_food
--

CREATE TRIGGER product_restaurant_change_trigger BEFORE UPDATE OF restaurant_id ON levichev_food.product FOR EACH ROW EXECUTE FUNCTION levichev_food.check_product_restaurant_change();


--
-- TOC entry 3885 (class 2620 OID 17243)
-- Name: review rating_change_trigger; Type: TRIGGER; Schema: levichev_food
--

CREATE TRIGGER rating_change_trigger AFTER INSERT OR DELETE OR UPDATE ON levichev_food.review FOR EACH ROW EXECUTE FUNCTION levichev_food.rating_change();


--
-- TOC entry 3886 (class 2620 OID 17043)
-- Name: review review_client_check_trigger; Type: TRIGGER; Schema: levichev_food
--

CREATE TRIGGER review_client_check_trigger BEFORE INSERT OR UPDATE OF client_id, order_id ON levichev_food.review FOR EACH ROW EXECUTE FUNCTION levichev_food.check_review_client();


--
-- TOC entry 3887 (class 2620 OID 17045)
-- Name: review review_product_check_trigger; Type: TRIGGER; Schema: levichev_food
--

CREATE TRIGGER review_product_check_trigger BEFORE INSERT OR UPDATE OF order_id, entity_id, entity_type ON levichev_food.review FOR EACH ROW EXECUTE FUNCTION levichev_food.check_review_product();


--
-- TOC entry 3867 (class 2606 OID 16931)
-- Name: client_address client_address_address_id_fkey; Type: FK CONSTRAINT; Schema: levichev_food
--

ALTER TABLE ONLY levichev_food.client_address
    ADD CONSTRAINT client_address_address_id_fkey FOREIGN KEY (address_id) REFERENCES levichev_food.address(address_id);


--
-- TOC entry 3868 (class 2606 OID 16926)
-- Name: client_address client_address_client_id_fkey; Type: FK CONSTRAINT; Schema: levichev_food
--

ALTER TABLE ONLY levichev_food.client_address
    ADD CONSTRAINT client_address_client_id_fkey FOREIGN KEY (client_id) REFERENCES levichev_food.client(client_id);


--
-- TOC entry 3869 (class 2606 OID 16945)
-- Name: courier_pay courier_pay_courier_id_fkey; Type: FK CONSTRAINT; Schema: levichev_food
--

ALTER TABLE ONLY levichev_food.courier_pay
    ADD CONSTRAINT courier_pay_courier_id_fkey FOREIGN KEY (courier_id) REFERENCES levichev_food.courier(courier_id);


--
-- TOC entry 3870 (class 2606 OID 16974)
-- Name: order order_address_id_fkey; Type: FK CONSTRAINT; Schema: levichev_food
--

ALTER TABLE ONLY levichev_food."order"
    ADD CONSTRAINT order_address_id_fkey FOREIGN KEY (address_id) REFERENCES levichev_food.address(address_id);


--
-- TOC entry 3871 (class 2606 OID 16969)
-- Name: order order_client_id_fkey; Type: FK CONSTRAINT; Schema: levichev_food
--

ALTER TABLE ONLY levichev_food."order"
    ADD CONSTRAINT order_client_id_fkey FOREIGN KEY (client_id) REFERENCES levichev_food.client(client_id);


--
-- TOC entry 3872 (class 2606 OID 16964)
-- Name: order order_courier_id_fkey; Type: FK CONSTRAINT; Schema: levichev_food
--

ALTER TABLE ONLY levichev_food."order"
    ADD CONSTRAINT order_courier_id_fkey FOREIGN KEY (courier_id) REFERENCES levichev_food.courier(courier_id);


--
-- TOC entry 3873 (class 2606 OID 16979)
-- Name: order order_restaurant_id_fkey; Type: FK CONSTRAINT; Schema: levichev_food
--

ALTER TABLE ONLY levichev_food."order"
    ADD CONSTRAINT order_restaurant_id_fkey FOREIGN KEY (restaurant_id) REFERENCES levichev_food.restaurant(restaurant_id);


--
-- TOC entry 3874 (class 2606 OID 16990)
-- Name: order_structure order_structure_order_id_fkey; Type: FK CONSTRAINT; Schema: levichev_food
--

ALTER TABLE ONLY levichev_food.order_structure
    ADD CONSTRAINT order_structure_order_id_fkey FOREIGN KEY (order_id) REFERENCES levichev_food."order"(order_id);


--
-- TOC entry 3875 (class 2606 OID 16995)
-- Name: order_structure order_structure_product_id_fkey; Type: FK CONSTRAINT; Schema: levichev_food
--

ALTER TABLE ONLY levichev_food.order_structure
    ADD CONSTRAINT order_structure_product_id_fkey FOREIGN KEY (product_id) REFERENCES levichev_food.product(product_id);


--
-- TOC entry 3876 (class 2606 OID 17010)
-- Name: payment payment_order_id_fkey; Type: FK CONSTRAINT; Schema: levichev_food
--

ALTER TABLE ONLY levichev_food.payment
    ADD CONSTRAINT payment_order_id_fkey FOREIGN KEY (order_id) REFERENCES levichev_food."order"(order_id);


--
-- TOC entry 3865 (class 2606 OID 16900)
-- Name: product product_product_category_id_fkey; Type: FK CONSTRAINT; Schema: levichev_food
--

ALTER TABLE ONLY levichev_food.product
    ADD CONSTRAINT product_product_category_id_fkey FOREIGN KEY (product_category_id) REFERENCES levichev_food.product_category(product_category_id);


--
-- TOC entry 3866 (class 2606 OID 16905)
-- Name: product product_restaurant_id_fkey; Type: FK CONSTRAINT; Schema: levichev_food
--

ALTER TABLE ONLY levichev_food.product
    ADD CONSTRAINT product_restaurant_id_fkey FOREIGN KEY (restaurant_id) REFERENCES levichev_food.restaurant(restaurant_id);


--
-- TOC entry 3864 (class 2606 OID 16877)
-- Name: restaurant restaurant_address_id_fkey; Type: FK CONSTRAINT; Schema: levichev_food
--

ALTER TABLE ONLY levichev_food.restaurant
    ADD CONSTRAINT restaurant_address_id_fkey FOREIGN KEY (address_id) REFERENCES levichev_food.address(address_id);


--
-- TOC entry 3877 (class 2606 OID 17032)
-- Name: review review_client_id_fkey; Type: FK CONSTRAINT; Schema: levichev_food
--

ALTER TABLE ONLY levichev_food.review
    ADD CONSTRAINT review_client_id_fkey FOREIGN KEY (client_id) REFERENCES levichev_food.client(client_id);


--
-- TOC entry 3878 (class 2606 OID 17037)
-- Name: review review_order_id_fkey; Type: FK CONSTRAINT; Schema: levichev_food
--

ALTER TABLE ONLY levichev_food.review
    ADD CONSTRAINT review_order_id_fkey FOREIGN KEY (order_id) REFERENCES levichev_food."order"(order_id);


--
-- TOC entry 4039 (class 0 OID 0)
-- Dependencies: 9
-- Name: SCHEMA levichev_food; Type: ACL; Schema: -
--



--
-- TOC entry 4040 (class 0 OID 0)
-- Dependencies: 277
-- Name: PROCEDURE add_product(IN p_product_name character varying, IN p_product_category_id uuid, IN p_price numeric, IN p_restaurant_id uuid, IN p_photo_url text, IN p_rating numeric, IN p_status levichev_food.product_status, IN p_description text); Type: ACL; Schema: levichev_food
--



--
-- TOC entry 4041 (class 0 OID 0)
-- Dependencies: 268
-- Name: FUNCTION check_order_address(); Type: ACL; Schema: levichev_food
--



--
-- TOC entry 4042 (class 0 OID 0)
-- Dependencies: 269
-- Name: FUNCTION check_order_product_restaurant(); Type: ACL; Schema: levichev_food
--



--
-- TOC entry 4043 (class 0 OID 0)
-- Dependencies: 270
-- Name: FUNCTION check_order_restaurant_change(); Type: ACL; Schema: levichev_food
--



--
-- TOC entry 4044 (class 0 OID 0)
-- Dependencies: 264
-- Name: FUNCTION check_payment_amount(); Type: ACL; Schema: levichev_food
--



--
-- TOC entry 4045 (class 0 OID 0)
-- Dependencies: 271
-- Name: FUNCTION check_product_restaurant_change(); Type: ACL; Schema: levichev_food
--



--
-- TOC entry 4046 (class 0 OID 0)
-- Dependencies: 266
-- Name: FUNCTION check_review_client(); Type: ACL; Schema: levichev_food
--



--
-- TOC entry 4047 (class 0 OID 0)
-- Dependencies: 267
-- Name: FUNCTION check_review_product(); Type: ACL; Schema: levichev_food
--



--
-- TOC entry 4048 (class 0 OID 0)
-- Dependencies: 279
-- Name: PROCEDURE courier_salary(); Type: ACL; Schema: levichev_food
--



--
-- TOC entry 4049 (class 0 OID 0)
-- Dependencies: 263
-- Name: PROCEDURE erase_test_data(); Type: ACL; Schema: levichev_food
--



--
-- TOC entry 4050 (class 0 OID 0)
-- Dependencies: 259
-- Name: PROCEDURE generate_client_addresses(); Type: ACL; Schema: levichev_food
--



--
-- TOC entry 4051 (class 0 OID 0)
-- Dependencies: 274
-- Name: PROCEDURE generate_courier_pay(); Type: ACL; Schema: levichev_food
--



--
-- TOC entry 4052 (class 0 OID 0)
-- Dependencies: 276
-- Name: PROCEDURE generate_couriers(IN value integer); Type: ACL; Schema: levichev_food
--



--
-- TOC entry 4053 (class 0 OID 0)
-- Dependencies: 260
-- Name: PROCEDURE generate_order_structure(); Type: ACL; Schema: levichev_food
--



--
-- TOC entry 4054 (class 0 OID 0)
-- Dependencies: 272
-- Name: PROCEDURE generate_orders(); Type: ACL; Schema: levichev_food
--



--
-- TOC entry 4055 (class 0 OID 0)
-- Dependencies: 262
-- Name: PROCEDURE generate_payments(); Type: ACL; Schema: levichev_food
--



--
-- TOC entry 4056 (class 0 OID 0)
-- Dependencies: 280
-- Name: PROCEDURE generate_product_categories(IN value integer); Type: ACL; Schema: levichev_food
--



--
-- TOC entry 4057 (class 0 OID 0)
-- Dependencies: 258
-- Name: PROCEDURE generate_products(IN value integer); Type: ACL; Schema: levichev_food
--



--
-- TOC entry 4058 (class 0 OID 0)
-- Dependencies: 257
-- Name: PROCEDURE generate_restaurants(IN value integer); Type: ACL; Schema: levichev_food
--



--
-- TOC entry 4059 (class 0 OID 0)
-- Dependencies: 261
-- Name: PROCEDURE generate_reviews(); Type: ACL; Schema: levichev_food
--



--
-- TOC entry 4060 (class 0 OID 0)
-- Dependencies: 278
-- Name: FUNCTION get_statistic(); Type: ACL; Schema: levichev_food
--



--
-- TOC entry 4061 (class 0 OID 0)
-- Dependencies: 275
-- Name: PROCEDURE insert_test_data(IN value integer); Type: ACL; Schema: levichev_food
--



--
-- TOC entry 4062 (class 0 OID 0)
-- Dependencies: 245
-- Name: FUNCTION rating_change(); Type: ACL; Schema: levichev_food
--



--
-- TOC entry 4063 (class 0 OID 0)
-- Dependencies: 273
-- Name: PROCEDURE recalculate_order_amounts(); Type: ACL; Schema: levichev_food
--



--
-- TOC entry 4064 (class 0 OID 0)
-- Dependencies: 265
-- Name: FUNCTION sync_order_pay_status(); Type: ACL; Schema: levichev_food
--



--
-- TOC entry 4065 (class 0 OID 0)
-- Dependencies: 222
-- Name: TABLE address; Type: ACL; Schema: levichev_food
--



--
-- TOC entry 4066 (class 0 OID 0)
-- Dependencies: 223
-- Name: TABLE client; Type: ACL; Schema: levichev_food
--



--
-- TOC entry 4067 (class 0 OID 0)
-- Dependencies: 228
-- Name: TABLE client_address; Type: ACL; Schema: levichev_food
--



--
-- TOC entry 4068 (class 0 OID 0)
-- Dependencies: 227
-- Name: TABLE courier; Type: ACL; Schema: levichev_food
--



--
-- TOC entry 4069 (class 0 OID 0)
-- Dependencies: 229
-- Name: TABLE courier_pay; Type: ACL; Schema: levichev_food
--



--
-- TOC entry 4070 (class 0 OID 0)
-- Dependencies: 230
-- Name: TABLE "order"; Type: ACL; Schema: levichev_food
--



--
-- TOC entry 4071 (class 0 OID 0)
-- Dependencies: 234
-- Name: TABLE how_much_money; Type: ACL; Schema: levichev_food
--



--
-- TOC entry 4072 (class 0 OID 0)
-- Dependencies: 231
-- Name: TABLE order_structure; Type: ACL; Schema: levichev_food
--



--
-- TOC entry 4073 (class 0 OID 0)
-- Dependencies: 232
-- Name: TABLE payment; Type: ACL; Schema: levichev_food
--



--
-- TOC entry 4074 (class 0 OID 0)
-- Dependencies: 226
-- Name: TABLE product; Type: ACL; Schema: levichev_food
--



--
-- TOC entry 4075 (class 0 OID 0)
-- Dependencies: 225
-- Name: TABLE product_category; Type: ACL; Schema: levichev_food
--



--
-- TOC entry 4076 (class 0 OID 0)
-- Dependencies: 224
-- Name: TABLE restaurant; Type: ACL; Schema: levichev_food
--



--
-- TOC entry 4077 (class 0 OID 0)
-- Dependencies: 233
-- Name: TABLE review; Type: ACL; Schema: levichev_food
--



-- Completed on 2026-11-13 20:22:59 MSK

--
-- PostgreSQL database dump complete
--


