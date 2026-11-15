# Обоснование ограничений — FoodExpress

Схема: `levichev_food`. Скрипты: `db/schema/01_schema.sql` … `08_how_much_money.sql`, права — `db/schema/grants.sql`.
Источник требований — `docs/company-rules.md` (ссылки `BR-N.M`) и `docs/backlog.md` (`FOOD-NNN`).

Правила, которые можно выразить в схеме, проверяет сама БД (`NOT NULL`, `CHECK`, `UNIQUE`, `FK`, в том числе составные FK). Триггеры — только там, где правило затрагивает несколько таблиц и декларативно не выражается (BR-7.3, BR-9.2), и для агрегатов (BR-8.7, BR-9.6).

---

## Enum-типы

| Тип | Значения | BR |
|---|---|---|
| `restaurant_status` | `активен`, `неактивен` | BR-4.3, BR-11.5 |
| `product_status` | `доступно`, `нет_в_наличии`, `архив` | BR-5.5, BR-11.5 |
| `courier_status` | `свободен`, `занят`, `на_доставке`, `уволен` | BR-6.2, BR-11.5 |
| `order_status` | `создан`, `готовится`, `в_доставке`, `доставлен`, `отменён` | BR-7.7, BR-11.5 |
| `order_pay_status` | `ожидает`, `оплачен`, `ошибка` | BR-7.9, BR-11.5 |
| `payment_status` | `успех`, `ошибка`, `в_обработке` | BR-8.2, BR-11.5 |
| `payment_type` | `карта`, `наличные`, `безнал` | BR-8.2, BR-8.6, BR-11.5 |
| `review_entity_type` | `блюдо`, `ресторан`, `заказ` | BR-9.1, BR-11.5 |

Значения не добавлялись и не менялись относительно BR.

---

## Типы данных и размерность `numeric` (BR-11.6)

Размерность выбрана так, чтобы в столбец не помещались заведомо невозможные значения: при превышении СУБД выдаёт ошибку `numeric field overflow`.

| Столбец | Тип | Максимум | Почему так |
|---|---|---|---|
| `product.price` | `numeric(8,2)` | 999 999.99 ₽ | Цена одного блюда; копейки — 2 знака. |
| `order.order_amount` | `numeric(8,2)` | 999 999.99 ₽ | Стоимость блюд одного заказа (даже крупный банкет укладывается). |
| `order.commission` | `numeric(8,2)` | 99 999.99 ₽ фактически | 10% от `order_amount` (BR-1.4). |
| `order.total_amount` | `numeric(9,2)` | 1 099 999.98 ₽ фактически | `order_amount + commission` — на разряд больше, иначе переполнение при максимальном `order_amount`. |
| `payment.amount` | `numeric(9,2)` | как `total_amount` | Сумма попытки = общей сумме заказа (BR-8.4); тип совпадает, так как на пару столбцов идёт составной FK. |
| `courier_pay.amount` | `numeric(8,2)` | 999 999.99 ₽ | Зарплата курьера за месяц = коэффициент (≤ 0.5) × сумма комиссий (BR-10.2); реальная месячная зарплата курьера на порядки меньше потолка. |
| `courier.coefficient`, `courier_pay.coefficient_used` | `numeric(2,1)` | 9.9, CHECK ограничивает 0.1–0.5 | BR-10.2 задаёт коэффициенты с одним знаком после запятой: 0.1, 0.2, 0.3, 0.5. |
| `order_structure.quantity` | `numeric(5,2)` | 999.99 | Может быть дробным, например 0.5 кг (BR-7.15). |
| `product.rating`, `restaurant.rating` | `numeric(3,2)` | 9.99, CHECK 0–5 | Среднее по отзывам с точностью до сотых (BR-4.2, BR-5.4, BR-9.6). |
| `review.rating` | `numeric(2,1)` | 9.9, CHECK 1–5 | Оценка отзыва (BR-9.4). |

Строки: `client.login varchar(50)`, `client.password char(32)` (длина MD5), `phone_number char(11)` (`7XXXXXXXXXX`), `address.street varchar(100)`, `house_number` и `apartment_office varchar(10)`, `restaurant_name varchar(100)`, `courier.fio varchar(150)`, `product_category_name varchar(50)`, `product_name varchar(100)`, `transaction_id varchar(64)`; длинные описания и реквизиты — `text`. Даты — `date`, `time`, `timestamp` без часового пояса (BR-11.2).

---

## Ловушки

### Ловушка 1: `payment` — неполная сущность

**Какие атрибуты добавил в `payment` и почему** (BR-8.2):

```
payment_type          — способ оплаты именно этой попытки (BR-8.2, BR-8.6)
amount                — сумма попытки (BR-8.2), равна order.total_amount (BR-8.4)
transaction_id        — внешний ID транзакции провайдера, уникален (BR-8.3, BR-8.5)
transaction_timestamp — дата и время транзакции (BR-8.2)
status                — 'успех' / 'ошибка' / 'в_обработке' (BR-8.2)
Данные карт не хранятся (BR-1.7, BR-8.5).
```

**Где хранится тип оплаты — `payment` или `order`** (BR-8.6):

```
В payment. У заказа может быть несколько попыток разными способами
(начал картой, оплатил наличными) — тип относится к попытке, а не к заказу.
В "order" хранится только агрегированный pay_status (BR-7.8), его поддерживает
триггер payment_status_sync_tg (см. раздел «Триггеры»).
```

### Ловушка 2: `order.address_id` — принадлежность клиенту (BR-7.4)

```
Составной FK, без триггера:
  "order" (client_id, address_id) → client_address (client_id, address_id)
Целевая пара — первичный ключ client_address, поэтому заказ можно оформить только
на адрес, который привязан именно к этому клиенту. Отдельные FK order.client_id → client
и order.address_id → address тоже есть (они из erd.md).
```

### Ловушка 3: `order_structure` — один ресторан в заказе (BR-7.3)

```
Триггер. Декларативно это можно сделать только добавив restaurant_id в order_structure
и составные FK, но restaurant_id зависел бы от части ключа (order_id) — нарушение 2НФ.
Поэтому три триггера:
  order_structure_restaurant_tg — при добавлении/изменении позиции: ресторан блюда
                                  = ресторан заказа;
  order_restaurant_change_tg    — нельзя сменить ресторан у заказа, если в нём уже
                                  есть блюда другого ресторана;
  product_restaurant_change_tg  — нельзя перенести блюдо в другой ресторан, если оно
                                  уже есть в заказах другого ресторана.
Без двух последних правило можно было бы обойти через UPDATE.
```

### Ловушка 4: `review` — полиморфизм (BR-9.1)

```
Полиморфизм: entity_type (enum) + entity_id (uuid). Обычный FK на entity_id невозможен:
он указывает то на product, то на restaurant, то на "order".
Что гарантирует БД:
  FK review(order_id) → "order"                         — отзыв привязан к заказу (BR-9.2);
  FK review(order_id, client_id) → "order"(order_id, client_id)
                                                        — отзыв оставляет только тот клиент,
                                                          который оформил заказ (BR-9.2);
  UNIQUE (order_id, entity_type, entity_id)             — не больше одного отзыва на объект
                                                          в рамках заказа (BR-9.5);
  триггер review_entity_tg                              — объект отзыва есть в этом заказе:
      'заказ'    → entity_id = order_id,
      'ресторан' → entity_id = "order".restaurant_id,
      'блюдо'    → есть позиция order_structure (order_id, entity_id).
Нормализацию (три nullable FK вместо entity_id) не выбирал: она противоречит контракту
erd.md (entity_id + entity_type) и требует CHECK «ровно одно поле заполнено».
```

---

## CHECK-ограничения

| Таблица | Ограничение | Условие | BR | Обоснование |
|---|---|---|---|---|
| `client` | `client_login_check` | `btrim(login) <> ''` | BR-2.1, BR-11.3 | Логин обязателен — пустая строка не считается логином. |
| `client` | `client_password_md5_check` | `password ~ '^[0-9a-f]{32}$'` | BR-2.3 | Пароль хранится только как MD5 (32 hex-символа), открытый пароль не пройдёт. |
| `client` | `client_phone_check` | `phone_number ~ '^7[0-9]{10}$'` | BR-2.1, BR-2.2 | Единый формат номера; иначе один телефон в разной записи обошёл бы UNIQUE. |
| `address` | `address_street_check`, `address_house_check` | `btrim(...) <> ''` | BR-3.1, BR-11.3 | Улица и дом обязательны. |
| `address` | `address_apartment_check` | `apartment_office is null or btrim(...) <> ''` | BR-3.2 | Квартиры может не быть (NULL), но не пустая строка. |
| `restaurant` | `restaurant_name_check`, `restaurant_description_check`, `restaurant_details_check` | `btrim(...) <> ''` | BR-4.1, BR-4.5, BR-11.3 | У ресторана есть название, описание и реквизиты. |
| `restaurant` | `restaurant_rating_check` | `rating between 0 and 5` | BR-4.2 | Диапазон рейтинга. |
| `restaurant` | `restaurant_work_time_check` | `work_end > work_start` | BR-4.4 | Закрытие позже открытия. |
| `product_category` | `product_category_name_check` | `btrim(...) <> ''` | BR-5.7 | У категории есть название. |
| `product` | `product_name_check`, `product_description_check` | `btrim(...) <> ''` | BR-5.2, BR-11.3 | У блюда есть название и описание. |
| `product` | `product_photo_check` | `photo_url is null or btrim(...) <> ''` | BR-5.6 | Фото необязательно, но не пустая строка. |
| `product` | `product_price_check` | `price >= 0` | BR-5.3 | Цена неотрицательна. |
| `product` | `product_rating_check` | `rating between 0 and 5` | BR-5.4 | Диапазон рейтинга. |
| `courier` | `courier_fio_check` | `btrim(fio) <> ''` | BR-6.1 | У курьера есть ФИО. |
| `courier` | `courier_phone_check` | `phone_number ~ '^7[0-9]{10}$'` | BR-6.1 | Формат телефона. |
| `courier` | `courier_coefficient_check` | `coefficient between 0.1 and 0.5` | BR-6.4 | Диапазон коэффициента. |
| `courier` | `courier_dismissal_status_check` | `status <> 'уволен' or dismissal_date is not null` | BR-6.3 | У уволенного обязательна дата увольнения. |
| `courier` | `courier_dismissal_date_check` | `dismissal_date is null or dismissal_date >= hire_date` | BR-6.1, BR-6.3 | Нельзя уволить раньше найма. |
| `courier_pay` | `courier_pay_year_check` | `year >= 2000` | BR-10.1 | Год — календарный год выплаты, защита от опечаток вроде 26. |
| `courier_pay` | `courier_pay_month_check` | `month between 1 and 12` | BR-10.1 | Выплата раз в календарный месяц. |
| `courier_pay` | `courier_pay_amount_check` | `amount >= 0` | BR-10.4 | Зарплата неотрицательна. |
| `courier_pay` | `courier_pay_coefficient_check` | `coefficient_used between 0.1 and 0.5` | BR-6.4, BR-10.2 | Применённый коэффициент из допустимого диапазона. |
| `"order"` | `order_amount_check` | `order_amount >= 0` | BR-7.10 | Стоимость блюд неотрицательна. |
| `"order"` | `order_min_total_check` | `total_amount >= 1000` | BR-1.8, BR-7.11 | Минимальная сумма заказа 1000 ₽. |
| `"order"` | `order_delivery_time_check` | `delivery_timestamp is null or delivery_timestamp >= order_timestamp` | BR-7.13 | Доставка не раньше создания. |
| `"order"` | `order_delivered_time_check` | `status <> 'доставлен' or delivery_timestamp is not null` | BR-7.12 | Доставленный заказ обязан иметь время окончания доставки. |
| `"order"` | `order_description_check` | `btrim(description) <> ''` | BR-11.3 | Комментарий есть в erd.md, BR не разрешает ему быть пустым. |
| `order_structure` | `order_structure_quantity_check` | `quantity > 0` | BR-7.15 | Количество положительно, может быть дробным. |
| `payment` | `payment_transaction_check` | `btrim(transaction_id) <> ''` | BR-8.3 | ID транзакции обязателен. |
| `review` | `review_description_check` | `btrim(description) <> ''` | BR-9.3 | У отзыва есть текст. |
| `review` | `review_photo_check` | `photo_url is null or btrim(...) <> ''` | BR-9.3 | Фото необязательно, но не пустая строка. |
| `review` | `review_rating_check` | `rating between 1 and 5` | BR-9.4 | Диапазон оценки. |

Комиссия и общая сумма заказа не проверяются CHECK, а вычисляются (см. «DEFAULT и GENERATED»), поэтому расхождение невозможно в принципе.

---

## UNIQUE-ограничения

| Таблица | Столбцы | BR | Обоснование |
|---|---|---|---|
| `client` | `login` | BR-2.2 | Логин уникален. |
| `client` | `phone_number` | BR-2.2 | Телефон уникален. |
| `address` | `(street, house_number, apartment_office)` `nulls not distinct` | BR-3.3, BR-3.4 | Один физический адрес — одна строка. Без этого два ресторана могли бы занять один дом через две одинаковые строки `address`, и `UNIQUE(restaurant.address_id)` ничего бы не дал. `nulls not distinct` (PostgreSQL 15+) — чтобы дом без квартиры тоже не дублировался. |
| `restaurant` | `address_id` | BR-3.3 | У ресторана свой адрес, двум ресторанам один адрес нельзя. |
| `client_address` | `(client_id, address_id)` — PK | BR-2.5 | Адрес не привязывается к клиенту дважды. |
| `order_structure` | `(order_id, product_id)` — PK | BR-7.16 | Блюдо встречается в заказе один раз. |
| `courier_pay` | `(year, month, courier_id)` — PK | BR-10.3 | Одна выплата курьеру за месяц; на нём же `on conflict` в `courier_salary`. |
| `"order"` | `(order_id, client_id)` | BR-9.2 | Технический ключ — цель составного FK из `review` (FK может ссылаться только на уникальный набор столбцов). |
| `"order"` | `(order_id, total_amount)` | BR-8.4 | Технический ключ — цель составного FK из `payment`. |
| `payment` | `transaction_id` | BR-8.3 | Внешний ID транзакции уникален. |
| `payment` | `order_id where status = 'успех'` — частичный уникальный индекс | BR-8.1 | Не больше одной успешной попытки на заказ. |
| `review` | `(order_id, entity_type, entity_id)` | BR-9.5 | Один отзыв на объект в рамках заказа. |

Названия ресторанов, категорий, блюд и телефоны курьеров не уникальны: BR этого не требует. `add_product` при совпадении названий выдаёт ошибку и просит уточнить.

---

## FK-ограничения

| Таблица | Столбцы | → Таблица | BR | Обоснование |
|---|---|---|---|---|
| `client_address` | `client_id` (`on delete cascade`) | `client` | BR-2.4, BR-3.5 | Адрес привязан к существующему клиенту; при удалении клиента удаляется только привязка, сам адрес остаётся. |
| `client_address` | `address_id` | `address` | BR-2.4 | Привязка ссылается на существующий адрес; удалить адрес, пока он привязан, нельзя (BR-3.5). |
| `restaurant` | `address_id` | `address` | BR-3.3 | Ресторан находится по существующему адресу. |
| `product` | `restaurant_id` | `restaurant` | BR-5.1 | Блюдо принадлежит ровно одному ресторану. |
| `product` | `product_category_id` | `product_category` | BR-5.1, BR-5.7 | Блюдо принадлежит ровно одной категории. |
| `courier_pay` | `courier_id` | `courier` | BR-10.1 | Выплата относится к курьеру. |
| `"order"` | `courier_id` | `courier` | BR-7.5 | Доставку выполняет существующий курьер. |
| `"order"` | `client_id` | `client` | BR-7.1, BR-7.2 | Заказ оформляет клиент. |
| `"order"` | `address_id` | `address` | BR-7.4 | Адрес доставки существует. |
| `"order"` | `restaurant_id` | `restaurant` | BR-7.2 | Заказ из одного ресторана. |
| `"order"` | `(client_id, address_id)` | `client_address` | BR-7.4 | Адрес доставки — один из адресов этого клиента (ловушка 2). |
| `order_structure` | `order_id` | `"order"` | BR-7.14 | Позиция принадлежит заказу. |
| `order_structure` | `product_id` | `product` | BR-7.14 | Позиция — существующее блюдо. |
| `payment` | `order_id` | `"order"` | BR-8.1 | Попытка оплаты относится к заказу. |
| `payment` | `(order_id, amount)` | `"order" (order_id, total_amount)` | BR-8.4 | Сумма попытки равна общей сумме заказа; изменить сумму уже оплачиваемого заказа нельзя. |
| `review` | `client_id` | `client` | BR-9.2 | Автор отзыва — клиент. |
| `review` | `order_id` | `"order"` | BR-9.2 | Отзыв связан с заказом. |
| `review` | `(order_id, client_id)` | `"order" (order_id, client_id)` | BR-9.2 | Отзыв оставляет только клиент, оформивший заказ (ловушка 4). |

Всего 18 FK. `review.entity_id` без FK — см. ловушку 4.

---

## NOT NULL (только бизнес-обязательные)

| Таблица | Столбец | BR | Обоснование |
|---|---|---|---|
| `"order"` | `courier_id` | BR-1.3, BR-7.5, BR-11.3 | Самовывоза нет, каждый заказ доставляет курьер; BR-11.3 не разрешает здесь NULL. Курьер назначается при оформлении заказа. |
| `"order"` | `description` | BR-11.3 | Поле есть в erd.md, разрешения на NULL в BR нет. |
| `courier` | `coefficient` | BR-6.4, BR-6.5 | Коэффициент есть всегда, у нового курьера — 0.1. |
| `restaurant` | `work_start`, `work_end` | BR-4.4 | График работы задан всегда. |
| `restaurant` | `description`, `company_details` | BR-4.1, BR-4.5 | Описание и реквизиты — обязательные атрибуты ресторана. |
| `product` | `description` | BR-5.2 | Описание — атрибут блюда, необязательным названо только фото (BR-5.6). |

Остальные столбцы `NOT NULL` по общему правилу BR-11.3.

---

## NULL (осознанно разрешено)

| Таблица | Столбец | BR | Почему NULL |
|---|---|---|---|
| `address` | `apartment_office` | BR-3.2 | У частного дома нет квартиры/офиса. |
| `product` | `photo_url` | BR-5.6 | Фото необязательно. |
| `review` | `photo_url` | BR-9.3 | Фото необязательно. |
| `courier` | `dismissal_date` | BR-6.3 | У работающего курьера даты увольнения нет. |
| `"order"` | `delivery_timestamp` | BR-7.12 | Заполняется, когда заказ доставлен. |
| `product` | `rating` | BR-9.7 | Нет отзывов — рейтинг NULL. |
| `restaurant` | `rating` | BR-9.7 | Нет отзывов — рейтинг NULL. |

---

## DEFAULT и GENERATED

| Таблица | Столбец | Что | Обоснование |
|---|---|---|---|
| все таблицы с UUID PK | `*_id` | `default exts.uuid_generate_v4()` | BR-11.1, BR-13.3. |
| `courier` | `coefficient` | `default 0.1` | BR-6.5. |
| `"order"` | `order_timestamp` | `default localtimestamp` | BR-7.1, BR-11.2: время сервера без часового пояса. |
| `"order"` | `pay_status` | `default 'ожидает'` | BR-8.7: пока попыток нет, заказ ожидает оплату; дальше поле ведёт триггер. |
| `payment` | `transaction_timestamp` | `default localtimestamp` | BR-8.2, BR-11.2. |
| `review` | `review_timestamp` | `default localtimestamp` | BR-9.3, BR-11.2. |
| `"order"` | `commission` | `generated always as (round(order_amount * 0.10, 2)) stored` | BR-1.4, BR-7.10: комиссия — ровно 10% стоимости блюд. Ввести другое значение невозможно. |
| `"order"` | `total_amount` | `generated always as (order_amount + round(order_amount * 0.10, 2)) stored` | BR-7.10: общая сумма = стоимость блюд + комиссия. |

---

## Триггеры и функции

Каждый объект — в своём файле `db/schema/*.sql`.

### Триггеры целостности (`02_triggers.sql`)

| Триггер (таблица, событие) | Функция | BR | Что делает |
|---|---|---|---|
| `order_structure_restaurant_tg` (`order_structure`, BEFORE INSERT / UPDATE OF order_id, product_id) | `check_order_structure_restaurant()` | BR-7.3 | Блюдо позиции должно быть из ресторана заказа, иначе ошибка. |
| `order_restaurant_change_tg` (`"order"`, BEFORE UPDATE OF restaurant_id) | `check_order_restaurant_change()` | BR-7.3 | Запрещает менять ресторан у заказа, в котором уже есть блюда другого ресторана. Без него правило обходится через UPDATE заказа. |
| `product_restaurant_change_tg` (`product`, BEFORE UPDATE OF restaurant_id) | `check_product_restaurant_change()` | BR-7.3 | Запрещает переносить блюдо в другой ресторан, если оно уже есть в заказах. Без него правило обходится через UPDATE блюда. |
| `review_entity_tg` (`review`, BEFORE INSERT / UPDATE OF order_id, entity_type, entity_id) | `check_review_entity()` | BR-9.1, BR-9.2 | Проверяет, что объект отзыва относится к заказу (см. ловушку 4). |
| `payment_status_sync_tg` (`payment`, AFTER INSERT / UPDATE / DELETE) | `payment_status_sync()` | BR-7.8, BR-8.7 | Пересчитывает `order.pay_status` по попыткам оплаты: есть `успех` → `оплачен`; есть `в_обработке` → `ожидает`; все попытки с ошибкой → `ошибка`; попыток нет → `ожидает`. При переносе попытки на другой заказ пересчитывает оба. |
| `rating_change_tg` (`review`, AFTER INSERT / UPDATE / DELETE) | `rating_change()` | BR-9.6, BR-9.7 | FOOD-105, см. ниже. |

Сумма оплаты (BR-8.4) и принадлежность адреса клиенту (BR-7.4) проверяются составными FK, а не триггерами.

Триггеры `payment_status_sync_tg` и `rating_change_tg` имеют условие `when (coalesce(current_setting('foodexpress.generator', true), '') <> 'on')`. Параметр включает только `insert_test_data` на время своей транзакции: генератор сам заполняет `pay_status` и рейтинги и не должен вызывать `rating_change` (samples, раздел 10). В остальных случаях триггеры работают всегда. Триггеры проверки целостности (BR-7.3, BR-9.2) при генерации не отключаются.

### Процедуры, функции, представление

| Объект | Файл | Тикет | Описание |
|---|---|---|---|
| `insert_test_data(value int)` | `03_insert_test_data.sql` | FOOD-102 | Одна процедура, другие процедуры и функции схемы не вызывает. Создаёт value категорий, курьеров, ресторанов, клиентов; value×5 адресов (value — ресторанам, value×4 — клиентам), блюд, заказов, оплат (одна успешная на заказ), отзывов; связи `client_address` и `order_structure`; `courier_pay` за 6 месяцев (текущий и 5 предыдущих) для каждого курьера и месяца. Все даты — не старше 180 дней. Курьер назначается на заказ, только если работал на дату заказа. Рейтинги блюд и ресторанов считаются одним `update` по отзывам, `courier.coefficient` — коэффициент на следующий месяц (у уволенных не меняется после месяца увольнения). `photo_url` у блюд и отзывов не заполняется (фото необязательно, BR-5.6, BR-9.3). Названия, ФИО, улицы, блюда — из словарей; связность — через массивы ID этого вызова. Повторный вызов без очистки добавляет данные, уникальность логина, телефона, адреса и названия ресторана проверяется перед вставкой. |
| `erase_test_data()` | `04_erase_test_data.sql` | FOOD-103 | `delete` из всех 12 таблиц от дочерних к родительским. |
| `add_product` — два варианта (перегрузка) | `05_add_product.sql` | FOOD-104 | **По идентификаторам** `add_product(p_name, p_product_category_id, p_price, p_restaurant_id, p_description, p_photo_url default null, p_rating default null, p_status default 'доступно')` — все атрибуты `product`, кроме `product_id` (он генерируется значением по умолчанию). **По названиям** `add_product(p_restaurant_name, p_category_name, p_product_name, p_price, p_description, p_photo_url default null, p_status default 'доступно')` — ресторан и категория ищутся по названию, чтобы пользователю не нужно было знать UUID; при отсутствии или неоднозначности названия — ошибка. В обоих вариантах проверки значений делают ограничения таблицы `product` (FK, CHECK, NOT NULL, размерность `numeric`), процедура перехватывает `foreign_key_violation`, `check_violation`, `not_null_violation`, `string_data_right_truncation`, `numeric_value_out_of_range` и выдаёт понятное сообщение со ссылкой на BR. В варианте по названиям `rating` не передаётся (у нового блюда отзывов нет, BR-9.7); в варианте по ID начальный рейтинг можно передать, после первого отзыва его пересчитывает `rating_change`. |
| `rating_change()` | `02_triggers.sql` | FOOD-105 | Пересчитывает `product.rating` / `restaurant.rating` = `round(avg(review.rating), 2)`; нет отзывов → NULL. При UPDATE пересчитывает и старую, и новую сущность. Для `'заказ'` ничего не делает. Рекурсии нет: обновляемые столбцы `rating` не вызывают триггеров. |
| `get_statistic()` | `06_get_statistic.sql` | FOOD-106 | Одна строка на ресторан. `"order"` читается один раз (CTE `delivered`, `materialized`), без оконных функций, `distinct on` и коррелированных подзапросов (BR-11.8) — только `join` и `group by`. Лучшее блюдо и клиент — агрегат `(array_agg(... order by показатель desc, random()))[1]`, при равенстве выбор случайный. Сумма и среднее считаются из той же группировки по клиентам, что и лучший клиент, — без отдельного прохода. |
| `courier_salary()` | `07_courier_salary.sql` | FOOD-107 | Без циклов: один `insert … on conflict do update` и один `update`. Учитываются доставленные заказы, оформленные в текущем месяце. Запись за текущий месяц получает каждый курьер (без доставок — 0). Повторный вызов в том же месяце обновляет запись и берёт коэффициент из неё, а не уже обновлённый `courier.coefficient`. Уволенным коэффициент не меняется (BR-10.6). |
| `how_much_money` | `08_how_much_money.sql` | FOOD-108 | Рекурсивный CTE месяцев (BR-11.9), месяцы без заказов — с нулями, `prev_commission` для первого месяца — NULL. Заказ относится к месяцу его оформления (`order_timestamp`) — так же считают `courier_salary` и генератор, поэтому комиссии и выплаты курьерам сопоставимы. Генератор создаёт доставку в том же месяце, что и заказ. |

---

## Нормализация (3НФ)

```
1НФ: все атрибуты атомарны (адрес разбит на улицу, дом, квартиру; позиции заказа вынесены
     в order_structure; привязки адресов — в client_address).
2НФ: в таблицах с составным ключом (client_address, order_structure, courier_pay) неключевые
     атрибуты (quantity; amount, coefficient_used) зависят от всего ключа.
3НФ: нет зависимостей неключевых атрибутов от других неключевых: категория — справочник
     product_category, адрес — таблица address, статусы — enum-типы.

Особые случаи:
- order.commission и order.total_amount функционально зависят от order_amount. Это транзитивная
  зависимость, поэтому они сделаны GENERATED ALWAYS: значения не вводятся, а вычисляются
  СУБД, аномалий обновления нет. Хранятся (stored), потому что участвуют в FK из payment
  и в отчётах.
- order.order_amount хранится, а не считается по order_structure × product.price: цена блюда
  может меняться, а сумма заказа фиксируется на момент оформления.
- product.rating и restaurant.rating — осознанная денормализация (агрегат review) для
  быстрого чтения меню; согласованность поддерживает триггер rating_change.
- review.client_id выводится из review.order_id. Оставлен по контракту erd.md, расхождение
  исключено составным FK review(order_id, client_id) → "order"(order_id, client_id).
- review.entity_id + entity_type — полиморфная ссылка, не зависимость между неключевыми
  атрибутами; валидность — см. ловушку 4.
- "order" оставлено с кавычками, а не переименовано (BR-13.1): так имя совпадает с erd.md.
```
