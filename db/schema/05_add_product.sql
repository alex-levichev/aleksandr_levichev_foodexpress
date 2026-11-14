-- FOOD-104. Добавление блюда

set search_path to levichev_food, exts;

-- вариант по названиям ресторана и категории

create or replace procedure add_product(
	p_restaurant_name varchar,
	p_category_name varchar,
	p_product_name varchar,
	p_price numeric,
	p_description text,
	p_photo_url text default null,
	p_status levichev_food.product_status default 'доступно'
) as $$
declare
	rest_id uuid;
	cat_id uuid;
	cnt int;
	err_constraint text;
	err_column text;
begin
	select count(*), min(restaurant_id::text)::uuid into cnt, rest_id
	from levichev_food.restaurant
	where restaurant_name = p_restaurant_name;

	if cnt = 0 then
		raise exception 'Ресторан «%» не найден', p_restaurant_name
			using hint = 'Проверьте название: select restaurant_name from restaurant';
	elseif cnt > 1 then
		raise exception 'Найдено несколько ресторанов с названием «%» (%), блюдо не добавлено', p_restaurant_name, cnt;
	end if;

	select count(*), min(product_category_id::text)::uuid into cnt, cat_id
	from levichev_food.product_category
	where product_category_name = p_category_name;

	if cnt = 0 then
		raise exception 'Категория «%» не найдена', p_category_name
			using hint = 'Проверьте название: select product_category_name from product_category';
	elseif cnt > 1 then
		raise exception 'Найдено несколько категорий с названием «%» (%), блюдо не добавлено', p_category_name, cnt;
	end if;

	insert into levichev_food.product (product_name, product_category_id, price, restaurant_id,
		photo_url, rating, status, description)
	values (p_product_name, cat_id, p_price, rest_id, p_photo_url, null, p_status, p_description);

	raise notice 'Блюдо «%» добавлено в ресторан «%»', p_product_name, p_restaurant_name;

exception
	when check_violation then
		get stacked diagnostics err_constraint = constraint_name;
		raise exception 'Блюдо не добавлено: %', case err_constraint
			when 'product_price_check' then 'цена должна быть неотрицательной (BR-5.3), передано ' || p_price
			when 'product_name_check' then 'название блюда не может быть пустым (BR-5.2)'
			when 'product_description_check' then 'описание блюда не может быть пустым (BR-5.2)'
			when 'product_photo_check' then 'ссылка на фото не может быть пустой строкой: передайте NULL (BR-5.6)'
			else 'нарушено ограничение ' || err_constraint
		end;
	when not_null_violation then
		get stacked diagnostics err_column = column_name;
		raise exception 'Блюдо не добавлено: не заполнено обязательное поле % (BR-5.2, BR-11.3)', err_column;
	when string_data_right_truncation then
		raise exception 'Блюдо не добавлено: название длиннее 100 символов';
	when numeric_value_out_of_range then
		raise exception 'Блюдо не добавлено: цена % вне допустимого диапазона (не больше 999 999.99)', p_price;
end;
$$ language plpgsql;

-- вариант по идентификаторам (контракт FOOD-104)
create or replace procedure add_product(
	p_name varchar,
	p_product_category_id uuid,
	p_price numeric,
	p_restaurant_id uuid,
	p_description text,
	p_photo_url text default null,
	p_rating numeric default null,
	p_status levichev_food.product_status default 'доступно'
) as $$
declare
	err_constraint text;
	err_column text;
begin
	insert into levichev_food.product (product_name, product_category_id, price, restaurant_id,
		photo_url, rating, status, description)
	values (p_name, p_product_category_id, p_price, p_restaurant_id,
		p_photo_url, p_rating, p_status, p_description);

	raise notice 'Блюдо «%» добавлено', p_name;

exception
	when foreign_key_violation then
		get stacked diagnostics err_constraint = constraint_name;
		raise exception 'Блюдо не добавлено: %', case err_constraint
			when 'product_restaurant_fkey' then 'ресторан с ID ' || coalesce(p_restaurant_id::text, 'NULL') || ' не существует (BR-5.1)'
			when 'product_category_fkey' then 'категория с ID ' || coalesce(p_product_category_id::text, 'NULL') || ' не существует (BR-5.1)'
			else 'нарушен внешний ключ ' || err_constraint
		end;
	when check_violation then
		get stacked diagnostics err_constraint = constraint_name;
		raise exception 'Блюдо не добавлено: %', case err_constraint
			when 'product_price_check' then 'цена должна быть неотрицательной (BR-5.3), передано ' || p_price
			when 'product_rating_check' then 'рейтинг должен быть от 0 до 5 (BR-5.4), передано ' || p_rating
			when 'product_name_check' then 'название блюда не может быть пустым (BR-5.2)'
			when 'product_description_check' then 'описание блюда не может быть пустым (BR-5.2)'
			when 'product_photo_check' then 'ссылка на фото не может быть пустой строкой: передайте NULL (BR-5.6)'
			else 'нарушено ограничение ' || err_constraint
		end;
	when not_null_violation then
		get stacked diagnostics err_column = column_name;
		raise exception 'Блюдо не добавлено: не заполнено обязательное поле % (BR-5.2, BR-11.3)', err_column;
	when string_data_right_truncation then
		raise exception 'Блюдо не добавлено: название длиннее 100 символов';
	when numeric_value_out_of_range then
		raise exception 'Блюдо не добавлено: цена или рейтинг вне допустимого диапазона';
end;
$$ language plpgsql;
