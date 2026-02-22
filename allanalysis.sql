----   Change over time ----------
---analyze sales perfromance over years

select 
datetrunc (month, OrderDate) Orderyear , sum (SalesAmount) totalsales,
count (distinct cust_number) Customer,
count (Quantity) TotalQuantitybymonyth
from gold.fact_sales
where Orderdate is not null 
group by datetrunc (month, OrderDate) 
order by datetrunc (month, OrderDate) 

--- HOW MANY NEW CUSTOMERS ADDED EACH YEAR
select
datetrunc(year, Orderdate) Orderyear,count (distinct (cust_number)) newCustomer
from gold.fact_sales
where Orderdate is not null 
group by datetrunc(year, Orderdate)
order by datetrunc(year, Orderdate)


--- cumulative analysis
----total sales per month

select 
sum (SalesAmount) Salesamount, DATETRUNC (MONTH, Orderdate) Month
from gold.fact_sales
where Orderdate is not null
group by DATETRUNC (MONTH, Orderdate)


--- running  total
select 
Monthofyear,
Salesamount,
sum (SalesAmount) over (order by Monthofyear ) as running_total,
avg (totalaverage) over ( order by Monthofyear ) as movingvaerage
from (
select 
sum (SalesAmount) Salesamount, DATETRUNC (YEAR, Orderdate) Monthofyear,
avg (price) totalaverage
from gold.fact_sales
where Orderdate is not null
group by DATETRUNC (year, Orderdate)
)t


--- analyse the yearly performance of products by comparing each product sales to its average sales 
----and previous year sales
with yearlyProductSales as (
select
DATETRUNC (year,s.Orderdate) Orderyear,
p.Product_name as Productname,
 sum (s.SalesAmount) SalesAmount
from gold.fact_sales s
left join gold.dim_products p
on p.Product_key=s.Product_key
where Orderdate is not null
group by p.Product_name,DATETRUNC (year,s.Orderdate) 
)
select 
Productname,Orderyear,SalesAmount,
avg (SalesAmount) over (partition by Productname) as avgSales,
SalesAmount - avg (SalesAmount) over (partition by Productname) as diff_avg,
SalesAmount - lag (SalesAmount) over (partition by Productname  order by Orderyear) as Previous_yearsales
from yearlyProductSales
order by Productname,Orderyear


----- which categories contribute to the most
with CategorySales as (
select p.Product_category Category,
sum (s.SalesAmount) totalsalesbycategory
from gold.fact_sales s left join Gold.dim_products p
on s.Product_key=p.Product_key
group by p.Product_category)
select Category, totalsalesbycategory,
sum (totalsalesbycategory) over () Totalsales,
concat (round(cast(totalsalesbycategory as float)/sum (totalsalesbycategory) over ()* 100,2), '%') as Totalpercentage
from CategorySales


---- data segmentation
-- segment products into cost ranges and see how many products fall into each category
with ProductCategory as (
select Product_key, Product_name, Product_cost,
case when Product_cost < 100 then 'Below 100'
	when Product_cost between 100 and 500 then '100 - 500'
	when Product_cost between 500 and 1000 then '500 - 1000'
	else 'above 1000'
	end  Productrange
from gold.dim_products
)
select Productrange,
count (Product_key) as totalProducts
from ProductCategory
group by Productrange
order by totalProducts desc


-----customers based on their spending behaviour into 3 segments
---- vip --> atleast 12 months of histry and spending more than 5000
----- reg---> atleast 12 months of histry and spending less than 5000
----- new ----> less thn 12 months of histry 
---- total count
with Categorize as (
    select 
        c.cust_number, 
        max(orderdate) as latestOrderdate,
        min(orderdate) as firstOrderdate,
        datediff(month, min(orderdate), max(orderdate)) as lifespan,
        sum(s.salesAmount) as Totalamount
    from gold.fact_sales s
    join gold.dim_customers c
        on s.cust_number = c.cust_number
    group by c.cust_number
)

select
    Category,
    count(cust_number) as totalCustomers
from (
    select 
        cust_number,
        case 
            when lifespan >= 12 and Totalamount > 5000 then 'VIP'
            when lifespan >= 12 and Totalamount <= 5000 then 'Regular'
            else 'New'
        end as Category
    from Categorize
) t
group by Category
order by totalCustomers desc;
