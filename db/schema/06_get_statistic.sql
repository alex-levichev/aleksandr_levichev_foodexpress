-- FOOD-106. Статистика по ресторанам

set search_path to levichev_food, exts;

create or replace function get_statistic()
returns table (
	restaurant_name varchar,
	best_product_name varchar,
	total_amount numeric,
	avg_amount numeric,
	best_user varchar
) as $$
begin
	return query
	with delivered as materialized (
		select o.order_id, o.restaurant_id as rest_id, o.client_id as cl_id, o.total_amount as order_total
		from levichev_food."order" o
		where o.status = 'доставлен'
	),
	product_qty as (
		select d.rest_id, p.product_name, sum(os.quantity) as qty
		from delivered d
		join levichev_food.order_structure os on os.order_id = d.order_id
		join levichev_food.product p on p.product_id = os.product_id
		group by d.rest_id, p.product_id, p.product_name
	),
	best_product as (
		select pq.rest_id, (array_agg(pq.product_name order by pq.qty desc, random()))[1] as best_name
		from product_qty pq
		group by pq.rest_id
	),
	client_orders as (
		select d.rest_id, c.login, count(*) as cnt, sum(d.order_total) as sum_total
		from delivered d
		join levichev_food.client c on c.client_id = d.cl_id
		group by d.rest_id, c.client_id, c.login
	),
	restaurant_stat as (
		select co.rest_id,
			sum(co.sum_total) as sum_total,
			round(sum(co.sum_total) / sum(co.cnt), 2) as avg_total,
			(array_agg(co.login order by co.cnt desc, random()))[1] as best_login
		from client_orders co
		group by co.rest_id
	)
	select r.restaurant_name, bp.best_name, rs.sum_total, rs.avg_total, rs.best_login
	from levichev_food.restaurant r
	left join restaurant_stat rs on rs.rest_id = r.restaurant_id
	left join best_product bp on bp.rest_id = r.restaurant_id
	order by r.restaurant_name;
end;
$$ language plpgsql;
