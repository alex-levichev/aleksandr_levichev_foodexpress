# FoodExpress — база данных

Добро пожаловать в проект. Твоя задача — спроектировать и реализовать базу данных для сервиса доставки еды.

## С чего начать
1. Прочитай [онбординг](docs/onboarding.md) — это твой первый рабочий день.
2. Изучи [бизнес-правила](docs/company-rules.md).
3. Открой [бэклог](docs/backlog.md) — там твои задачи.

## Если ты никогда не работал с Git
1. Посмотри [скринкаст](docs/git-screencast.md) (10 минут).
2. Держи под рукой [шпаргалку](docs/git-cheatsheet.md).

## Сдача работы
Все требования к составу файлов, формату резервной копии и процессу сдачи описаны в файле [docs/acceptance.md](docs/acceptance.md).

## Платформы
Репозиторий зеркалируется на две платформы. Форкай ту, где тебе удобнее:
- GitHub: [`<ссылка_на_github>`](https://github.com/NKhashchanov/total_designing_db_2026)
- GitVerse: [`<ссылка_на_gitverse>`](https://gitverse.ru/nkhashchanov/total_designing_db_2026)

## Состав выполненной работы

Схема: `levichev_food`.

| Файл | Содержимое |
|---|---|
| `db/schema/01_schema.sql` | схема, 8 enum-типов, 12 таблиц, ограничения, индексы (FOOD-101) |
| `db/schema/02_triggers.sql` | триггеры целостности и `rating_change` (FOOD-105) |
| `db/schema/03_insert_test_data.sql` | генератор тестовых данных (FOOD-102) |
| `db/schema/04_erase_test_data.sql` | очистка данных (FOOD-103) |
| `db/schema/05_add_product.sql` | добавление блюда (FOOD-104) |
| `db/schema/06_get_statistic.sql` | статистика по ресторанам (FOOD-106) |
| `db/schema/07_courier_salary.sql` | зарплата курьеров (FOOD-107) |
| `db/schema/08_how_much_money.sql` | отчёт `how_much_money` (FOOD-108) |
| `db/schema/grants.sql` | пользователь `inspector` и права (FOOD-109) |
| `db/foodexpress_levichev.backup` | архив `pg_dump -Fc` схемы `levichev_food` (FOOD-110) |
| `db/constraints.md` | обоснование ограничений, триггеров и функций |
| `db/tests.md` | протокол проверки под `inspector` |

## Развёртывание

В базе заранее должна быть схема `exts` с расширением `uuid-ossp` (BR-13.3).

**Из бэкапа** (так проверяет аудитор):

```bash
pg_restore -d <база> db/foodexpress_levichev.backup
psql -d <база> -f db/schema/grants.sql
```

Владелец объектов в архиве — `postgres`. Если такой роли нет, восстановить с `--no-owner`
(в DBeaver — галочка «No owner»). Если схема `levichev_food` в базе уже есть, сначала
`drop schema levichev_food cascade;`. Права выдаёт `grants.sql`.

**Из скриптов** — выполнить файлы `db/schema/01_…` – `08_…` по порядку, затем `grants.sql`.

## Быстрая проверка под inspector

```sql
set search_path to levichev_food, exts;
call erase_test_data();
call insert_test_data(10);
select * from get_statistic();
call courier_salary();
select * from how_much_money;
call add_product('<название ресторана>', '<название категории>', 'Новое блюдо', 450, 'Описание блюда');
call add_product(p_name => 'Новое блюдо', p_product_category_id => '<uuid>', p_price => 450,
    p_restaurant_id => '<uuid>', p_description => 'Описание блюда');
```
