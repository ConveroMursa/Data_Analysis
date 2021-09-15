create table users(
	id varchar(100),
	role varchar(10)
	)
	
create table lesson(
	id varchar(100),
	event_id int,
	subject varchar(10)
	)
	
create table participants(
	user_id varchar(100),
	event_id varchar(10)
)

CREATE TYPE lessons.mpaa_quality AS ENUM (
	'1', '2', '3', '4', '5');

create table quality(
	lesson_id varchar(100),
	tech_quality lessons.mpaa_quality
)

--Какой из репетиторов получал самую низкую среднюю оценку качества за день и вывести эту оценку.

explain analyse
with t1 as (
	select date_trunc('day',l.scheduled_time) date_ , p.user_id tutor, 
		round(avg(q.tech_quality),2) avg_mark, 
		min(round(avg(q.tech_quality),2)) over (partition by date_trunc('day',l.scheduled_time)) min_count
	from quality q 
	join lesson l on q.lesson_id = l.id 
	join participants p on p.event_id = l.event_id 
	join users u on u.id = p.user_id 
	where p.user_id in (select id from users where "role" = ' tutor')
	group by p.user_id, date_trunc('day',l.scheduled_time) 
	order by date_trunc('day',l.scheduled_time)
)
select t1.date_, t1.tutor, t1.avg_mark
from t1
where t1.avg_mark=t1.min_count

explain analyse
with cte as(
	select date_trunc('day',l.scheduled_time) date_ , p.user_id tutor, round(avg(q.tech_quality),2) avg_mark
	from quality q 
	join lesson l on q.lesson_id = l.id 
	join participants p on p.event_id = l.event_id 
	join users u on u.id = p.user_id 
	where p.user_id in (select id from users where "role" = ' tutor')
	group by p.user_id, date_trunc('day',l.scheduled_time) 
	order by date_trunc('day',l.scheduled_time)
)
select cte.date_ , cte.tutor, tem.minmar
from cte
join (select cte.date_ date_1, min(cte.avg_mark) minmar
	  from cte
	  group by cte.date_) tem
on tem.minmar = cte.avg_mark and tem.date_1 = cte.date_
