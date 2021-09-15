
--1. В каких городах больше одного аэропорта?
--Группируем таблицу airports по городам и считаем количество аэропортов в каждом городе
--Если количество больше одного, то выводим соответствующую строку.

select a.city , count(a.airport_code) amount_of_airports
from airports a
group by a.city
having count(a.airport_code) > 1

--2. В каких аэропортах есть рейсы, выполняемые самолетом с максимальной дальностью перелета? (- Подзапрос)
--В подзапросе находим самолеты с максимальной дальностью перелета (select max(a."range")from aircrafts a)
--В основном запросе в таблице flights находим уникальные аэропорты где aircraft_code в списке самолетов, выбранных подзапросом.

select distinct f.departure_airport 
from flights f 
where f.aircraft_code in (
	select a.aircraft_code 
	from aircrafts a
	where a."range" = (select max(a."range")
	from aircrafts a)
	)

--3. Вывести 10 рейсов с максимальным временем задержки вылета (Оператор LIMIT)
--Находим разницу между актуальным временем вылета и плановым и если она актуальна (не null), 
--то сортируем в порядке убывания и находим первые десять строк.

select f.flight_id, f.actual_departure, f.scheduled_departure, (f.actual_departure - f.scheduled_departure) max_del
from flights f 
where (f.actual_departure - f.scheduled_departure) is not null
order by max_del desc
limit 10

--4. Были ли брони, по которым не были получены посадочные талоны?
--Берем таблицу tickets, где есть брони и соединяем с таблицей boarding_passes чтобы выявить каким билетам 
--из tickets нет соответствия в boarding_passes.
--Выводим такие брони, где нет соответствия и группируем по ним, чтобы убрать дубли.
		
select t.book_ref
from tickets t 
left join boarding_passes bp on t.ticket_no = bp.ticket_no 
where bp.ticket_no is null
group by t.book_ref


--5. Найдите свободные места для каждого рейса, их % отношение к общему количеству мест в самолете.
--Добавьте столбец с накопительным итогом - суммарное накопление количества вывезенных пассажиров из каждого аэропорта на каждый день. 
--Т.е. в этом столбце должна отражаться накопительная сумма - сколько человек уже вылетело из данного аэропорта на этом или более ранних рейсах за день.
--Сначала находим количество пассажиров, которым выданы посадочные талоны на рейс, затем общее количество мест в самолете, который осуществляет полет,
--соединяем результирующие таблицы, добавляем к ним flights, чтобы получить аэропорт и время отправления.
--выводим расчет по свободным местам, их проценту, и оконную функцию для расчета нарастающего итога по вывезенным пассажирам в разрезе даты и аэропорта.

select o_seats.flight_id, f.departure_airport, f.scheduled_departure, 
		(a_seats.all_seats - o_seats.oc_seats) free_seats, 
		round((100*(a_seats.all_seats - o_seats.oc_seats)/a_seats.all_seats::numeric),2) per_free,
		sum(o_seats.oc_seats) over (partition by f.departure_airport, date(f.scheduled_departure) order by f.scheduled_departure),
		o_seats.oc_seats	
from (
	select f.flight_id , count(bp.seat_no) oc_seats
	from boarding_passes bp 
	join flights f using(flight_id)
	group by f.flight_id) o_seats
left join (select f.flight_id, count(s.seat_no) all_seats									
	from seats s 
	join flights f using(aircraft_code)
	group by f.flight_id) a_seats on o_seats.flight_id = a_seats.flight_id
left join flights f on f.flight_id = o_seats.flight_id
order by f.departure_airport

--6. Найдите процентное соотношение перелетов по типам самолетов от общего количества. ( Подзапрос. Оператор ROUND)
--В подзапросе определяем общее количество перелетов всеми самолетами, в таблице flights группируем по видам самолетов 
--и находим количество перелетов каждым самолетом, добавляем таблицу aircrafts, чтобы вывести название самолета и в выводе прописываем вычисления и округления.

select a2.model , 
	count(f.aircraft_code) amount, 
	round((100*count(f.aircraft_code))/(select count(f.aircraft_code)::numeric from flights f),2)
from flights f
join aircrafts a2 using(aircraft_code)
group by f.aircraft_code, a2.model
order by amount desc

--7. Были ли города, в которые можно  добраться бизнес - классом дешевле, чем эконом-классом в рамках перелета? (CTE)
--Во-первых находим уникальную стоимость Эконом и Бизнес классов по каждому уникальному перелету из твблицы ticket_flights в двух раздельных cte. 
--Соединяем их по flight_id и проверяем, есть ли такие перелеты, где эконом тариф больше бизнес.
--Во втором варианте можно добавить таблицы flights и airports, чтобы вывести название города прибытия и обернуть основной запрос в подзапрос, 
--чтобы вывести уникальный город, соответствующий условию.

--Вариант1, короткий и отвечает на вопрос были ли вообще такие перелеты.

with cte_e as(
	select distinct flight_id, amount economy
	from ticket_flights
	where fare_conditions = 'Economy'
),
	 cte_b as( 
	select distinct flight_id, amount business
	from ticket_flights
	where fare_conditions = 'Business'
)
select cte_e.flight_id, cte_e.economy, cte_b.business
from cte_e
join cte_b on cte_e.flight_id = cte_b.flight_id
where cte_b.business < cte_e.economy

--Вариант2, длинный и отвечает на вопрос были ли именно города.

with cte_e as(
	select distinct flight_id, amount economy
	from ticket_flights
	where fare_conditions = 'Economy'
),
	 cte_b as( 
	select distinct flight_id, amount business
	from ticket_flights
	where fare_conditions = 'Business'
)
select distinct t.city
from (select a.city, cte_e.flight_id, cte_e.economy, cte_b.business
	from cte_e
	join cte_b on cte_e.flight_id = cte_b.flight_id
	join flights f on cte_e.flight_id = f.flight_id 
	join airports a on f.arrival_airport = a.airport_code 
	where cte_b.business < cte_e.economy
	) t
	
--8. Между какими городами нет прямых рейсов? (Декартово произведение в предложении FROM. Самостоятельно созданные представления. Оператор EXCEPT)
--Выводим все возможные маршруты с помощью декартова произведения, и убираем дубли и строки, где города отправления и прибытия одинаковые, 
--создаем материализованное представление, т.к. данные в нем не оперативные и поменяются только тогда, когда в обслуживании появятся новые города.
--Выводим с помощью таблицы flights все имеющиеся маршруты, соединяем с таблицей airports, чтобы получить данные как по городу вылета, так и по городу прилета.
--Группируем, чтобы убрать дубли, создаем обычное представление на случай если внезапно появятся новые маршруты между уже обслуживаемыми городами - информация будет оперативной.
--Используем EXCEPT, чтобы убрать из всех возможных маршрутов имеющиеся и получаем не существующие маршруты между городами.

create materialized view all_routs as
	select  a.city departure , a2.city arrival
	from airports a, airports a2
	where a.city <> a2.city 
	group by a.city, a2.city
	
create view used_routs as
	select  a.city departure, a2.city arrival
	from flights f 
	join airports a on a.airport_code = f.departure_airport
	join airports a2 on a2.airport_code = f.arrival_airport
	group by a.city, a2.city
	
select *
from all_routs
where all_routs.departure > all_routs.arrival
except
select *
from used_routs
where used_routs.departure > used_routs.arrival

--9. Вычислите расстояние между аэропортами, связанными прямыми рейсами, сравните с допустимой максимальной дальностью перелетов  в самолетах, 
--обслуживающих эти рейсы (Оператор RADIANS или использование sind/cosd)
--Выводим с помощью таблицы flights все имеющиеся маршруты, соединяем с таблицей airports, чтобы получить данные как по аэропорту вылета, так и по аэропорту прилета.
--Соединяем с таблицей aircrafts, чтобы получить максимальную дистанцию, на которую расчитана эта модель самолета.
--По формуле вычисляем расстояние до городов и сравниваем его с максимальной дистанцией. Сортируем, чтобы узнать наиболее критические в этом отношении маршруты.


select
	distinct f.departure_airport,
	f.arrival_airport,
	ac.model ,
	ac."range" ,
	round(6371 * acos(sin(RADIANS(a.latitude))* sin(RADIANS(a2.latitude)) + cos(RADIANS(a.latitude))* cos(RADIANS(a2.latitude))* cos(RADIANS(a.longitude) - RADIANS(a2.longitude)))::numeric, 1) distance,
	ac."range" - round(6371 * acos(sin(RADIANS(a.latitude))* sin(RADIANS(a2.latitude)) + cos(RADIANS(a.latitude))* cos(RADIANS(a2.latitude))* cos(RADIANS(a.longitude) - RADIANS(a2.longitude)))::numeric, 1) difference
from
	flights f
join airports a on
	a.airport_code = f.departure_airport
join airports a2 on
	a2.airport_code = f.arrival_airport
join aircrafts ac on
	f.aircraft_code = ac.aircraft_code 
where f.departure_airport > f.arrival_airport
order by difference

