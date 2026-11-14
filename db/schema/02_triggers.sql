-- Триггеры целостности и FOOD-105

set search_path to levichev_food, exts;

-- BR-7.3: блюдо в заказе из ресторана заказа
create or replace function check_order_structure_restaurant() returns trigger as $$
declare
	order_restaurant uuid;
	product_restaurant uuid;
begin
	select restaurant_id into order_restaurant
	from levichev_food."order"
	where order_id = new.order_id;

	select restaurant_id into product_restaurant
	from levichev_food.product
	where product_id = new.product_id;

	if order_restaurant <> product_restaurant then
		raise exception 'Блюдо % не из ресторана заказа % (BR-7.3)', new.product_id, new.order_id;
	end if;
	return new;
end;
$$ language plpgsql;

create trigger order_structure_restaurant_tg
before insert or update of order_id, product_id on order_structure
for each row execute procedure check_order_structure_restaurant();

-- BR-7.3: нельзя сменить ресторан заказа, если в нём есть блюда
create or replace function check_order_restaurant_change() returns trigger as $$
begin
	if exists (
		select 1
		from levichev_food.order_structure os
		join levichev_food.product p on p.product_id = os.product_id
		where os.order_id = new.order_id and p.restaurant_id <> new.restaurant_id)
	then
		raise exception 'В заказе % есть блюда другого ресторана, сменить ресторан нельзя (BR-7.3)', new.order_id;
	end if;
	return new;
end;
$$ language plpgsql;

create trigger order_restaurant_change_tg
before update of restaurant_id on "order"
for each row execute procedure check_order_restaurant_change();

-- BR-7.3: нельзя перенести блюдо в другой ресторан, если оно есть в заказах
create or replace function check_product_restaurant_change() returns trigger as $$
begin
	if exists (
		select 1
		from levichev_food.order_structure os
		join levichev_food."order" o on o.order_id = os.order_id
		where os.product_id = new.product_id and o.restaurant_id <> new.restaurant_id)
	then
		raise exception 'Блюдо % уже заказывали в другом ресторане, перенести нельзя (BR-7.3)', new.product_id;
	end if;
	return new;
end;
$$ language plpgsql;

create trigger product_restaurant_change_tg
before update of restaurant_id on product
for each row execute procedure check_product_restaurant_change();

-- BR-9.1, BR-9.2: объект отзыва относится к заказу
create or replace function check_review_entity() returns trigger as $$
begin
	if new.entity_type = 'заказ' and new.entity_id <> new.order_id then
		raise exception 'Отзыв на заказ: entity_id должен совпадать с order_id (BR-9.2)';
	elseif new.entity_type = 'ресторан' and not exists (
		select 1
		from levichev_food."order"
		where order_id = new.order_id and restaurant_id = new.entity_id)
	then
		raise exception 'Ресторан % не относится к заказу % (BR-9.2)', new.entity_id, new.order_id;
	elseif new.entity_type = 'блюдо' and not exists (
		select 1
		from levichev_food.order_structure
		where order_id = new.order_id and product_id = new.entity_id)
	then
		raise exception 'Блюда % нет в заказе % (BR-9.2)', new.entity_id, new.order_id;
	end if;
	return new;
end;
$$ language plpgsql;

create trigger review_entity_tg
before insert or update of order_id, entity_type, entity_id on review
for each row execute procedure check_review_entity();

-- BR-8.7: статус оплаты заказа по попыткам оплаты
create or replace function payment_status_sync() returns trigger as $$
declare
	ord uuid;
begin
	foreach ord in array array[old.order_id, new.order_id]
	loop
		if ord is not null then
			update levichev_food."order" o
			set pay_status = case
					when exists (select 1 from levichev_food.payment p
						where p.order_id = ord and p.status = 'успех') then 'оплачен'
					when exists (select 1 from levichev_food.payment p
						where p.order_id = ord and p.status = 'в_обработке') then 'ожидает'
					when exists (select 1 from levichev_food.payment p
						where p.order_id = ord) then 'ошибка'
					else 'ожидает'
				end::levichev_food.order_pay_status
			where o.order_id = ord;
		end if;
	end loop;
	return null;
end;
$$ language plpgsql;

create trigger payment_status_sync_tg
after insert or update or delete on payment
for each row
when (coalesce(current_setting('foodexpress.generator', true), '') <> 'on')
execute procedure payment_status_sync();

-- FOOD-105: пересчёт рейтинга блюда и ресторана
create or replace function rating_change() returns trigger as $$
declare
	e_type levichev_food.review_entity_type;
	e_id uuid;
	i int;
begin
	for i in 1..2
	loop
		if i = 1 and tg_op in ('UPDATE', 'DELETE') then
			e_type = old.entity_type;
			e_id = old.entity_id;
		elseif i = 2 and tg_op in ('INSERT', 'UPDATE') then
			e_type = new.entity_type;
			e_id = new.entity_id;
		else
			continue;
		end if;

		if e_type = 'блюдо' then
			update levichev_food.product
			set rating = (
				select round(avg(r.rating), 2)
				from levichev_food.review r
				where r.entity_type = 'блюдо' and r.entity_id = e_id)
			where product_id = e_id;
		elseif e_type = 'ресторан' then
			update levichev_food.restaurant
			set rating = (
				select round(avg(r.rating), 2)
				from levichev_food.review r
				where r.entity_type = 'ресторан' and r.entity_id = e_id)
			where restaurant_id = e_id;
		end if;
	end loop;
	return null;
end;
$$ language plpgsql;

create trigger rating_change_tg
after insert or update or delete on review
for each row
when (coalesce(current_setting('foodexpress.generator', true), '') <> 'on')
execute procedure rating_change();
