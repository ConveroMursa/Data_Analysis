
--1. Which cities have more than one airport?
--Group the airports table by cities and count the number of airports in each city
--If the number is greater than one, then output this line.

select a.city , count(a.airport_code) amount_of_airports
from airports a
group by a.city
having count(a.airport_code) > 1

--2. Which airports have flights operated by the aircraft with the longest flight distance? (- Subquery)
-- In the subquery, find the aircraft with the maximum flight distance (select max(a."range")from aircrafts a)
--In the main query, in the flights table, find unique airports where aircraft_code is in the list of aircraft selected by the subquery.

select distinct f.departure_airport 
from flights f 
where f.aircraft_code in (
	select a.aircraft_code 
	from aircrafts a
	where a."range" = (select max(a."range")
	from aircrafts a)
	)

--3. Display 10 flights with the maximum departure delay time (LIMIT Operator)
--Find the difference between the actual departure time and the planned one, and if it is actual (not null),
--then sort in descending order and find the first ten rows.

select f.flight_id, f.actual_departure, f.scheduled_departure, (f.actual_departure - f.scheduled_departure) max_del
from flights f 
where (f.actual_departure - f.scheduled_departure) is not null
order by max_del desc
limit 10

--4. Were there any bookings without received boarding passes?
--Take the tickets table where there are reservations and join it with the boarding_passes table to find out which tickets
--from tickets there is no match in boarding_passes.
--Display this bookings where there is no match and group by them to remove duplicates.
		
select t.book_ref
from tickets t 
left join boarding_passes bp on t.ticket_no = bp.ticket_no 
where bp.ticket_no is null
group by t.book_ref


--5. Find free seats for each flight, their % ratio to the total number of seats on the plane.
--Add a column with a cumulative total - the total accumulation of the number of passengers taken out of each airport for each day.
--so this column should show the cumulative amount - how many people have already departed from this airport on this or earlier flights per day.
--First, we find the number of passengers who are issued boarding passes for the flight, then the total number of seats in the aircraft that is flying,
-- join the resulting tables, add flights to them to get the airport and time of departure.
--display the calculation for free seats, their percentage, and a window function for calculating the running total for passengers taken out by date and airport.
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

--6. Find the percentage of flights by aircraft type of the total.
--In the subquery, we determine the total number of flights by all aircraft, in the flights table we group by aircraft type
--and find the number of flights by each aircraft, add the aircrafts table to display the name of the aircraft, and write calculations and rounding in the output.

select a2.model , 
	count(f.aircraft_code) amount, 
	round((100*count(f.aircraft_code))/(select count(f.aircraft_code)::numeric from flights f),2)
from flights f
join aircrafts a2 using(aircraft_code)
group by f.aircraft_code, a2.model
order by amount desc

--7. Were there cities that you can get to in business class cheaper than in economy class as part of the flight? 
--Firstly, we find the unique cost of Economy and Business classes for each unique flight from the ticket_flights table in two separate cte.
--Connect them by flight_id and check if there are such flights where the economy fare is more business.
--In the second option, we can add the flights and airports tables to display the name of the city of arrival and wrap the main query in a subquery,
--to display a unique city that matches the condition.

--Option 1 answers the question whether there were such flights.

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

-- Option 2 answers the question whether there were such cities.

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
	
--8. Between which cities there are no direct flights? 
--We display all possible routes using the Cartesian product, and remove duplicates and lines where the cities of departure and arrival are the same,
--create a materialized view, because the data in it is not operational and will change only when new cities appear in service.
--Output all available routes using the flights table, join with the airports table to get data for both the city of departure and the city of arrival.
--We group to remove duplicates, create a regular view in case new routes suddenly appear between already served cities - the information will be operational.
--Use EXCEPT to remove existing routes from all possible routes and get non-existing routes between cities.

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

--9. Calculate the distance between airports connected by direct flights, compare with the allowable maximum flight distance in aircraft,
--serving these flights.
--Retrieve all available routes using the flights table, join with the airports table to get data for both the airport of departure and the airport of arrival.
--Join with the aircrafts table to get the maximum distance that this aircraft model is designed for.
--According to the formula, we calculate the distance to cities and compare it with the maximum distance. We sort to find out the most critical routes in this regard.


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

