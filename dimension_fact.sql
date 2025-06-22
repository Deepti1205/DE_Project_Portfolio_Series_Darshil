create table dimdate
(
	date_key integer not null primary key,
	date date not null,
	year smallint not null,
	quarter smallint not null,
	month smallint not null,
	day smallint not null,
	week smallint not null,
	is_weekend boolean
)

select column_name,data_type from information_schema.columns where table_name = 'dimdate'

------------------------------------------------------------------------------------------
insert into dimdate(date_key,date,year,quarter,month,day,week,is_weekend)
select 
	distinct(to_char(payment_date :: date,'yyyyMMdd'):: integer)	as date_key,
	date(payment_date)                 								as date,
	extract(year from payment_date)    								as year,
	extract(quarter from payment_date) 								as quarter,
	extract(month from payment_date)   								as month,
	extract(day from payment_date)     								as day,
	extract(week from payment_date)    								as week,
	CASE
		when extract(isodow from payment_date) in (6,7) then true
		else false
	end as is_weekend		
from payment		
select * from dimdate limit 5
------------------------------------------------------------------------
select extract(isodow from payment_date) from payment  --for case when then

select payment_date :: date from payment -- shorthand for type-casting, from timestamp to date type
select to_char(payment_date :: date,'yyyyMMdd') from payment  --converting date into character
select to_char(payment_date :: date,'yyyyMMdd'):: integer from payment --typecasted from char to int
select distinct(to_char(payment_date :: date,'yyyyMMdd'):: integer) from payment --to get unique values after casting to integer
	
_________________________________________________________________________________

CREATE TABLE dimCustomer
    (
      customer_key SERIAL PRIMARY KEY,
      customer_id  smallint NOT NULL,
      first_name   varchar(45) NOT NULL,
      last_name    varchar(45) NOT NULL,
      email        varchar(50),
      address      varchar(50) NOT NULL,
      address2     varchar(50),
      district     varchar(20) NOT NULL,
      city         varchar(50) NOT NULL,
      country      varchar(50) NOT NULL,
      postal_code  varchar(10),
      phone        varchar(20) NOT NULL,
      active       smallint NOT NULL,
      create_date  timestamp NOT NULL,
      start_date   date NOT NULL,
      end_date     date NOT NULL
    );
	
------------------------------------------------------
insert into dimcustomer(customer_key, customer_id, first_name, last_name, email, address, 
                         address2, district, city, country, postal_code, phone, active, 
                          create_date,start_date, end_date)
select 
	c.customer_id as customer_key,
	c.customer_id,
	c.first_name,
	c.last_name,
	c.email,
	c.active,
	c.create_date,
	a.address,
	a.address2,
	a.district,
	a.postal_code,
	a.phone,
	ci.city,
	co.country,
	now()  as start_date,
	now()  as end_date
from customer as c 
join address as a   on c.address_id = a.address_id
join city as ci     on a.city_id = ci.city_id
join country as co  on ci.country_id = co.country_id

select * from customer limit 10
select * from dimcustomer limit 10
select * from address limit 10

___________________________________________________________________________________
CREATE TABLE dimMovie
    (
      movie_key          SERIAL PRIMARY KEY,
      film_id            smallint NOT NULL,
      title              varchar(255) NOT NULL,
      description        text,
      release_year       year,
      language           varchar(20) NOT NULL,
      original_language  varchar(20),
      rental_duration    smallint NOT NULL,
      length             smallint NOT NULL,
      rating             varchar(5) NOT NULL,
      special_features   varchar(60) NOT NULL
    );
	
INSERT INTO dimMovie (movie_key, film_id, title, description, release_year, language, original_language, rental_duration, length, rating, special_features)
SELECT 
    f.film_id as movie_key,
    f.film_id,
    f.title, 
    f.description,
    f.release_year,
    l.name as language,
    orig_lang.name AS original_language,
    f.rental_duration,
    f.length,
    f.rating,
    f.special_features
FROM film f
JOIN language l              ON (f.language_id=l.language_id)
LEFT JOIN language orig_lang ON (f.language_id = orig_lang.language_id);

select * from dimmovie limit 10

-----------------------------------------------------------------------------
CREATE TABLE dimStore
    (
      store_key           SERIAL PRIMARY KEY,
      store_id            smallint NOT NULL,
      address             varchar(50) NOT NULL,
      address2            varchar(50),
      district            varchar(20) NOT NULL,
      city                varchar(50) NOT NULL,
      country             varchar(50) NOT NULL,
      postal_code         varchar(10),
      manager_first_name  varchar(45) NOT NULL,
      manager_last_name   varchar(45) NOT NULL,
      start_date          date NOT NULL,
      end_date            date NOT NULL
    );

INSERT INTO dimStore (store_key, store_id, address, address2, district, city, country, postal_code, manager_first_name, manager_last_name, start_date, end_date)
SELECT
    s.store_id as store_key,
    s.store_id,
    a.address,
    a.address2,
    a.district,
    c.city,
    co.country,
    a.postal_code,
    st.first_name as manager_first_name,
    st.last_name  as manager_last_name,
    now() as start_date,
    now() as end_date
FROM store s
JOIN staff st     ON    (s.manager_staff_id = st.staff_id)
JOIN address a    ON    (s.address_id = a.address_id)
JOIN city c       ON    (a.city_id = c.city_id)
JOIN country co   ON    (c.country_id = co.country_id);

select * from dimstore limit 10

-----------------------------------------------------------------------------
CREATE TABLE factSales
    (
        sales_key SERIAL PRIMARY KEY,
        date_key integer REFERENCES dimDate (date_key),
        customer_key integer REFERENCES dimCustomer (customer_key),
        movie_key integer REFERENCES dimMovie (movie_key),
        store_key integer REFERENCES dimStore (store_key),
        sales_amount numeric
    );

INSERT INTO factSales (date_key, customer_key, movie_key, store_key, sales_amount)
SELECT 
        TO_CHAR(payment_date :: DATE, 'yyyyMMDD')::integer AS date_key,
        p.customer_id  as customer_key,
        i.film_id as movie_key,
        i.store_id as store_key,
        p.amount as sales_amount
FROM payment p 
JOIN rental r ON (p.rental_id = r.rental_id)
JOIN inventory i ON (r.inventory_id = i.inventory_id);

select * from factsales limit 10

------------------------------------------------------------------------
-- star schema
SELECT dimMovie.title, dimDate.month, dimCustomer.city, sum(sales_amount) as revenue
FROM factSales 
JOIN dimMovie    on (dimMovie.movie_key      = factSales.movie_key)
JOIN dimDate     on (dimDate.date_key         = factSales.date_key)
JOIN dimCustomer on (dimCustomer.customer_key = factSales.customer_key)
group by (dimMovie.title, dimDate.month, dimCustomer.city)
order by dimMovie.title, dimDate.month, dimCustomer.city, revenue desc;


-- 3nf
SELECT f.title, EXTRACT(month FROM p.payment_date) as month, ci.city, sum(p.amount) as revenue
FROM payment p
JOIN rental r    ON ( p.rental_id = r.rental_id )
JOIN inventory i ON ( r.inventory_id = i.inventory_id )
JOIN film f ON ( i.film_id = f.film_id)
JOIN customer c  ON ( p.customer_id = c.customer_id )
JOIN address a ON ( c.address_id = a.address_id )
JOIN city ci ON ( a.city_id = ci.city_id )
group by (f.title, month, ci.city)
order by f.title, month, ci.city, revenue desc;






















