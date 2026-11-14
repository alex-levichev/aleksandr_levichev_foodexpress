-- FOOD-103. Удаление тестовых данных

set search_path to levichev_food, exts;

create or replace procedure erase_test_data() as $$
begin
	delete from levichev_food.review;
	delete from levichev_food.payment;
	delete from levichev_food.order_structure;
	delete from levichev_food.courier_pay;
	delete from levichev_food."order";
	delete from levichev_food.product;
	delete from levichev_food.product_category;
	delete from levichev_food.restaurant;
	delete from levichev_food.courier;
	delete from levichev_food.client_address;
	delete from levichev_food.client;
	delete from levichev_food.address;
end;
$$ language plpgsql;
