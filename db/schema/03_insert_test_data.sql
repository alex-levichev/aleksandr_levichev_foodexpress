-- FOOD-102. Генератор тестовых данных

set search_path to levichev_food, exts;

create or replace procedure insert_test_data(value int) as $$
declare
	streets text[] = array['Ленина', 'Советская', 'Садовая', 'Лесная', 'Школьная', 'Набережная',
		'Пушкина', 'Гагарина', 'Мира', 'Молодёжная', 'Центральная', 'Полевая', 'Новая', 'Заводская',
		'Октябрьская', 'Комсомольская', 'Строителей', 'Парковая', 'Луговая', 'Солнечная',
		'Кирова', 'Чехова', 'Лермонтова', 'Победы', 'Речная', 'Вокзальная', 'Береговая',
		'Зелёная', 'Сиреневая', 'Космонавтов'];
	rest_kinds text[] = array['Ресторан', 'Кафе', 'Бистро', 'Трактир', 'Пиццерия', 'Чайхана',
		'Гриль-бар', 'Столовая', 'Кулинария', 'Пекарня'];
	rest_names text[] = array['Самовар', 'Старый мельник', 'Белые ночи', 'Золотой колос',
		'Тёплый очаг', 'Уютный дворик', 'Пять специй', 'Синяя птица', 'Сытый гусь', 'Печь и угли',
		'Каравай', 'Бамбуковая роща', 'Морской бриз', 'Дикая вишня', 'Северный ветер', 'Ласточка',
		'Три поросёнка', 'Вкусная история', 'Красный перец', 'Лукоморье'];
	cat_bases text[] = array['Пицца', 'Роллы', 'Бургеры', 'Супы', 'Салаты', 'Паста',
		'Горячие блюда', 'Блюда на гриле', 'Десерты', 'Напитки', 'Завтраки', 'Выпечка'];
	cat_variants text[] = array['фирменные', 'сезонное меню', 'детское меню', 'постное меню',
		'классика', 'для компании', 'острое', 'лёгкое меню', 'праздничное', 'бизнес-ланч'];
	-- dish_cat[i] — номер категории из cat_bases для блюда dish_names[i]
	dish_cat int[] = array[
		1, 1, 1, 1, 1, 1,
		2, 2, 2, 2, 2,
		3, 3, 3, 3, 3,
		4, 4, 4, 4, 4, 4,
		5, 5, 5, 5, 5,
		6, 6, 6, 6, 6,
		7, 7, 7, 7, 7, 7,
		8, 8, 8, 8, 8,
		9, 9, 9, 9, 9, 9,
		10, 10, 10, 10, 10,
		11, 11, 11, 11, 11,
		12, 12, 12, 12, 12];
	dish_names text[] = array[
		'Пицца Маргарита', 'Пицца Пепперони', 'Пицца Четыре сыра', 'Пицца Гавайская', 'Пицца Деревенская', 'Пицца с грибами',
		'Ролл Филадельфия', 'Ролл Калифорния', 'Ролл с угрём', 'Ролл Овощной', 'Запечённый ролл с лососем',
		'Бургер Классический', 'Чизбургер', 'Бургер с беконом', 'Куриный бургер', 'Двойной бургер',
		'Борщ', 'Солянка мясная', 'Куриный суп с лапшой', 'Суп Том Ям', 'Грибной крем-суп', 'Уха',
		'Салат Цезарь', 'Греческий салат', 'Оливье', 'Винегрет', 'Салат с тунцом',
		'Паста Карбонара', 'Паста Болоньезе', 'Паста с морепродуктами', 'Феттучине Альфредо', 'Лазанья',
		'Плов', 'Пельмени домашние', 'Котлеты по-киевски', 'Бефстроганов', 'Голубцы', 'Жаркое в горшочке',
		'Шашлык из свинины', 'Куриные крылья гриль', 'Стейк из говядины', 'Люля-кебаб', 'Овощи гриль',
		'Чизкейк', 'Тирамису', 'Медовик', 'Наполеон', 'Мороженое пломбир', 'Блинчики с вареньем',
		'Морс клюквенный', 'Компот из сухофруктов', 'Лимонад домашний', 'Чай с чабрецом', 'Квас',
		'Сырники со сметаной', 'Омлет с овощами', 'Каша овсяная', 'Блины с творогом', 'Яичница с беконом',
		'Пирожок с капустой', 'Хачапури по-аджарски', 'Самса с мясом', 'Круассан', 'Ватрушка'];
	m_first text[] = array['Александр', 'Дмитрий', 'Максим', 'Сергей', 'Андрей', 'Алексей',
		'Иван', 'Никита', 'Михаил', 'Егор', 'Артём', 'Павел', 'Роман', 'Олег', 'Кирилл'];
	m_middle text[] = array['Александрович', 'Дмитриевич', 'Сергеевич', 'Андреевич', 'Иванович',
		'Петрович', 'Николаевич', 'Владимирович', 'Олегович', 'Михайлович'];
	m_last text[] = array['Иванов', 'Смирнов', 'Кузнецов', 'Попов', 'Васильев', 'Петров',
		'Соколов', 'Михайлов', 'Новиков', 'Фёдоров', 'Морозов', 'Волков', 'Алексеев', 'Лебедев', 'Семёнов'];
	f_first text[] = array['Анна', 'Мария', 'Елена', 'Ольга', 'Наталья', 'Екатерина',
		'Татьяна', 'Ирина', 'Светлана', 'Юлия', 'Дарья', 'Полина'];
	f_middle text[] = array['Александровна', 'Дмитриевна', 'Сергеевна', 'Андреевна', 'Ивановна',
		'Петровна', 'Николаевна', 'Владимировна', 'Олеговна', 'Михайловна'];
	login_m_first text[] = array['ivan', 'dmitry', 'sergey', 'alex', 'nikita', 'pavel', 'kirill',
		'roman', 'egor', 'artem', 'maxim', 'oleg'];
	login_m_last text[] = array['ivanov', 'kuznetsov', 'petrov', 'novikov', 'morozov', 'semenov',
		'pavlov', 'sokolov', 'volkov', 'orlov'];
	login_f_first text[] = array['anna', 'maria', 'elena', 'olga', 'yulia', 'daria', 'polina',
		'irina', 'ksenia', 'natalia'];
	login_f_last text[] = array['ivanova', 'smirnova', 'popova', 'sokolova', 'volkova', 'lebedeva',
		'egorova', 'orlova', 'morozova', 'petrova'];
	order_notes text[] = array['Позвонить за 10 минут до приезда', 'Оставить у двери',
		'Домофон не работает, позвонить по телефону', 'Без лука, пожалуйста', 'Приборы на двоих',
		'Не звонить в дверь', 'Сдача с 5000', 'Подъезд со двора', 'Комментариев нет'];
	review_good text[] = array['Всё очень вкусно, спасибо!', 'Привезли быстро и горячим',
		'Отличная порция, закажу ещё', 'Курьер вежливый, всё аккуратно упаковано'];
	review_mid text[] = array['В целом неплохо, но можно лучше', 'Вкусно, но доставка задержалась',
		'Нормально, ничего особенного'];
	review_bad text[] = array['Привезли холодным', 'Перепутали заказ', 'Слишком долго ждали доставку'];

	courier_statuses courier_status[] = enum_range(null::courier_status);
	order_statuses order_status[] = enum_range(null::order_status);
	product_statuses product_status[] = enum_range(null::product_status);
	restaurant_statuses restaurant_status[] = enum_range(null::restaurant_status);
	pay_types payment_type[] = enum_range(null::payment_type);
	entity_types review_entity_type[] = enum_range(null::review_entity_type);

	-- 6 месяцев выплат: текущий + 5 предыдущих; все даты — не старше 180 дней
	first_month timestamp = date_trunc('month', localtimestamp) - interval '5 months';
	period_start timestamp = greatest(date_trunc('month', localtimestamp) - interval '5 months',
		date_trunc('day', localtimestamp) - interval '179 days');
	period_end timestamp = localtimestamp - interval '3 hours';

	cat_ids uuid[] = '{}';
	cat_base int[] = '{}';
	cour_ids uuid[] = '{}';
	cour_hire date[] = '{}';
	cour_dismissal date[] = '{}';
	rest_ids uuid[] = '{}';
	prod_ids uuid[] = '{}';
	prod_price numeric[] = '{}';
	client_ids uuid[] = '{}';
	ca_client uuid[] = '{}';
	ca_address uuid[] = '{}';
	ord_ids uuid[] = '{}';
	ord_client uuid[] = '{}';
	ord_rest_n int[] = '{}';
	ord_shift int[] = '{}';
	ord_cnt int[] = '{}';
	ord_ts timestamp[] = '{}';
	ord_delivery timestamp[] = '{}';

	i int;
	j int;
	k int;
	n int;
	attempt int;
	rc int;
	new_id uuid;
	txt text;
	str text;
	house text;
	apt text;
	phone text;
	used_names text[];
	candidates int[];
	c_status courier_status;
	c_hire date;
	c_dismissal date;
	o_ts timestamp;
	o_delivery timestamp;
	o_status order_status;
	o_rest_n int;
	o_courier int;
	o_shift int;
	o_cnt int;
	o_amount numeric;
	pos_idx int[];
	pos_qty numeric[];
	e_type review_entity_type;
	e_id uuid;
	r_rating int;
	slots int;
	need int;
	done int;
	coef numeric;
	next_coef numeric;
	m_cnt int[];
	m_sum numeric[];
begin
	if value is null or value < 1 then
		raise exception 'Параметр value должен быть целым числом >= 1, передано: %', value;
	end if;

	-- рейтинги и pay_status генератор заполняет сам, триггеры rating_change и
	-- payment_status_sync на время генерации не срабатывают
	perform set_config('foodexpress.generator', 'on', true);

	-- категории
	for i in 1..value
	loop
		k = 1 + floor(random() * array_length(cat_bases, 1))::int;
		txt = cat_bases[k];
		attempt = 0;
		while exists (select 1 from product_category where product_category_name = txt) and attempt < 30
		loop
			k = 1 + floor(random() * array_length(cat_bases, 1))::int;
			txt = cat_bases[k] || ' — ' || cat_variants[1 + floor(random() * array_length(cat_variants, 1))::int];
			attempt = attempt + 1;
		end loop;

		insert into product_category (product_category_id, product_category_name)
		values (exts.uuid_generate_v4(), txt)
		returning product_category_id into new_id;

		cat_ids = cat_ids || new_id;
		cat_base = cat_base || k;
	end loop;

	-- курьеры: первый нанят в начале периода и работает
	for i in 1..value
	loop
		if i = 1 then
			c_status = 'свободен';
			c_hire = period_start::date;
		else
			c_status = courier_statuses[1 + floor(random() * array_length(courier_statuses, 1))::int];
			if c_status = 'уволен' and random() < 0.6 then
				c_status = 'свободен';
			end if;
			c_hire = period_start::date + floor(random() * 120)::int;
		end if;

		if c_status = 'уволен' then
			c_dismissal = c_hire + floor(random() * (current_date - c_hire + 1))::int;
		else
			c_dismissal = null;
		end if;

		if random() < 0.7 then
			txt = m_last[1 + floor(random() * array_length(m_last, 1))::int] || ' '
				|| m_first[1 + floor(random() * array_length(m_first, 1))::int] || ' '
				|| m_middle[1 + floor(random() * array_length(m_middle, 1))::int];
		else
			txt = m_last[1 + floor(random() * array_length(m_last, 1))::int] || 'а '
				|| f_first[1 + floor(random() * array_length(f_first, 1))::int] || ' '
				|| f_middle[1 + floor(random() * array_length(f_middle, 1))::int];
		end if;

		insert into courier (courier_id, fio, phone_number, status, hire_date, dismissal_date, coefficient)
		values (exts.uuid_generate_v4(), txt,
			'79' || lpad(floor(random() * 1000000000)::bigint::text, 9, '0'),
			c_status, c_hire, c_dismissal, 0.1)
		returning courier_id into new_id;

		cour_ids = cour_ids || new_id;
		cour_hire = cour_hire || c_hire;
		cour_dismissal = cour_dismissal || c_dismissal;
	end loop;

	-- рестораны и их адреса
	for i in 1..value
	loop
		loop
			str = 'ул. ' || streets[1 + floor(random() * array_length(streets, 1))::int];
			house = (1 + floor(random() * 150)::int)::text;
			exit when not exists (
				select 1 from address
				where street = str and house_number = house and apartment_office is null);
		end loop;

		insert into address (address_id, street, house_number, apartment_office)
		values (exts.uuid_generate_v4(), str, house, null)
		returning address_id into new_id;

		txt = rest_kinds[1 + floor(random() * array_length(rest_kinds, 1))::int] || ' «'
			|| rest_names[1 + floor(random() * array_length(rest_names, 1))::int] || '»';
		attempt = 0;
		while exists (select 1 from restaurant where restaurant_name = txt) and attempt < 50
		loop
			txt = rest_kinds[1 + floor(random() * array_length(rest_kinds, 1))::int] || ' «'
				|| rest_names[1 + floor(random() * array_length(rest_names, 1))::int] || '»';
			attempt = attempt + 1;
		end loop;
		if attempt = 50 then
			txt = txt || ' на ' || str;
		end if;

		insert into restaurant (restaurant_id, restaurant_name, address_id, description,
			work_start, work_end, company_details, rating, status)
		values (exts.uuid_generate_v4(), txt, new_id,
			'Домашняя кухня, свежие продукты, доставка по городу',
			time '07:00' + floor(random() * 9)::int * interval '30 minutes',
			time '20:00' + floor(random() * 7)::int * interval '30 minutes',
			'ИНН ' || lpad(floor(random() * 10000000000)::bigint::text, 10, '0')
				|| ', ОГРН 1' || lpad(floor(random() * 1000000000000)::bigint::text, 12, '0')
				|| ', р/с 40702810' || lpad(floor(random() * 1000000000000)::bigint::text, 12, '0'),
			null,
			case when random() < 0.85 then 'активен'::restaurant_status
				else restaurant_statuses[1 + floor(random() * array_length(restaurant_statuses, 1))::int] end)
		returning restaurant_id into new_id;

		rest_ids = rest_ids || new_id;
	end loop;

	-- блюда: по 5 на ресторан, блюда ресторана i — позиции (i-1)*5+1 .. (i-1)*5+5
	for i in 1..value
	loop
		used_names = '{}';
		for j in 1..5
		loop
			attempt = 0;
			loop
				n = 1 + floor(random() * array_length(cat_ids, 1))::int;
				candidates = array(
					select d.idx
					from generate_subscripts(dish_cat, 1) as d(idx)
					where dish_cat[d.idx] = cat_base[n]);
				k = candidates[1 + floor(random() * array_length(candidates, 1))::int];
				attempt = attempt + 1;
				exit when not (dish_names[k] = any(used_names)) or attempt > 30;
			end loop;
			used_names = used_names || dish_names[k];

			insert into product (product_id, product_name, product_category_id, price, restaurant_id,
				photo_url, rating, status, description)
			values (exts.uuid_generate_v4(), dish_names[k], cat_ids[n],
				(15 + floor(random() * 106)::int) * 10,
				rest_ids[i],
				null,
				null,
				case when random() < 0.85 then 'доступно'::product_status
					else product_statuses[1 + floor(random() * array_length(product_statuses, 1))::int] end,
				case when cat_base[n] = 10 then 'Объём ' || (25 + floor(random() * 26)::int) * 10 || ' мл'
					else 'Порция ' || (200 + floor(random() * 300)::int) || ' г, готовится по рецепту шефа' end)
			returning product_id, price into new_id, o_amount;

			prod_ids = prod_ids || new_id;
			prod_price = prod_price || o_amount;
		end loop;
	end loop;

	-- клиенты
	for i in 1..value
	loop
		loop
			if random() < 0.5 then
				txt = login_m_first[1 + floor(random() * array_length(login_m_first, 1))::int] || '.'
					|| login_m_last[1 + floor(random() * array_length(login_m_last, 1))::int];
			else
				txt = login_f_first[1 + floor(random() * array_length(login_f_first, 1))::int] || '.'
					|| login_f_last[1 + floor(random() * array_length(login_f_last, 1))::int];
			end if;
			txt = txt || (10 + floor(random() * 990)::int);
			exit when not exists (select 1 from client where login = txt);
		end loop;
		loop
			phone = '79' || lpad(floor(random() * 1000000000)::bigint::text, 9, '0');
			exit when not exists (select 1 from client where phone_number = phone);
		end loop;

		insert into client (client_id, login, password, phone_number)
		values (exts.uuid_generate_v4(), txt, md5(random()::text), phone)
		returning client_id into new_id;

		client_ids = client_ids || new_id;
	end loop;

	-- адреса клиентов: по 4 на клиента
	for k in 1..value * 4
	loop
		loop
			str = 'ул. ' || streets[1 + floor(random() * array_length(streets, 1))::int];
			house = (1 + floor(random() * 150)::int)::text;
			if random() < 0.75 then
				apt = (1 + floor(random() * 300)::int)::text;
			else
				apt = null;
			end if;
			exit when not exists (
				select 1 from address
				where street = str and house_number = house and apartment_office is not distinct from apt);
		end loop;

		insert into address (address_id, street, house_number, apartment_office)
		values (exts.uuid_generate_v4(), str, house, apt)
		returning address_id into new_id;

		insert into client_address (client_id, address_id)
		values (client_ids[((k - 1) % value) + 1], new_id);

		ca_client = ca_client || client_ids[((k - 1) % value) + 1];
		ca_address = ca_address || new_id;
	end loop;

	-- общие адреса: часть клиентов пользуется адресом другого клиента
	n = array_length(ca_address, 1);
	for i in 1..value
	loop
		if random() < 0.3 then
			new_id = ca_address[1 + floor(random() * n)::int];
			insert into client_address (client_id, address_id)
			values (client_ids[i], new_id)
			on conflict do nothing;
			get diagnostics rc = row_count;
			if rc = 1 then
				ca_client = ca_client || client_ids[i];
				ca_address = ca_address || new_id;
			end if;
		end if;
	end loop;

	-- заказы, состав заказов, оплаты
	for i in 1..value * 5
	loop
		k = 1 + floor(random() * array_length(ca_client, 1))::int;
		o_rest_n = 1 + floor(random() * value)::int;
		o_ts = period_start + random() * (period_end - period_start);

		-- курьер должен работать на дату заказа
		attempt = 0;
		loop
			o_courier = 1 + floor(random() * value)::int;
			attempt = attempt + 1;
			exit when (cour_hire[o_courier] <= o_ts::date
				and (cour_dismissal[o_courier] is null or cour_dismissal[o_courier] > o_ts::date))
				or attempt > 10;
		end loop;
		if attempt > 10 then
			o_courier = 1;
		end if;

		if random() < 0.75 then
			o_status = 'доставлен';
		else
			o_status = order_statuses[1 + floor(random() * array_length(order_statuses, 1))::int];
			if o_status in ('создан', 'готовится', 'в_доставке') and o_ts < localtimestamp - interval '2 days' then
				o_status = 'отменён';
			end if;
		end if;
		if o_status = 'доставлен' then
			o_delivery = o_ts + (30 + floor(random() * 61)::int) * interval '1 minute';
		else
			o_delivery = null;
		end if;

		o_cnt = 1 + floor(random() * 5)::int;
		o_shift = floor(random() * 5)::int;
		pos_idx = '{}';
		pos_qty = '{}';
		o_amount = 0;
		for j in 0..o_cnt - 1
		loop
			n = (o_rest_n - 1) * 5 + ((o_shift + j) % 5) + 1;
			pos_idx = pos_idx || n;
			pos_qty = pos_qty || (1 + floor(random() * 3)::int)::numeric;
			o_amount = o_amount + prod_price[n] * pos_qty[j + 1];
		end loop;

		while o_amount + round(o_amount * 0.10, 2) < 1000
		loop
			pos_qty[1] = pos_qty[1] + 1;
			o_amount = o_amount + prod_price[pos_idx[1]];
		end loop;

		insert into "order" (order_id, courier_id, client_id, address_id, restaurant_id,
			order_timestamp, delivery_timestamp, order_amount, status, pay_status, description)
		values (exts.uuid_generate_v4(), cour_ids[o_courier], ca_client[k], ca_address[k], rest_ids[o_rest_n],
			o_ts, o_delivery, o_amount, o_status, 'оплачен',
			order_notes[1 + floor(random() * array_length(order_notes, 1))::int])
		returning order_id into new_id;

		for j in 1..o_cnt
		loop
			insert into order_structure (order_id, product_id, quantity)
			values (new_id, prod_ids[pos_idx[j]], pos_qty[j]);
		end loop;

		insert into payment (payment_id, order_id, payment_type, amount, transaction_id,
			transaction_timestamp, status)
		values (exts.uuid_generate_v4(), new_id,
			pay_types[1 + floor(random() * array_length(pay_types, 1))::int],
			o_amount + round(o_amount * 0.10, 2),
			'TX' || upper(replace(exts.uuid_generate_v4()::text, '-', '')),
			o_ts + (1 + floor(random() * 5)::int) * interval '1 minute',
			'успех');

		ord_ids = ord_ids || new_id;
		ord_client = ord_client || ca_client[k];
		ord_rest_n = ord_rest_n || o_rest_n;
		ord_shift = ord_shift || o_shift;
		ord_cnt = ord_cnt || o_cnt;
		ord_ts = ord_ts || o_ts;
		ord_delivery = ord_delivery || o_delivery;
	end loop;

	-- отзывы: на доставленные заказы, не больше одного на объект в заказе
	need = value * 5;
	candidates = '{}';
	slots = 0;
	for i in 1..array_length(ord_ids, 1)
	loop
		if ord_delivery[i] is not null then
			candidates = candidates || i;
			slots = slots + ord_cnt[i] + 2;
		end if;
	end loop;
	if slots < need then
		candidates = array(select generate_series(1, array_length(ord_ids, 1)));
	end if;

	done = 0;
	attempt = 0;
	while done < need
	loop
		attempt = attempt + 1;
		if attempt > need * 100 then
			raise exception 'Не удалось сгенерировать % отзывов', need;
		end if;

		i = candidates[1 + floor(random() * array_length(candidates, 1))::int];
		e_type = entity_types[1 + floor(random() * array_length(entity_types, 1))::int];
		if e_type = 'заказ' then
			e_id = ord_ids[i];
		elseif e_type = 'ресторан' then
			e_id = rest_ids[ord_rest_n[i]];
		else
			e_id = prod_ids[(ord_rest_n[i] - 1) * 5 + ((ord_shift[i] + floor(random() * ord_cnt[i])::int) % 5) + 1];
		end if;

		r_rating = 1 + floor(random() * 5)::int;
		if r_rating >= 4 then
			txt = review_good[1 + floor(random() * array_length(review_good, 1))::int];
		elseif r_rating = 3 then
			txt = review_mid[1 + floor(random() * array_length(review_mid, 1))::int];
		else
			txt = review_bad[1 + floor(random() * array_length(review_bad, 1))::int];
		end if;

		insert into review (review_id, client_id, review_timestamp, entity_id, entity_type,
			order_id, description, photo_url, rating)
		values (exts.uuid_generate_v4(), ord_client[i],
			least(localtimestamp, coalesce(ord_delivery[i], ord_ts[i]) + random() * interval '2 days'),
			e_id, e_type, ord_ids[i], txt,
			null,
			r_rating)
		on conflict (order_id, entity_type, entity_id) do nothing;
		get diagnostics rc = row_count;
		done = done + rc;
	end loop;

	-- рейтинги блюд и ресторанов этого вызова
	update product p
	set rating = r.avg_rating
	from (
		select rv.entity_id, round(avg(rv.rating), 2) as avg_rating
		from review rv
		where rv.entity_type = 'блюдо' and rv.entity_id = any(prod_ids)
		group by rv.entity_id) r
	where p.product_id = r.entity_id;

	update restaurant rs
	set rating = r.avg_rating
	from (
		select rv.entity_id, round(avg(rv.rating), 2) as avg_rating
		from review rv
		where rv.entity_type = 'ресторан' and rv.entity_id = any(rest_ids)
		group by rv.entity_id) r
	where rs.restaurant_id = r.entity_id;

	-- выплаты курьерам за 6 месяцев и коэффициент на следующий месяц
	for i in 1..value
	loop
		select array_agg(coalesce(t.cnt, 0) order by m.m),
			array_agg(coalesce(t.commission_sum, 0) order by m.m)
		into m_cnt, m_sum
		from generate_series(first_month, date_trunc('month', localtimestamp), interval '1 month') as m(m)
		left join (
			select date_trunc('month', o.delivery_timestamp) as month_start,
				count(*) as cnt,
				sum(o.commission) as commission_sum
			from "order" o
			where o.courier_id = cour_ids[i] and o.status = 'доставлен'
			group by 1) t on t.month_start = m.m;

		coef = 0.1;
		for j in 1..array_length(m_cnt, 1)
		loop
			insert into courier_pay (year, month, courier_id, amount, coefficient_used)
			values (date_part('year', first_month + (j - 1) * interval '1 month')::int,
				date_part('month', first_month + (j - 1) * interval '1 month')::int,
				cour_ids[i], round(coef * m_sum[j], 2), coef);

			next_coef = case
				when m_cnt[j] <= 150 then 0.1
				when m_cnt[j] <= 250 then 0.2
				when m_cnt[j] <= 500 then 0.3
				else 0.5
			end;

			-- после месяца увольнения коэффициент не пересчитывается
			if j < array_length(m_cnt, 1) and (cour_dismissal[i] is null
				or first_month + (j - 1) * interval '1 month' < date_trunc('month', cour_dismissal[i])) then
				coef = next_coef;
			end if;
		end loop;

		update courier
		set coefficient = case when status = 'уволен' then coef else next_coef end
		where courier_id = cour_ids[i];
	end loop;

	perform set_config('foodexpress.generator', 'off', true);
end;
$$ language plpgsql
set search_path = levichev_food, exts;
