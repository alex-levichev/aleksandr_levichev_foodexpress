-- FOOD-101. Схема, типы, таблицы, ограничения

create schema levichev_food;

set search_path to levichev_food, exts;

-- enum-типы

create type restaurant_status as enum ('активен', 'неактивен');
create type product_status as enum ('доступно', 'нет_в_наличии', 'архив');
create type courier_status as enum ('свободен', 'занят', 'на_доставке', 'уволен');
create type order_status as enum ('создан', 'готовится', 'в_доставке', 'доставлен', 'отменён');
create type order_pay_status as enum ('ожидает', 'оплачен', 'ошибка');
create type payment_status as enum ('успех', 'ошибка', 'в_обработке');
create type payment_type as enum ('карта', 'наличные', 'безнал');
create type review_entity_type as enum ('блюдо', 'ресторан', 'заказ');

-- клиенты и адреса

create table client (
	client_id uuid primary key default exts.uuid_generate_v4(),
	login varchar(50) not null,
	password char(32) not null,
	phone_number char(11) not null,
	constraint client_login_key unique (login),
	constraint client_phone_number_key unique (phone_number),
	constraint client_login_check check (btrim(login) <> ''),
	constraint client_password_md5_check check (password ~ '^[0-9a-f]{32}$'),
	constraint client_phone_check check (phone_number ~ '^7[0-9]{10}$')
);

create table address (
	address_id uuid primary key default exts.uuid_generate_v4(),
	street varchar(100) not null,
	house_number varchar(10) not null,
	apartment_office varchar(10),
	constraint address_unique unique nulls not distinct (street, house_number, apartment_office),
	constraint address_street_check check (btrim(street) <> ''),
	constraint address_house_check check (btrim(house_number) <> ''),
	constraint address_apartment_check check (apartment_office is null or btrim(apartment_office) <> '')
);

create table client_address (
	client_id uuid not null,
	address_id uuid not null,
	constraint client_address_pkey primary key (client_id, address_id),
	constraint client_address_client_fkey foreign key (client_id)
		references client (client_id) on delete cascade,
	constraint client_address_address_fkey foreign key (address_id)
		references address (address_id)
);

-- рестораны и меню

create table restaurant (
	restaurant_id uuid primary key default exts.uuid_generate_v4(),
	restaurant_name varchar(100) not null,
	address_id uuid not null,
	description text not null,
	work_start time not null,
	work_end time not null,
	company_details text not null,
	rating numeric(3,2),
	status restaurant_status not null,
	constraint restaurant_address_key unique (address_id),
	constraint restaurant_address_fkey foreign key (address_id) references address (address_id),
	constraint restaurant_name_check check (btrim(restaurant_name) <> ''),
	constraint restaurant_description_check check (btrim(description) <> ''),
	constraint restaurant_details_check check (btrim(company_details) <> ''),
	constraint restaurant_rating_check check (rating between 0 and 5),
	constraint restaurant_work_time_check check (work_end > work_start)
);

create table product_category (
	product_category_id uuid primary key default exts.uuid_generate_v4(),
	product_category_name varchar(50) not null,
	constraint product_category_name_check check (btrim(product_category_name) <> '')
);

create table product (
	product_id uuid primary key default exts.uuid_generate_v4(),
	product_name varchar(100) not null,
	product_category_id uuid not null,
	price numeric(8,2) not null,
	restaurant_id uuid not null,
	photo_url text,
	rating numeric(3,2),
	status product_status not null,
	description text not null,
	constraint product_category_fkey foreign key (product_category_id)
		references product_category (product_category_id),
	constraint product_restaurant_fkey foreign key (restaurant_id)
		references restaurant (restaurant_id),
	constraint product_name_check check (btrim(product_name) <> ''),
	constraint product_description_check check (btrim(description) <> ''),
	constraint product_photo_check check (photo_url is null or btrim(photo_url) <> ''),
	constraint product_price_check check (price >= 0),
	constraint product_rating_check check (rating between 0 and 5)
);

-- курьеры

create table courier (
	courier_id uuid primary key default exts.uuid_generate_v4(),
	fio varchar(150) not null,
	phone_number char(11) not null,
	status courier_status not null,
	hire_date date not null,
	dismissal_date date,
	coefficient numeric(2,1) not null default 0.1,
	constraint courier_fio_check check (btrim(fio) <> ''),
	constraint courier_phone_check check (phone_number ~ '^7[0-9]{10}$'),
	constraint courier_coefficient_check check (coefficient between 0.1 and 0.5),
	constraint courier_dismissal_status_check check (status <> 'уволен' or dismissal_date is not null),
	constraint courier_dismissal_date_check check (dismissal_date is null or dismissal_date >= hire_date)
);

create table courier_pay (
	year int not null,
	month int not null,
	courier_id uuid not null,
	amount numeric(8,2) not null,
	coefficient_used numeric(2,1) not null,
	constraint courier_pay_pkey primary key (year, month, courier_id),
	constraint courier_pay_courier_fkey foreign key (courier_id) references courier (courier_id),
	constraint courier_pay_year_check check (year >= 2000),
	constraint courier_pay_month_check check (month between 1 and 12),
	constraint courier_pay_amount_check check (amount >= 0),
	constraint courier_pay_coefficient_check check (coefficient_used between 0.1 and 0.5)
);

-- заказы

create table "order" (
	order_id uuid primary key default exts.uuid_generate_v4(),
	courier_id uuid not null,
	client_id uuid not null,
	address_id uuid not null,
	restaurant_id uuid not null,
	order_timestamp timestamp not null default localtimestamp,
	delivery_timestamp timestamp,
	order_amount numeric(8,2) not null,
	commission numeric(8,2) generated always as (round(order_amount * 0.10, 2)) stored,
	total_amount numeric(9,2) generated always as (order_amount + round(order_amount * 0.10, 2)) stored,
	status order_status not null,
	pay_status order_pay_status not null default 'ожидает',
	description text not null,
	constraint order_courier_fkey foreign key (courier_id) references courier (courier_id),
	constraint order_client_fkey foreign key (client_id) references client (client_id),
	constraint order_address_fkey foreign key (address_id) references address (address_id),
	constraint order_restaurant_fkey foreign key (restaurant_id) references restaurant (restaurant_id),
	constraint order_client_address_fkey foreign key (client_id, address_id)
		references client_address (client_id, address_id),
	constraint order_client_key unique (order_id, client_id),
	constraint order_total_key unique (order_id, total_amount),
	constraint order_amount_check check (order_amount >= 0),
	constraint order_min_total_check check (total_amount >= 1000),
	constraint order_delivery_time_check check (delivery_timestamp is null or delivery_timestamp >= order_timestamp),
	constraint order_delivered_time_check check (status <> 'доставлен' or delivery_timestamp is not null),
	constraint order_description_check check (btrim(description) <> '')
);

create table order_structure (
	order_id uuid not null,
	product_id uuid not null,
	quantity numeric(5,2) not null,
	constraint order_structure_pkey primary key (order_id, product_id),
	constraint order_structure_order_fkey foreign key (order_id) references "order" (order_id),
	constraint order_structure_product_fkey foreign key (product_id) references product (product_id),
	constraint order_structure_quantity_check check (quantity > 0)
);

-- оплаты

create table payment (
	payment_id uuid primary key default exts.uuid_generate_v4(),
	order_id uuid not null,
	payment_type payment_type not null,
	amount numeric(9,2) not null,
	transaction_id varchar(64) not null,
	transaction_timestamp timestamp not null default localtimestamp,
	status payment_status not null,
	constraint payment_order_fkey foreign key (order_id) references "order" (order_id),
	constraint payment_order_amount_fkey foreign key (order_id, amount)
		references "order" (order_id, total_amount),
	constraint payment_transaction_key unique (transaction_id),
	constraint payment_transaction_check check (btrim(transaction_id) <> '')
);

create unique index payment_one_success_idx on payment (order_id) where status = 'успех';

-- отзывы

create table review (
	review_id uuid primary key default exts.uuid_generate_v4(),
	client_id uuid not null,
	review_timestamp timestamp not null default localtimestamp,
	entity_id uuid not null,
	entity_type review_entity_type not null,
	order_id uuid not null,
	description text not null,
	photo_url text,
	rating numeric(2,1) not null,
	constraint review_client_fkey foreign key (client_id) references client (client_id),
	constraint review_order_fkey foreign key (order_id) references "order" (order_id),
	constraint review_order_client_fkey foreign key (order_id, client_id)
		references "order" (order_id, client_id),
	constraint review_entity_key unique (order_id, entity_type, entity_id),
	constraint review_description_check check (btrim(description) <> ''),
	constraint review_photo_check check (photo_url is null or btrim(photo_url) <> ''),
	constraint review_rating_check check (rating between 1 and 5)
);

-- индексы
create index order_courier_idx on "order" (courier_id);
create index order_restaurant_idx on "order" (restaurant_id);
create index order_status_idx on "order" (status);
create index order_structure_product_idx on order_structure (product_id);
create index product_restaurant_idx on product (restaurant_id);
create index review_entity_idx on review (entity_type, entity_id);
