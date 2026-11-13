# Обоснование ограничений — FoodExpress

Схема: `levichev_food`. Обоснования основаны на `docs/company-rules.md` и результатах проверки ограничений в PostgreSQL. Документ учитывает исправления ограничений, выполненные и проверенные в PostgreSQL 12 ноября 2026 года.

## Enum-типы

| Тип | Значения | BR |
|---|---|---|
| `restaurant_status` | `активен`, `неактивен` | BR-4.3, BR-11.5 |
| `product_status` | `доступно`, `нет_в_наличии`, `архив` | BR-5.5, BR-11.5 |
| `courier_status` | `свободен`, `занят`, `на_доставке`, `уволен` | BR-6.2, BR-11.5 |
| `order_status` | `создан`, `готовится`, `в_доставке`, `доставлен`, `отменён` | BR-7.7, BR-11.5 |
| `order_pay_status` | `ожидает`, `оплачен`, `ошибка` | BR-7.9, BR-11.5 |
| `payment_type` | `карта`, `наличные`, `безнал` | BR-8.2, BR-11.5 |
| `payment_status` | `успех`, `ошибка`, `в_обработке` | BR-8.2, BR-11.5 |
| `review_entity_type` | `блюдо`, `ресторан`, `заказ` | BR-9.1, BR-11.5 |

## Ловушки

### Ловушка 1: `payment` — неполная сущность

**Добавленные атрибуты (BR-8.2):** `payment_type` (способ конкретной попытки), `amount` (сумма попытки), `transaction_id` (внешний идентификатор провайдера), `transaction_timestamp` (момент попытки), `status` (результат попытки). `order_id` связывает попытку с заказом. Данные банковских карт не сохраняются (BR-1.7, BR-8.5).

**Тип оплаты (BR-8.6):** хранится в `payment.payment_type`, а не в `order`: один заказ может иметь несколько попыток с разными способами оплаты. Уникальность `transaction_id` обеспечивает BR-8.3. Частичный уникальный индекс для успешных попыток не допускает более одной успешной оплаты одного заказа (BR-8.1); сумма проверяется триггером `payment_amount_check_trigger` (BR-8.4), агрегированный статус заказа обновляет `payment_status_sync_trigger` (BR-8.7).

### Ловушка 2: `order.address_id` — принадлежность клиенту (BR-7.4)

Использован триггер `order_address_check_trigger` при INSERT/UPDATE заказа. Он проверяет существование пары `(client_id, address_id)` в `client_address`. Отдельные FK на клиента и адрес гарантируют существование каждой записи, но не гарантировали бы их принадлежность друг другу. Связующая таблица `client_address` допускает общий адрес у разных клиентов (BR-2.4) и имеет составной первичный ключ, исключающий повторную привязку (BR-2.5).

### Ловушка 3: `order_structure` — один ресторан в заказе (BR-7.3)

`order_product_restaurant_check_trigger` проверяет, что `product.restaurant_id` соответствует `order.restaurant_id` при добавлении/изменении позиции. Дополнительно `order_restaurant_change_trigger` и `product_restaurant_change_trigger` защищают согласованность при последующих изменениях ресторанов в заказе и блюде. Обычные FK на `order_id` и `product_id` такой межтабличной проверки не дают.

### Ловушка 4: `review` — полиморфизм (BR-9.1)

В `review` хранится пара `entity_type` (ENUM) + `entity_id` (UUID). Один обычный FK на `entity_id` невозможен: он может ссылаться на `product`, `restaurant` либо `order`. Для отзывов реализованы триггеры `review_client_check_trigger` и `review_product_check_trigger`, проверяющие принадлежность отзыва клиенту заказа и блюда составу заказа (BR-9.2). Уникальность `(order_id, entity_type, entity_id)` ограничивает один отзыв на объект в пределах заказа (BR-9.5). Функция `check_review_product()` проверена: для типа `блюдо` она ищет позицию в `order_structure`, для `ресторан` — соответствие `restaurant_id` ресторану заказа, для `заказ` — равенство `entity_id = order_id`. Так подтверждается валидность объекта каждого типа (BR-9.1–9.2).

## CHECK-ограничения

| Таблица | Столбец | Условие | BR | Обоснование |
|---|---|---|---|---|
| `product` | `price` | `price >= 0` | BR-5.3 | Цена блюда неотрицательна. |
| `product` | `rating` | `rating BETWEEN 0 AND 5` | BR-5.4 | Рейтинг блюда ограничен диапазоном. |
| `restaurant` | `work_start`, `work_end` | `work_end > work_start` | BR-4.4 | Закрытие позже открытия. |
| `restaurant` | `rating` | `rating BETWEEN 0 AND 5` | BR-4.2 | Рейтинг ресторана находится в диапазоне 0–5; отсутствие отзывов допускает NULL. |
| `courier` | `coefficient` | `coefficient BETWEEN 0.1 AND 0.5` | BR-6.4 | Допустимый диапазон коэффициента. |
| `courier` | `hire_date`, `dismissal_date` | `dismissal_date IS NULL OR dismissal_date >= hire_date` | BR-6.1, BR-6.3 | Дата увольнения не должна предшествовать найму. |
| `courier` | `status`, `dismissal_date` | `status <> 'уволен' OR dismissal_date IS NOT NULL` | BR-6.3 | Для уволенного курьера обязательна дата увольнения. |
| `courier_pay` | `year` | `year >= 2000` | BR-10.1, BR-11.6 | Техническая граница допустимого года учёта зарплаты. |
| `courier_pay` | `month` | `month BETWEEN 1 AND 12` | BR-10.1 | Месяц расчёта зарплаты — календарный. |
| `courier_pay` | `amount` | `amount >= 0` | BR-10.4 | Зарплата неотрицательна. |
| `courier_pay` | `coefficient_used` | `coefficient_used BETWEEN 0.1 AND 0.5` | BR-10.2, BR-6.4 | Применённый коэффициент находится в допустимом диапазоне. |
| `"order"` | `order_amount` | `order_amount >= 0` | BR-7.10 | Стоимость блюд неотрицательна. |
| `"order"` | `commission` | `commission >= 0` | BR-1.4, BR-7.10 | Комиссия неотрицательна. |
| `"order"` | `commission`, `order_amount` | `commission = round(order_amount * 0.10, 2)` | BR-1.4, BR-7.10 | Комиссия составляет ровно 10% стоимости блюд с округлением до копеек. |
| `"order"` | `total_amount` | `total_amount >= 0` | BR-7.10 | Итоговая сумма неотрицательна. |
| `"order"` | `total_amount`, `order_amount`, `commission` | `total_amount = order_amount + commission` | BR-7.10 | Итоговая сумма включает комиссию. |
| `"order"` | `total_amount` | `total_amount >= 1000` | BR-1.8, BR-7.11 | Минимальная сумма заказа — 1000 ₽. |
| `"order"` | `delivery_timestamp`, `order_timestamp` | `delivery_timestamp IS NULL OR delivery_timestamp >= order_timestamp` | BR-7.13 | Доставка не может завершиться раньше создания заказа. |
| `order_structure` | `quantity` | `quantity > 0` | BR-7.15 | Количество положительно, допускает дробные значения. |
| `payment` | `amount` | `amount >= 0` | BR-8.2, BR-8.4 | Сумма попытки неотрицательна; равенство сумме заказа проверяет триггер. |
| `review` | `rating` | `rating BETWEEN 1 AND 5` | BR-9.4 | Допустимая оценка отзыва. |

Ограничения `restaurant_rating_check`, `courier_dismissal_status_check` и `courier_pay_coefficient_used_check` подтверждены итоговым запросом к `pg_constraint`.

## UNIQUE-ограничения

| Таблица | Столбцы | BR | Обоснование |
|---|---|---|---|
| `client` | `login` | BR-2.2 | Логин уникален. |
| `client` | `phone_number` | BR-2.2 | Телефон клиента уникален. |
| `courier` | `phone_number` | BR-6.1, BR-11.6 | Техническое правило однозначной идентификации курьера по телефону. |
| `restaurant` | `address_id` | BR-3.3 | Разные рестораны не делят один адрес. |
| `product_category` | `product_category_name` | BR-5.7 | Избегаем повторных названий в справочнике категорий; дополнительное проектное решение. |
| `payment` | `transaction_id` | BR-8.3 | Внешний идентификатор транзакции уникален. |
| `review` | `(order_id, entity_type, entity_id)` | BR-9.5 | Один отзыв на объект в одном заказе. |
| `client_address` | `(client_id, address_id)` — составной PK | BR-2.5 | Один адрес не привязывается к клиенту повторно. |
| `order_structure` | `(order_id, product_id)` — составной PK | BR-7.16 | Одно блюдо не дублируется в заказе. |
| `courier_pay` | `(year, month, courier_id)` — составной PK | BR-10.3 | Одна выплата курьеру за месяц. |
| `payment` | `order_id WHERE status = 'успех'` — частичный уникальный индекс | BR-8.1 | Не более одной успешной попытки оплаты на заказ. |

## FK-ограничения

| Таблица | Столбцы | → Таблица | BR | Обоснование |
|---|---|---|---|---|
| `restaurant` | `address_id` | `address(address_id)` | BR-3.3 | У ресторана есть адрес. |
| `product` | `restaurant_id` | `restaurant(restaurant_id)` | BR-5.1 | Блюдо принадлежит ресторану. |
| `product` | `product_category_id` | `product_category(product_category_id)` | BR-5.1, BR-5.7 | Блюдо принадлежит категории. |
| `client_address` | `client_id` | `client(client_id)` | BR-2.4 | Адрес привязан к существующему клиенту. |
| `client_address` | `address_id` | `address(address_id)` | BR-2.4 | Привязка ссылается на существующий адрес. |
| `courier_pay` | `courier_id` | `courier(courier_id)` | BR-10.1, BR-10.3 | Выплата относится к курьеру. |
| `"order"` | `client_id` | `client(client_id)` | BR-7.1, BR-7.2 | Заказ оформляет клиент. |
| `"order"` | `restaurant_id` | `restaurant(restaurant_id)` | BR-7.2 | Заказ оформлен в ресторане. |
| `"order"` | `address_id` | `address(address_id)` | BR-7.4 | У заказа есть адрес доставки; принадлежность клиенту проверяет триггер. |
| `"order"` | `courier_id` | `courier(courier_id)` | BR-7.5 | Назначенный курьер существует. |
| `order_structure` | `order_id` | `"order"(order_id)` | BR-7.14 | Позиция относится к заказу. |
| `order_structure` | `product_id` | `product(product_id)` | BR-7.14 | Позиция содержит существующее блюдо. |
| `payment` | `order_id` | `"order"(order_id)` | BR-8.1 | Попытка оплаты относится к заказу. |
| `review` | `client_id` | `client(client_id)` | BR-9.2 | Автор отзыва существует. |
| `review` | `order_id` | `"order"(order_id)` | BR-9.2 | Отзыв связан с заказом. |

`review.entity_id` не имеет обычного FK из-за полиморфизма; см. ловушку 4.

## NOT NULL (только бизнес-обязательные)

| Таблица | Столбец | BR | Обоснование |
|---|---|---|---|
| `client` | `login`, `password`, `phone_number` | BR-2.1 | Данные регистрации обязательны. |
| `restaurant` | `restaurant_name`, `description`, `company_details`, `work_start`, `work_end`, `status` | BR-4.1, BR-4.4, BR-11.3 | Основные сведения, описание, реквизиты и график работы ресторана обязательны. |
| `product` | `product_name`, `price`, `status`, `description` | BR-5.2 | Основные данные блюда обязательны. |
| `courier` | `fio`, `phone_number`, `status`, `hire_date`, `coefficient` | BR-6.1 | Данные сотрудника и коэффициент обязательны. |
| `"order"` | `order_timestamp`, `order_amount`, `commission`, `total_amount`, `status`, `pay_status` | BR-7.1, BR-7.6–7.10 | У заказа есть дата, суммы и статусы. |
| `payment` | `payment_type`, `amount`, `transaction_id`, `transaction_timestamp`, `status` | BR-8.2 | Поля попытки оплаты обязательны. |
| `review` | `review_timestamp`, `entity_type`, `entity_id`, `description`, `rating` | BR-9.1–9.4 | Отзыв имеет объект, текст, дату и оценку. |
| `courier_pay` | `amount`, `coefficient_used` | BR-10.2 | Выплата содержит сумму и применённый коэффициент. |

PK и очевидные FK здесь не дублируются.

## NULL (осознанно разрешено)

| Таблица | Столбец | BR | Почему NULL |
|---|---|---|---|
| `address` | `apartment_office` | BR-3.2 | У частного дома может не быть квартиры/офиса. |
| `product` | `photo_url` | BR-5.6 | Фото необязательно. |
| `product` | `rating` | BR-9.7 | Если отзывов нет, агрегированный рейтинг равен NULL. |
| `restaurant` | `rating` | BR-9.7 | Если отзывов нет, агрегированный рейтинг равен NULL. |
| `courier` | `dismissal_date` | BR-6.3 | Работающий курьер может не иметь даты увольнения. |
| `"order"` | `delivery_timestamp` | BR-7.12 | До завершения доставки дата отсутствует. |
| `"order"` | `courier_id` | BR-7.5, BR-7.7 | Пока заказ создан и курьер не назначен, поле может быть пустым; это проектное допущение. |
| `review` | `photo_url` | BR-9.3 | Фотография отзыва необязательна. |
| `"order"` | `description` | BR-11.3 | Дополнительный комментарий к заказу может отсутствовать; проектное допущение. |

## DEFAULT и GENERATED

| Таблица | Столбец | Что | Обоснование |
|---|---|---|---|
| Таблицы с UUID PK | `*_id` | `DEFAULT exts.uuid_generate_v4()` | BR-11.1: UUID генерируется на сервере. |
| `courier` | `coefficient` | `DEFAULT 0.1` | BR-6.5: начальный коэффициент нового курьера. |
| `"order"` | `order_timestamp` | `DEFAULT CURRENT_TIMESTAMP` | BR-7.1, BR-11.2: момент создания на сервере. |
| `payment` | `transaction_timestamp` | `DEFAULT CURRENT_TIMESTAMP` | BR-8.2, BR-11.2: момент регистрации попытки. |
| `review` | `review_timestamp` | `DEFAULT CURRENT_TIMESTAMP` | BR-9.3, BR-11.2: момент создания отзыва. |
| `"order"` | `commission`, `total_amount` | Обычные столбцы + CHECK, не GENERATED | BR-1.4, BR-7.10: значения сохраняются, но CHECK контролируют формулы 10% и суммы. Это позволяет хранить зафиксированные суммы заказа. |

## Нормализация (3НФ)

Данные разделены по сущностям: клиенты, адреса, рестораны, категории и блюда, курьеры, заказы, позиции, платежи, отзывы и выплаты. Связь клиентов с адресами вынесена в `client_address` (многие-ко-многим), а состав заказа — в `order_structure`; составные ключи не допускают повторов. Неключевые атрибуты описывают сущность, определяемую ключом, а не другую неключевую колонку. Справочники и независимые сущности вынесены отдельно.

**Осознанные исключения и вычисляемые данные:** `order.commission` (10% от `order_amount`) и `order.total_amount` (`order_amount + commission`) сохраняются как обычные поля с CHECK (BR-1.4, BR-7.10), хотя могут быть вычислены. `product.rating` и `restaurant.rating` — материализованные средние оценок, поддерживаемые триггером `rating_change` при INSERT/UPDATE/DELETE отзывов (BR-9.6–9.7); это осознанная денормализация для быстрого чтения. `review.entity_type + entity_id` реализует полиморфную ссылку, а не функциональную зависимость между неключевыми атрибутами.

Таким образом, основная модель спроектирована с соблюдением принципов 3НФ, с указанными контролируемыми вычисляемыми полями и агрегатами.

## Проверка перед сдачей

По результатам проверок в DBeaver ограничения рейтинга ресторана, даты увольнения и коэффициента зарплаты добавлены и подтверждены. Для `restaurant.description` и `restaurant.company_details` установлено `NOT NULL` после проверки отсутствия NULL в существующих строках. Функция `check_review_product()` проверена для всех трёх типов объектов.

**Осталось актуализировать резервную копию** `db/foodexpress_levichev.backup` после этих изменений и проверить её восстановление в отдельной базе. До этого предыдущую копию следует сохранить.
