-- FOOD-108. Отчёт how_much_money

set search_path to levichev_food, exts;

create or replace view how_much_money as
with recursive bounds as (
	select date_trunc('month', min(o.order_timestamp))::date as first_month,
		date_trunc('month', max(o.order_timestamp))::date as last_month
	from levichev_food."order" o
	where o.status = 'доставлен'
),
months as (
	select b.first_month as month_start
	from bounds b
	where b.first_month is not null
	union all
	select (m.month_start + interval '1 month')::date
	from months m
	join bounds b on m.month_start < b.last_month
),
orders_by_month as (
	select date_trunc('month', o.order_timestamp)::date as month_start,
		sum(o.order_amount) as sum_no_commission,
		sum(o.total_amount) as sum_with_commission
	from levichev_food."order" o
	where o.status = 'доставлен'
	group by 1
),
pay_by_month as (
	select make_date(cp.year, cp.month, 1) as month_start,
		sum(cp.amount) as courier_pay
	from levichev_food.courier_pay cp
	group by 1
),
report as (
	select m.month_start,
		coalesce(obm.sum_no_commission, 0) as sum_no_commission,
		coalesce(obm.sum_with_commission, 0) as sum_with_commission,
		coalesce(obm.sum_with_commission, 0) - coalesce(obm.sum_no_commission, 0) as commission,
		coalesce(pbm.courier_pay, 0) as courier_pay
	from months m
	left join orders_by_month obm on obm.month_start = m.month_start
	left join pay_by_month pbm on pbm.month_start = m.month_start
)
select to_char(r.month_start, 'YYYY-MM') as year_month,
	r.sum_no_commission::numeric as sum_no_commission,
	r.sum_with_commission::numeric as sum_with_commission,
	r.commission::numeric as commission,
	lag(r.commission) over (order by r.month_start)::numeric as prev_commission,
	(r.commission - lag(r.commission) over (order by r.month_start))::numeric as commission_diff,
	r.courier_pay::numeric as courier_pay,
	(r.commission - r.courier_pay)::numeric as net_profit
from report r
order by r.month_start;
