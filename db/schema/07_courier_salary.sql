-- FOOD-107. Зарплата курьеров

set search_path to levichev_food, exts;

create or replace procedure courier_salary() as $$
declare
	cur_year int = date_part('year', current_date);
	cur_month int = date_part('month', current_date);
	month_start date = date_trunc('month', current_date);
	month_end date = date_trunc('month', current_date) + interval '1 month';
begin
	insert into levichev_food.courier_pay (year, month, courier_id, amount, coefficient_used)
	select cur_year, cur_month, c.courier_id,
		round(coalesce(cp.coefficient_used, c.coefficient) * coalesce(sum(o.commission), 0), 2),
		coalesce(cp.coefficient_used, c.coefficient)
	from levichev_food.courier c
	left join levichev_food.courier_pay cp
		on cp.courier_id = c.courier_id and cp.year = cur_year and cp.month = cur_month
	left join levichev_food."order" o
		on o.courier_id = c.courier_id
		and o.status = 'доставлен'
		and o.order_timestamp >= month_start
		and o.order_timestamp < month_end
	group by c.courier_id, c.coefficient, cp.coefficient_used
	on conflict (year, month, courier_id) do update
	set amount = excluded.amount,
		coefficient_used = excluded.coefficient_used;

	update levichev_food.courier c
	set coefficient = case
			when coalesce(d.cnt, 0) <= 150 then 0.1
			when d.cnt <= 250 then 0.2
			when d.cnt <= 500 then 0.3
			else 0.5
		end
	from levichev_food.courier c2
	left join (
		select o.courier_id, count(*) as cnt
		from levichev_food."order" o
		where o.status = 'доставлен'
			and o.order_timestamp >= month_start
			and o.order_timestamp < month_end
		group by o.courier_id) d on d.courier_id = c2.courier_id
	where c.courier_id = c2.courier_id
		and c.status <> 'уволен';
end;
$$ language plpgsql;
