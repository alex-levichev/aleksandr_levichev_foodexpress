# Протокол выполненных проверок FoodExpress

Документ содержит **только проверки, для которых зафиксирован успешный результат**. Отсутствие отдельной проверки в этом отчёте не означает, что соответствующее бизнес-требование отменено или полностью проверено.

## Окружение

| Параметр | Значение |
|---|---|
| PostgreSQL | 17.11 (Homebrew) |
| Дата | 13.11.2026; часть проверок проведена ранее |
| Рабочая база | `foodexpress` |
| База для проверки восстановления | `foodexpress_restore_test` |
| Схема | `levichev_food` |
| Роль для проверки прав | `inspector` |

**Восстановление:** Custom-бэкап восстановлен с 0 ошибок после предварительной установки `exts` и `uuid-ossp`. Согласно BR-13.3, эта схема и расширение должны существовать в целевом окружении. Для запуска процедур от `inspector` необходим `GRANT USAGE ON SCHEMA exts TO inspector;`.

Примеры SQL в разделах ниже — команды проверки; часть фактических результатов получена эквивалентными агрегирующими запросами. Значения и статусы указаны только там, где они подтверждены.

## A. Подготовка

### A.1. Восстановление бэкапа

Ожидается: без ошибок.
Факт: Custom-бэкап `foodexpress_levichev.backup` восстановлен в отдельную базу с 0 ошибок; 12 таблиц, 20 ресторанов, 100 блюд, 100 заказов, 100 отзывов. Первоначальная попытка без `exts` завершилась ошибками; перед успешным восстановлением создана схема `exts` и установлено `uuid-ossp`.
Вердикт: OK (при условии предварительной установки `exts` и `uuid-ossp`)

### A.2. Переключение на inspector

```sql
SET ROLE inspector;
SET search_path TO levichev_food, exts;
SELECT current_user;
```

Ожидается: `inspector`.
Факт: В транзакции `SET LOCAL ROLE inspector` выполнен; основные процедуры запустились без ошибки после выдачи `USAGE` на `exts`.
Вердикт: OK (подтверждено запуском процедур под ролью)

---

## B. FOOD-101: Структура схемы


### B.1. Схема существует

```sql
SELECT schema_name FROM information_schema.schemata
WHERE schema_name LIKE '%_food';
```

Ожидается: `levichev_food`.
Факт: Схема `levichev_food` существует; запросы к её таблицам выполнялись.
Вердикт: OK (проверено ранее)

### B.2. Схема `exts` с `uuid-ossp`

```sql
SELECT extname, extnamespace::regnamespace AS schema
FROM pg_extension WHERE extname = 'uuid-ossp';
```

Ожидается: `uuid-ossp`, схема `exts`.
Факт: `uuid-ossp` найдено в схеме `exts` тестовой базы.
Вердикт: OK (13.11.2026)

### B.3. Все 12 исходных таблиц + N после нормализации

```sql
SELECT table_name FROM information_schema.tables
WHERE table_schema = 'levichev_food'
ORDER BY table_name;
```

Ожидается: `address`, `client`, `client_address`, `courier`, `courier_pay`, `order`, `order_structure`, `payment`, `product`, `product_category`, `restaurant`, `review` (12 + N штук).
Факт: В схеме созданы 12 таблиц: address, client, client_address, courier, courier_pay, order, order_structure, payment, product, product_category, restaurant, review.
Вердикт: OK (проверено ранее)

### B.5. Enum-типы

```sql
SELECT t.typname, array_agg(e.enumlabel ORDER BY e.enumsortorder) AS values
FROM pg_type t
JOIN pg_enum e ON t.oid = e.enumtypid
JOIN pg_namespace n ON n.oid = t.typnamespace
WHERE n.nspname = 'levichev_food'
GROUP BY t.typname
ORDER BY t.typname;
```

Ожидается: 8 типов со значениями из constraints.md.
Факт: Созданы 8 ENUM-типов, состав и значения ранее проверены.
Вердикт: OK (проверено ранее)

### B.6. FK-ограничения

```sql
SELECT conname, conrelid::regclass AS tbl, confrelid::regclass AS ref
FROM pg_constraint
WHERE contype = 'f'
  AND connamespace = 'levichev_food'::regnamespace
ORDER BY tbl, conname;
```

Ожидается: не менее 15 FK, все из erd.md.
Факт: 15 внешних ключей; `convalidated = false` у 0 ограничений. Прямой анти-JOIN по всем связям отдельно не выполнялся.
Вердикт: OK (наличие и валидность ограничений FK)

### B.7. Пароль — MD5

```sql
SELECT length(password) AS len, password
FROM client LIMIT 5;
```

Ожидается: `len = 32`, hex-строка.
Факт: 20 клиентов; 20 паролей соответствуют шаблону 32 шестнадцатеричных символов; 0 несоответствий. Проверен формат, не происхождение хеша.
Вердикт: OK (формат MD5, 13.11.2026)

---

## C. FOOD-102: `insert_test_data(value)`


### C.1. Чистая схема

```sql
CALL erase_test_data();
```

Ожидается: без ошибок.
Факт: Ранее `erase_test_data()` выполнялась успешно.
Вердикт: OK (проверено ранее)

### C.2. Первый запуск

```sql
CALL insert_test_data(10);
```

Ожидается: без ошибок.
Факт: Ранее `insert_test_data(10)` выполнялась успешно.
Вердикт: OK (проверено ранее)

### C.3. Распределение строк (BR-11.7)

```sql
SELECT 'client' AS tbl, count(*) FROM client
UNION ALL SELECT 'courier', count(*) FROM courier
UNION ALL SELECT 'product_category', count(*) FROM product_category
UNION ALL SELECT 'restaurant', count(*) FROM restaurant
UNION ALL SELECT 'address', count(*) FROM address
UNION ALL SELECT 'product', count(*) FROM product
UNION ALL SELECT 'order', count(*) FROM "order"
UNION ALL SELECT 'review', count(*) FROM review
UNION ALL SELECT 'payment', count(*) FROM payment
ORDER BY tbl;
```

Ожидается: 10, 10, 10, 10, 50, 50, 50, 50, 50.
Факт: Ранее проверено распределение после генерации 10; позже набор перегенерирован с параметром 20.
Вердикт: OK (проверено ранее)

### C.4. Адреса ресторанов vs клиентов (BR-11.7)

```sql
SELECT 'restaurant addresses' AS cat, count(*) FROM restaurant WHERE address_id IS NOT NULL
UNION ALL
SELECT 'total addresses', count(*) FROM address;
```

Ожидается: 10 ресторанных адресов, 50 всего → 40 клиентских.
Факт: 20 ресторанов, 20 уникальных ресторанных адресов, 100 адресов всего при параметре генерации 20.
Вердикт: OK (13.11.2026)

### C.5. Нет пустых строк (BR-11.3)

```sql
SELECT count(*) FROM client WHERE login = '' OR password = '' OR phone_number = '';
-- и аналогично для других varchar-полей с NOT NULL
```

Ожидается: 0.
Факт: Проверены все 15 обязательных текстовых полей динамическим SQL: «ИТОГО пустых строк: 0».
Вердикт: OK (13.11.2026)

### C.6. Нет NULL там, где запрещено (BR-11.3)

```sql
SELECT count(*) FROM "order" WHERE client_id IS NULL OR restaurant_id IS NULL
  OR courier_id IS NULL OR address_id IS NULL OR total_amount IS NULL;
-- и аналогично для других NOT NULL полей
```

Ожидается: 0.
Факт: В заказах 0 NULL в проверенных обязательных полях `client_id`, `restaurant_id`, `courier_id`, `address_id`, `total_amount`; остальные NOT NULL поля не проверялись отдельным сканированием данных.
Вердикт: OK (для указанных полей; остальные защищены NOT NULL)

### C.7. Минимум один активный курьер (BR-6.6)

```sql
SELECT count(*) FROM courier WHERE status != 'уволен';
```

Ожидается: `>= 1`.
Факт: 20 курьеров со статусом, отличным от «уволен».
Вердикт: OK (13.11.2026)

### C.8. `courier_pay` консистентен с правилами (BR-10.2)

```sql
SELECT cp.year, cp.month, cp.courier_id, cp.amount, cp.coefficient_used,
       round(coalesce((
           SELECT sum(o.commission)
           FROM "order" o
           WHERE o.courier_id = cp.courier_id
             AND o.status = 'доставлен'
             AND extract(year  from o.order_timestamp) = cp.year
             AND extract(month from o.order_timestamp) = cp.month
       ), 0) * cp.coefficient_used, 2) AS expected_amount
FROM courier_pay cp
LIMIT 20;
```

Ожидается: `amount = expected_amount` в каждой строке.
Факт: Проверены все 120 строк `courier_pay`: `incorrect_payments = 0` при сверке суммы комиссий доставленных заказов × `coefficient_used`.
Вердикт: OK (13.11.2026)

### C.9. Повторный вызов не ломает

```sql
DO $$
BEGIN
    FOR i IN 1..10 LOOP
        CALL insert_test_data(10);
    END LOOP;
END $$;
```

Ожидается: без ошибок, данные добавляются или заменяются (по решению студента, задокументированному в constraints.md).
Факт: Повторные вызовы `insert_test_data(10)` ранее проходили без ошибок.
Вердикт: OK (проверено ранее)

---

## D. Проверки бизнес-правил на сгенерированных данных

## D. Проверки бизнес-правил

### D.2. Минимальная сумма заказа (BR-1.8)

```sql
SELECT count(*) FROM "order" WHERE total_amount < 1000;
```

Ожидается: 0.
Факт: Заказов с `total_amount < 1000`: 0.
Вердикт: OK (13.11.2026)

### D.3. Комиссия = 10% (BR-1.4)

```sql
SELECT count(*) FROM "order" WHERE round(order_amount * 0.10, 2) != commission;
```

Ожидается: 0.
Факт: Заказов с неверной комиссией 10%: 0.
Вердикт: OK (13.11.2026)

### D.4. `total_amount = order_amount + commission`

```sql
SELECT count(*) FROM "order"
WHERE round(order_amount + commission, 2) != total_amount;
```

Ожидается: 0.
Факт: Заказов с неверной итоговой суммой: 0.
Вердикт: OK (13.11.2026)

### D.5. Дата доставки не раньше создания (BR-7.13)

```sql
SELECT count(*) FROM "order"
WHERE delivery_timestamp IS NOT NULL AND delivery_timestamp < order_timestamp;
```

Ожидается: 0.
Факт: Заказов с датой доставки раньше создания: 0.
Вердикт: OK (13.11.2026)

### D.6. Адрес доставки принадлежит клиенту (BR-7.4)

```sql
SELECT count(*) FROM "order" o
LEFT JOIN client_address ca
  ON ca.client_id = o.client_id AND ca.address_id = o.address_id
WHERE ca.client_id IS NULL;
```

Ожидается: 0.
Факт: Заказов с адресом, не принадлежащим клиенту: 0.
Вердикт: OK (13.11.2026)

### D.7. Все блюда в заказе из одного ресторана (BR-7.3)

```sql
SELECT count(DISTINCT os.order_id)
FROM order_structure os
JOIN "order" o ON os.order_id = o.order_id
JOIN product p ON os.product_id = p.product_id
WHERE p.restaurant_id != o.restaurant_id;
```

Ожидается: 0.
Факт: Позиций заказа с блюдом другого ресторана: 0.
Вердикт: OK (13.11.2026)

### D.9. Сумма оплаты = `total_amount` заказа (BR-8.4)

```sql
SELECT count(*) FROM payment p
JOIN "order" o ON p.order_id = o.order_id
WHERE p.amount != o.total_amount;
```

Ожидается: 0.
Факт: Оплат с суммой, отличной от `order.total_amount`: 0.
Вердикт: OK (13.11.2026)

### D.10. Нет дубликатов в `client_address` (BR-2.5)

```sql
SELECT client_id, address_id, count(*)
FROM client_address
GROUP BY client_id, address_id
HAVING count(*) > 1;
```

Ожидается: пусто.
Факт: Повторяющихся пар `client_id`, `address_id`: 0.
Вердикт: OK (13.11.2026)

### D.11. Нет дубликатов в `order_structure` (BR-7.16)

```sql
SELECT order_id, product_id, count(*)
FROM order_structure
GROUP BY order_id, product_id
HAVING count(*) > 1;
```

Ожидается: пусто.
Факт: Повторяющихся пар `order_id`, `product_id`: 0.
Вердикт: OK (13.11.2026)

### D.12. `work_end > work_start` (BR-4.4)

```sql
SELECT count(*) FROM restaurant WHERE work_end <= work_start;
```

Ожидается: 0.
Факт: Ресторанов с `work_end <= work_start`: 0.
Вердикт: OK (13.11.2026)

### D.13. `dismissal_date >= hire_date` (BR-6.3)

```sql
SELECT count(*) FROM courier
WHERE dismissal_date IS NOT NULL AND dismissal_date < hire_date;
```

Ожидается: 0.
Факт: Курьеров с `dismissal_date < hire_date`: 0.
Вердикт: OK (13.11.2026)

### D.14. Рейтинг блюд/ресторанов соответствует отзывам (BR-9.6)

```sql
-- product.rating = AVG(review.rating) по отзывам на блюдо
SELECT p.product_id, p.rating,
       (SELECT round(avg(r.rating), 2) FROM review r
        WHERE r.entity_type = 'блюдо' AND r.entity_id = p.product_id) AS expected
FROM product p
WHERE p.rating IS NOT NULL
LIMIT 20;
```

Ожидается: `rating = expected`.
Факт: Несоответствий средних рейтингов отзывам: 0 у блюд и 0 у ресторанов (включая NULL через `IS DISTINCT FROM`).
Вердикт: OK (13.11.2026)

---

## E. Функции и процедуры


### E.1. `add_product` — успешный вызов

```sql
SELECT count(*) AS before FROM product;

CALL add_product(
    p_restaurant_id => (SELECT restaurant_id FROM restaurant LIMIT 1),
    p_product_category_id => (SELECT product_category_id FROM product_category LIMIT 1),
    p_name => 'Тестовое блюдо',
    p_price => 250,
    p_rating => 4.5,
    p_status => 'доступно',
    p_description => 'Описание'
    -- + photo_url если есть
);

SELECT count(*) AS after FROM product;
```

Ожидается: `after = before + 1`.
Факт: Успешный вызов `add_product` ранее проверен.
Вердикт: OK (проверено ранее)

### E.2. `add_product` — падает на несуществующий ресторан

```sql
CALL add_product(
    p_restaurant_id => '00000000-0000-0000-0000-000000000000',
    -- остальные аргументы
);
```

Ожидается: ошибка с внятным сообщением.
Факт: Ошибка для несуществующего ресторана ранее проверена.
Вердикт: OK (проверено ранее)

### E.3. `rating_change` — пересчитывает рейтинг

```sql
-- Выбрать заказ, блюдо и клиента
SELECT p.product_id, p.rating FROM product p WHERE p.rating IS NOT NULL LIMIT 1;

-- Вставить отзыв на это блюдо
INSERT INTO review (review_id, client_id, review_timestamp, entity_id, entity_type, order_id, description, rating)
VALUES (
    exts.uuid_generate_v4(),
    (SELECT client_id FROM client LIMIT 1),
    localtimestamp,
    <product_id>,
    'блюдо',
    (SELECT order_id FROM "order" LIMIT 1),
    'Тестовый отзыв',
    5
);

SELECT rating FROM product WHERE product_id = <product_id>;
```

Ожидается: `rating` пересчитан.
Факт: Триггер `rating_change` ранее проверен при изменении отзывов.
Вердикт: OK (проверено ранее)

### E.4. `rating_change` — удаление отзыва

```sql
-- Удалить отзыв из E.3
DELETE FROM review WHERE review_id = <review_id>;

SELECT rating FROM product WHERE product_id = <product_id>;
```

Ожидается: если других отзывов нет — `rating IS NULL`; иначе — пересчитан.
Факт: Пересчёт после удаления отзыва ранее проверен.
Вердикт: OK (проверено ранее)

### E.5. `get_statistic()`

```sql
SELECT * FROM get_statistic();
```

Ожидается:
- Колонки: `restaurant_name`, `best_product_name`, `total_amount`, `avg_amount`, `best_user`.
- По одной строке на ресторан.
- `best_user` = `client.login` (не NULL при наличии заказов).

Факт: Функция вернула 20 строк; сумма `total_amount` по статистике равна сумме доставленных заказов: 128 983,8.
Вердикт: OK (13.11.2026; сверка общей суммы)

### E.6. `courier_salary()`

```sql
-- До
SELECT courier_id, coefficient FROM courier ORDER BY courier_id;

CALL courier_salary();

-- После
SELECT courier_id, coefficient FROM courier ORDER BY courier_id;
SELECT year, month, courier_id, amount, coefficient_used
FROM courier_pay
ORDER BY year DESC, month DESC, courier_id
LIMIT 20;
```

Ожидается:
- `courier.coefficient` пересчитан для работающих (по BR-10.2).
- У уволенных — не изменился.
- `courier_pay` содержит запись за текущий месяц.

Факт: `courier_salary()` ранее выполнялась; сверялись начисления и коэффициенты.
Вердикт: OK (проверено ранее)

### E.7. `courier_salary()` — повторный вызов

```sql
CALL courier_salary();
SELECT count(*) FROM courier_pay
WHERE year = extract(year from current_date)
  AND month = extract(month from current_date);
```

Ожидается: количество не изменилось (idempotency / обновление).
Факт: Повторный запуск `courier_salary()` ранее проверялся без дублирования строк.
Вердикт: OK (проверено ранее)

---

## F. Представление `how_much_money`

## F. Представление how_much_money

### F.1. Колонки

```sql
SELECT column_name, data_type
FROM information_schema.columns
WHERE table_schema = 'levichev_food'
  AND table_name = 'how_much_money'
ORDER BY ordinal_position;
```

Ожидается: `year_month` (text), `sum_no_commission`, `sum_with_commission`, `commission`, `prev_commission`, `commission_diff`, `courier_pay`, `net_profit` (numeric).
Факт: Представление `how_much_money` создано и ранее проверялось.
Вердикт: OK (проверено ранее)

### F.2. Месяцы покрыты

```sql
SELECT * FROM how_much_money ORDER BY year_month;
```

Ожидается: месяцы от первого доставленного заказа до последнего (не пропущено ни одного).
Факт: Ранее представление показывало последовательные месяцы с мая по ноябрь 2026.
Вердикт: OK (проверено ранее)

### F.3. Месяцы без заказов присутствуют (BR-11.9)

```sql
SELECT year_month FROM how_much_money
WHERE sum_no_commission = 0 OR sum_no_commission IS NULL;
```

Ожидается: если в какие-то месяцы заказов не было — они есть в результате.
Факт: Ранее проверялось наличие месяцев без заказов.
Вердикт: OK (проверено ранее)

### F.4. Корректность сумм

```sql
SELECT year_month,
       sum_no_commission,
       sum_with_commission,
       commission,
       prev_commission,
       commission_diff,
       courier_pay,
       net_profit
FROM how_much_money
ORDER BY year_month
LIMIT 10;
```

Ожидается:
- `commission = sum_with_commission - sum_no_commission`.
- `commission_diff = commission - prev_commission` (NULL для первого месяца).
- `net_profit = commission - courier_pay`.

Факт: Ранее проверялись суммы комиссии и чистой прибыли.
Вердикт: OK (проверено ранее)

---

## G. Права `inspector`

## G. Права inspector

### G.1. Права на схему

```sql
SELECT
    nspname AS schema_name,
    has_schema_privilege('inspector', nspname, 'USAGE')  AS usage,
    has_schema_privilege('inspector', nspname, 'CREATE') AS create
FROM pg_namespace
WHERE nspname = 'levichev_food';
```

Ожидается: `levichev_food`, `true`, `true` (полный доступ).
Факт: В рабочей базе `foodexpress` права `USAGE = true`, `CREATE = true` для роли `inspector`.
Вердикт: OK (13.11.2026)

### G.2. Права на таблицы

```sql
SELECT table_name, string_agg(privilege_type, ', ') AS privs
FROM information_schema.role_table_grants
WHERE grantee = 'inspector' AND table_schema = 'levichev_food'
GROUP BY table_name;
```

Ожидается: у каждой таблицы `SELECT, INSERT, UPDATE, DELETE` (или `ALL`).
Факт: У всех 12 таблиц `has_table_privilege(..., SELECT, INSERT, UPDATE, DELETE) = true`.
Вердикт: OK (13.11.2026)

### G.3. `information_schema` читается под `inspector`

```sql
SET ROLE inspector;
SELECT count(*) FROM information_schema.tables
WHERE table_schema = 'levichev_food';
RESET ROLE;
```

Ожидается: 12 + N (количество таблиц).
Факт: Под `SET LOCAL ROLE inspector` `information_schema.tables` возвращает 12 базовых таблиц.
Вердикт: OK (13.11.2026)

### G.4. `pg_catalog` читается под `inspector`

```sql
SET ROLE inspector;
SELECT count(*) FROM pg_catalog.pg_tables
WHERE schemaname = 'levichev_food';
RESET ROLE;
```

Ожидается: 12 + N.
Факт: Под `SET LOCAL ROLE inspector` `pg_catalog.pg_tables` возвращает 12 таблиц.
Вердикт: OK (13.11.2026)

## H. Оптимизация

### H.1. `EXPLAIN ANALYZE` — паттерн «избыточные подзапросы»

```sql
EXPLAIN ANALYZE
SELECT c.courier_id,
       (SELECT count(*) FROM "order" o WHERE o.courier_id = c.courier_id AND o.status = 'доставлен') AS cnt,
       (SELECT coalesce(sum(commission), 0) FROM "order" o WHERE o.courier_id = c.courier_id AND o.status = 'доставлен') AS commission_sum
FROM courier c;
```

Ожидается: два SubPlan, каждый — скан `"order"`. Время растёт линейно от числа курьеров.
Факт: План содержит два `SubPlan`; оба выполняют `Seq Scan` по `order` с `loops=20` (всего 40 сканирований). `Execution Time = 1.414 ms`.
Вердикт: OK (13.11.2026)

### H.2. `EXPLAIN ANALYZE` — паттерн «один JOIN»

```sql
EXPLAIN ANALYZE
SELECT c.courier_id,
       count(o.order_id) AS cnt,
       coalesce(sum(o.commission), 0) AS commission_sum
FROM courier c
LEFT JOIN "order" o ON o.courier_id = c.courier_id AND o.status = 'доставлен'
GROUP BY c.courier_id;
```

Ожидается: один `Hash Right Join` / `Hash Left Join`, один скан `"order"`. Время меньше, чем в H.1.
Факт: `Hash Right Join`, один `Seq Scan` по `order`, `Execution Time = 0.297 ms`; на этом запуске быстрее варианта H.1 примерно в 4,8 раза.
Вердикт: OK (13.11.2026)

## I. Очистка и повторная генерация

### I.2. Повторный `erase_test_data` не падает

```sql
CALL erase_test_data();
```

Ожидается: без ошибок.
Факт: Повторный вызов `erase_test_data()` ранее проходил без ошибок.
Вердикт: OK (проверено ранее)

### I.3. После очистки `insert_test_data` снова работает

```sql
CALL insert_test_data(10);
SELECT count(*) FROM "order";
```

Ожидается: 50.
Факт: После очистки вызов `insert_test_data(10)` создал 50 заказов; журнал DBeaver: «ПОСЛЕ ОЧИСТКИ: 0», «ПОСЛЕ ГЕНЕРАЦИИ: 50». После `ROLLBACK` исходные 100 заказов сохранены.
Вердикт: OK (13.11.2026)

## Итог

Проверки с зафиксированными успешными результатами перечислены выше.
