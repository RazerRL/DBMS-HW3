use hw_3;

-- Query 1: List names and sellers of products that are no longer available (quantity=0) --
select products.name as product_name, merchants.name as company
from products join sell on products.pid = sell.pid		-- Join tables
			  join merchants on sell.mid = merchants.mid
where sell.quantity_available = 0;		-- Only include produts with quantity 0

-- Query 2: List names and descriptions of products that are not sold --
select products.name as product_name, products.description
from products
where not exists (		-- Exclude products from 'sell' table
    select 1 
    from sell 
    where sell.pid = products.pid
);

-- Query 3: How many customers bought SATA drives but not any routers? --
select count(distinct pl.cid) as num_customer
from place pl join contain c1 on pl.oid = c1.oid		-- Join tables
			  join products p1 on c1.pid = p1.pid
where p1.name like '%SATA%' and pl.cid not in (		-- Filter for items with 'SATA' in the name
    select distinct pl2.cid
    from place pl2 join contain c2 on pl2.oid = c2.oid
				   join products p2 on c2.pid = p2.pid
    where p2.name like '%Router%'		-- Customers who bought routers
  );

-- Query 4: HP has a 20% sale on all its Networking products --
select merchants.name as company, products.name as product_name, sell.price as original_price, 
round(sell.price * 0.8, 2) as discount_price		-- Discounted price
from products join sell on products.pid = sell.pid		-- Join tables
			  join merchants on sell.mid = merchants.mid
where products.category = 'Networking' and merchants.name = 'HP';		-- Only networking products sold by HP

-- Query 5: What did Uriel Whitney order? --
select merchants.name as company, products.name as product_name, sell.price as price
from customers join place on customers.cid = place.cid		-- Join tables
			   join contain on place.oid = contain.oid
			   join products on contain.pid = products.pid
			   join sell on sell.pid = products.pid
			   join merchants on sell.mid = merchants.mid
where customers.fullname = 'Uriel Whitney';		-- Only for customer Uriel Whitney

-- Query 6: List the annual total sales for each company --
select merchants.name as company, year(place.order_date) as year, 
round(sum(sell.price), 2) as total_sales		-- Sum of sales
from place join contain on place.oid = contain.oid		-- Join tables
		   join products on contain.pid = products.pid
		   join sell on sell.pid = products.pid
		   join merchants on sell.mid = merchants.mid
group by merchants.name, year
order by merchants.name;

-- Query 7: Which company had the highest annual revenue and in what year? --
with annual_rev as (		-- Calculate total yearly sales per merchant
  select merchants.mid, merchants.name as company, year(place.order_date) as year, 
  round(sum(sell.price), 2) as total_sales		-- Sum of sales
  from place join contain on place.oid = contain.oid		-- Join tables
			 join products on contain.pid = products.pid
			 join sell on sell.pid = products.pid
			 join merchants on sell.mid = merchants.mid
  group by merchants.mid, merchants.name, year(place.order_date)
)
select company, year, total_sales
from annual_rev
order by total_sales desc		-- Display company with highest annual revenue
limit 1;

-- Query 8: On average, what was the cheapest shipping method used ever? --
select shipping_method, round(avg(shipping_cost), 2) as avg_cost		-- Average of shipping cost
from orders
group by shipping_method
order by avg_cost asc		-- Display cheapest method
limit 1;

-- Query 9: What is the best sold category for each company? --
select t.mid, merchants.name as company, t.category, t.total_revenue
from (		-- Compute total revenue per merchant per category
    select sell.mid, products.category, round(sum(sell.price), 2) as total_revenue
    from sell join products on sell.pid = products.pid		-- Join tables
			  join contain on products.pid = contain.pid
			  join place on place.oid = contain.oid
    group by sell.mid, products.category
) as t
join (
    select mid, max(total_revenue) as max_revenue
    from (		-- For each merchant, find the maximum revenue among categories
        select sell.mid, products.category, round(sum(sell.price), 2) as total_revenue
        from sell join products on sell.pid = products.pid		-- Join tables
				  join contain on products.pid = contain.pid
				  join place on place.oid = contain.oid
        group by sell.mid, products.category
    ) as totals
    group by mid
) as best on t.mid = best.mid and t.total_revenue = best.max_revenue
join merchants on t.mid = merchants.mid		-- Joins upper queries to return the top-selling category for each merchant
order by merchants.name;

-- Query 10: For each company find out which customers have spent the most and the least amounts --
select cs.mid, merchants.name as company, cs.cid, customers.fullname, cs.total_spent,
       case
           when cs.total_spent = max_table.max_spent then 'Top Customer'
           when cs.total_spent = min_table.min_spent then 'Lowest Customer'
       end as customer_rank		-- Labels customer as top or towest customer/spender
from (		-- Compute total spending per merchant per customer
    select merchants.mid, customers.cid, round(sum(sell.price), 2) as total_spent
    from merchants join sell on merchants.mid = sell.mid		-- Join tables
				   join products on sell.pid = products.pid
				   join contain on products.pid = contain.pid
				   join place on place.oid = contain.oid
				   join customers on place.cid = customers.cid
    group by merchants.mid, customers.cid
) as cs
join merchants on cs.mid = merchants.mid -- Join merchants and customers with customer spending subquery
join customers on cs.cid = customers.cid
join (		-- Find the maximum amount spent per merchant
    select mid, max(total_spent) as max_spent
    from (
        select merchants.mid, customers.cid, round(sum(sell.price), 2) as total_spent
        from merchants join sell on merchants.mid = sell.mid		-- Join tables
						 join products on sell.pid = products.pid
						 join contain on products.pid = contain.pid
						 join place on place.oid = contain.oid
						 join customers on place.cid = customers.cid
        group by merchants.mid, customers.cid
    ) as totals
    group by mid
) as max_table on cs.mid = max_table.mid
join (		-- Find the minimum amount spent per merchant
    select mid, min(total_spent) as min_spent
    from (
        select merchants.mid, customers.cid, round(sum(sell.price), 2) as total_spent
        from merchants join sell on merchants.mid = sell.mid		-- Join tables
						 join products on sell.pid = products.pid
						 join contain on products.pid = contain.pid
						 join place on place.oid = contain.oid
						 join customers on place.cid = customers.cid
        group by merchants.mid, customers.cid
    ) as totals
    group by mid
) as min_table on cs.mid = min_table.mid
where cs.total_spent = max_table.max_spent or cs.total_spent = min_table.min_spent
order by merchants.name, cs.total_spent desc;

