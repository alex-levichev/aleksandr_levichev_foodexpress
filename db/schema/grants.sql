-- FOOD-109. Пользователь inspector и права

do $$
begin
	if not exists (select 1 from pg_catalog.pg_roles where rolname = 'inspector') then
		create role inspector with login password 'NetoSQL2025';
	else
		alter role inspector with login password 'NetoSQL2025';
	end if;
end;
$$ language plpgsql;

do $$
begin
	execute 'grant connect on database ' || quote_ident(current_database()) || ' to inspector';
end;
$$ language plpgsql;

grant all privileges on schema levichev_food to inspector;
grant all privileges on all tables in schema levichev_food to inspector;
grant all privileges on all sequences in schema levichev_food to inspector;
grant all privileges on all routines in schema levichev_food to inspector;
grant usage on type levichev_food.restaurant_status, levichev_food.product_status,
	levichev_food.courier_status, levichev_food.order_status, levichev_food.order_pay_status,
	levichev_food.payment_status, levichev_food.payment_type, levichev_food.review_entity_type
	to inspector;

alter default privileges in schema levichev_food grant all on tables to inspector;
alter default privileges in schema levichev_food grant all on sequences to inspector;
alter default privileges in schema levichev_food grant all on routines to inspector;

do $$
begin
	grant usage on schema exts to inspector;
	grant execute on all functions in schema exts to inspector;
exception when insufficient_privilege then
	raise warning 'Нет прав выдать доступ к exts: по умолчанию функции доступны через PUBLIC';
end;
$$ language plpgsql;

do $$
begin
	grant usage on schema information_schema to inspector;
	grant usage on schema pg_catalog to inspector;
exception when insufficient_privilege then
	raise warning 'Нет прав выдать доступ к системным схемам: по умолчанию они доступны через PUBLIC';
end;
$$ language plpgsql;
