
--1. � ����� ������� ������ ������ ���������?
--���������� ������� airports �� ������� � ������� ���������� ���������� � ������ ������
--���� ���������� ������ ������, �� ������� ��������������� ������.

select a.city , count(a.airport_code) amount_of_airports
from airports a
group by a.city
having count(a.airport_code) > 1

--2. � ����� ���������� ���� �����, ����������� ��������� � ������������ ���������� ��������? (- ���������)
--� ���������� ������� �������� � ������������ ���������� �������� (select max(a."range")from aircrafts a)
--� �������� ������� � ������� flights ������� ���������� ��������� ��� aircraft_code � ������ ���������, ��������� �����������.

select distinct f.departure_airport 
from flights f 
where f.aircraft_code in (
	select a.aircraft_code 
	from aircrafts a
	where a."range" = (select max(a."range")
	from aircrafts a)
	)

--3. ������� 10 ������ � ������������ �������� �������� ������ (�������� LIMIT)
--������� ������� ����� ���������� �������� ������ � �������� � ���� ��� ��������� (�� null), 
--�� ��������� � ������� �������� � ������� ������ ������ �����.

select f.flight_id, f.actual_departure, f.scheduled_departure, (f.actual_departure - f.scheduled_departure) max_del
from flights f 
where (f.actual_departure - f.scheduled_departure) is not null
order by max_del desc
limit 10

--4. ���� �� �����, �� ������� �� ���� �������� ���������� ������?
--����� ������� tickets, ��� ���� ����� � ��������� � �������� boarding_passes ����� ������� ����� ������� 
--�� tickets ��� ������������ � boarding_passes.
--������� ����� �����, ��� ��� ������������ � ���������� �� ���, ����� ������ �����.
		
select t.book_ref
from tickets t 
left join boarding_passes bp on t.ticket_no = bp.ticket_no 
where bp.ticket_no is null
group by t.book_ref


--5. ������� ��������� ����� ��� ������� �����, �� % ��������� � ������ ���������� ���� � ��������.
--�������� ������� � ������������� ������ - ��������� ���������� ���������� ���������� ���������� �� ������� ��������� �� ������ ����. 
--�.�. � ���� ������� ������ ���������� ������������� ����� - ������� ������� ��� �������� �� ������� ��������� �� ���� ��� ����� ������ ������ �� ����.
--������� ������� ���������� ����������, ������� ������ ���������� ������ �� ����, ����� ����� ���������� ���� � ��������, ������� ������������ �����,
--��������� �������������� �������, ��������� � ��� flights, ����� �������� �������� � ����� �����������.
--������� ������ �� ��������� ������, �� ��������, � ������� ������� ��� ������� ������������ ����� �� ���������� ���������� � ������� ���� � ���������.

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

--6. ������� ���������� ����������� ��������� �� ����� ��������� �� ������ ����������. ( ���������. �������� ROUND)
--� ���������� ���������� ����� ���������� ��������� ����� ����������, � ������� flights ���������� �� ����� ��������� 
--� ������� ���������� ��������� ������ ���������, ��������� ������� aircrafts, ����� ������� �������� �������� � � ������ ����������� ���������� � ����������.

select a2.model , 
	count(f.aircraft_code) amount, 
	round((100*count(f.aircraft_code))/(select count(f.aircraft_code)::numeric from flights f),2)
from flights f
join aircrafts a2 using(aircraft_code)
group by f.aircraft_code, a2.model
order by amount desc

--7. ���� �� ������, � ������� �����  ��������� ������ - ������� �������, ��� ������-������� � ������ ��������? (CTE)
--��-������ ������� ���������� ��������� ������ � ������ ������� �� ������� ����������� �������� �� ������� ticket_flights � ���� ���������� cte. 
--��������� �� �� flight_id � ���������, ���� �� ����� ��������, ��� ������ ����� ������ ������.
--�� ������ �������� ����� �������� ������� flights � airports, ����� ������� �������� ������ �������� � �������� �������� ������ � ���������, 
--����� ������� ���������� �����, ��������������� �������.

--�������1, �������� � �������� �� ������ ���� �� ������ ����� ��������.

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

--�������2, ������� � �������� �� ������ ���� �� ������ ������.

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
	
--8. ����� ������ �������� ��� ������ ������? (��������� ������������ � ����������� FROM. �������������� ��������� �������������. �������� EXCEPT)
--������� ��� ��������� �������� � ������� ��������� ������������, � ������� ����� � ������, ��� ������ ����������� � �������� ����������, 
--������� ����������������� �������������, �.�. ������ � ��� �� ����������� � ���������� ������ �����, ����� � ������������ �������� ����� ������.
--������� � ������� ������� flights ��� ��������� ��������, ��������� � �������� airports, ����� �������� ������ ��� �� ������ ������, ��� � �� ������ �������.
--����������, ����� ������ �����, ������� ������� ������������� �� ������ ���� �������� �������� ����� �������� ����� ��� �������������� �������� - ���������� ����� �����������.
--���������� EXCEPT, ����� ������ �� ���� ��������� ��������� ��������� � �������� �� ������������ �������� ����� ��������.

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

--9. ��������� ���������� ����� �����������, ���������� ������� �������, �������� � ���������� ������������ ���������� ���������  � ���������, 
--������������� ��� ����� (�������� RADIANS ��� ������������� sind/cosd)
--������� � ������� ������� flights ��� ��������� ��������, ��������� � �������� airports, ����� �������� ������ ��� �� ��������� ������, ��� � �� ��������� �������.
--��������� � �������� aircrafts, ����� �������� ������������ ���������, �� ������� ��������� ��� ������ ��������.
--�� ������� ��������� ���������� �� ������� � ���������� ��� � ������������ ����������. ���������, ����� ������ �������� ����������� � ���� ��������� ��������.


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

