create database dv;
use dv;

--imported all the files with all the necessary size set while importing to get better handling of data  

--lets check the customer master table
select * from [dbo].[RETAIL_CUSTOMER_MASTER_FINAL_NE]

--lets checK the customertransaction table
select * from [dbo].[CUSTOMER_TRANSACTION_CT_FINAL]

--Store_master
select * from [dbo].[STORE_MASTER_DUMP]

--Product Master
select top 10 * from [dbo].[RETAIL_PROD_MASTER_FINAL]



--lets start with the necessary data preprocessing before we begin building the data model

--customer master


-- age of customers
--relationship age
alter table [dbo].[RETAIL_CUSTOMER_MASTER_FINAL_NE]
add age int, relationship_age int;
--age bucket 
--AON(Age on Network)
update [dbo].[RETAIL_CUSTOMER_MASTER_FINAL_NE]
set Age = datediff(year, date_of_birth,getdate()), 
relationship_age = datediff(month, STORE_REG_DATE ,getdate());

--AGE BUCKET AND RELATIONSHIP AGE
select *,
case
	when Age >= 60 THEN 'A5.OLD-AGE'
	when Age >= 50 THEN 'A4.MID-OLD-AGE'
	when Age >= 40 THEN 'A3.MID-AGE'
	when Age >= 30 THEN 'A2.MID-YOUNG-AGE'
	ELSE 'A1.YOUNG-AGE'
	end as age_bucket,
case 
when RELATIONSHIP_AGE >= 60 THEN 'A1.5+ YEARS'
when RELATIONSHIP_AGE >= 48 THEN 'A2.4+ YEARS'
when RELATIONSHIP_AGE >= 36 THEN 'A3.3+ YEARS'
when RELATIONSHIP_AGE >= 24 THEN 'A4.2+ YEARS'
when RELATIONSHIP_AGE >= 12 THEN 'A5.1+ YEARS'
when RELATIONSHIP_AGE >= 6 THEN 'A6.6+ MONTHS'
ELSE 'A7.NEW'
end as AON
into customer_master
from [dbo].[RETAIL_CUSTOMER_MASTER_FINAL_NE];

select * from customer_master;



--Store Master
select * from store_master_dump;


--store Age
alter table store_master_dump
add store_age int;

update store_master_dump
set store_Age = datediff(year, STORE_INC_DATE,getdate());

---STORE_SIZE

select  * ,case
when STORE_SIZE_SQ_FT >= 5000 THEN 'BIG STORE'
when STORE_SIZE_SQ_FT >= 3000 THEN 'MID STORE'
ELSE 'MINI STORE' 
end as store_size,
case
when STORE_AGE > 10 THEN 'OLD-AGE'
when STORE_AGE > 5 THEN 'MID-AGE'
when STORE_AGE > 2 THEN 'GROWTH-AGE'
ELSE 'NEW-AGE'
end as Store_type
into store_master
from store_master_dump;

select * from store_master

--as we can see we have various customers from various stores and in various states for now lets only take one store

-- lets get the list of stores in Connecticut
select distinct store_id from RETAIL_CUSTOMER_MASTER_FINAL_NE where state = 'CT' 
--store_122, store_4, store_41, and store_6 and store_93 are the stores that are in Connecticut

--we are going to get store details from the customer master to transaction table only in Connecticut's Remke Markets
select a.* , b.store_id into customer_transaction_remke_ct from [dbo].[CUSTOMER_TRANSACTION_CT_FINAL] as a
inner join 
customer_master as b
on a.customer_id = b.customer_id
where b.state = 'CT' and b.store_id = 'STORE_93'


--now this is our transaction master table for the store_93
select * from customer_transaction_remke_ct


--DATAMODEL
--preparing the datamodel for store_93 (Remke Markets in Connecticut)


select a.CUSTOMER_ID, a.State as order_state, a.PROD_CAT,
a.PROD_ID, a.VISIT_YEAR, a.VISIT_MONTH, a.ORDER_QTY,
b.First_Name, b.Last_Name, b.Gender, b.E_Mail,
b.Date_of_Birth, b.AGE , b.AGE_BUCKET,b.SSN,
b.Phone_No,b.STATE_NAME, b.State, b.Zip,
b.Region, b.STORE_ID, b.STORE_REG_DATE,
b.AON,b.RELATIONSHIP_AGE, c.PRODUCT,c.CATEGORY,
c.SUB_CATEGORY, c.BRAND,c.SALE_PRICE_INR,
c.SALE_PRICE_USD, c.MARKET_PRICE,
c.MARKET_USD, c.TYPE, c.RATING, c.DESCRIPTION, c.RAND_NO, c.CAT, c.PD_ID,
c.PRICE_YEAR, c.COST_PRICE_INR, c.COST_PRICE_USD, 
d.STORE_NAME, d.PROVINCE, d.STORE_INC_DATE,
d.STORE_SIZE_SQ_FT, d.NO_OF_STAFFS,
d.STORE_SIZE, d.STORE_TYPE, d.STORE_AGE, SALES_REV  = a.order_qty*c.SALE_PRICE_USD
into datamodel
from customer_transaction_remke_ct as a 
LEFT join 
customer_master as b
on a.CUSTOMER_ID = b.CUSTOMER_ID
inner join RETAIL_PROD_MASTER_FINAL as c
on a.PROD_ID = c.prod_id and a.visit_year = c.price_year and a.prod_cat = c.cat
LEFT join store_master as d
on A.STORE_ID = d.STORE_ID;

--CHECKING THE NUMBER OF RECORDS 
select count(*) from datamodel  --6.7 Lakh records
--kpis

--PRODUCT KPI
select KPI = 'PRODUCT',PRODUCT as value, count(customer_id) as count,sum(order_qty) as total_qty,
sum(sales_rev) as total_sales,
format(sum(sales_rev)/sum(order_qty), 'n2') as sales_per_qty 
into product_kpi from datamodel group by product;
select * from product_kpi

--CATEGORY KPI
select KPI = 'CATEGORY',category as value, count(customer_id) as count,sum(order_qty) as total_qty,
sum(sales_rev) as total_sales,
format(sum(sales_rev)/sum(order_qty), 'n2') as sales_per_qty 
into category_kpi from datamodel group by category;
select * from category_kpi

--SUB_CATEGORY KPI
select KPI = 'SUB_CATEGORY',SUB_CATEGORY as value, count(customer_id) as count,sum(order_qty) as total_qty,
sum(sales_rev) as total_sales,
format(sum(sales_rev)/sum(order_qty), 'N2') as sales_per_qty
into sub_cat_kpi from datamodel group by SUB_CATEGORY;
select * from sub_cat_kpi;

select KPI = 'BRAND',brand as value, count(customer_id) as count,sum(order_qty) as total_qty,
sum(sales_rev ) as total_sales,
format(sum(sales_rev)/sum(order_qty), 'n2') as sales_per_qty 
into brand_kpi from datamodel group by brand;
select * from brand_kpi;

select KPI = 'GENDER',gender as value, count(customer_id) as count,sum(order_qty) as total_qty,
sum(sales_rev) as total_sales,
format(sum(sales_rev)/sum(order_qty), 'n2') as sales_per_qty 
into gender_kpi from datamodel group by Gender;
select * from gender_kpi;

select KPI = 'AGE_BUCKET',age_bucket as value, count(customer_id) as count,sum(order_qty) as total_qty,
sum(sales_rev) as total_sales,
format(sum(sales_rev)/sum(order_qty), 'n2') as sales_per_qty 
into age_cat_kpi from datamodel group by age_bucket;
select * from age_cat_kpi;

select KPI = 'RELATIONSHIP_AGE',relationship_age as value, count(customer_id) as count,sum(order_qty) as total_qty,
sum(sales_rev) as total_sales,
format(sum(sales_rev)/sum(order_qty), 'n2') as sales_per_qty 
into rltnshp_cat_kpi from datamodel group by relationship_age;
select * from rltnshp_cat_kpi;

--since the values in relationship_age is an integer(numeric datatype)
-- i am going to change the data type for this to varchar so that it is able to be 
-- appended to one whole KPI tabe
alter table rltnshp_cat_kpi
alter column value varchar(10)

select KPI = 'STORE_TYPE',Store_type as value, count(customer_id) as count, sum(order_qty) as total_qty,
sum(sales_rev) as total_sales,
format(sum(sales_rev )/sum(order_qty), 'n2') as sales_per_qty 
into store_type_kpi from datamodel group by store_type;
select * from store_type_kpi;

select KPI = 'STORE_NAME', STORE_NAME as value, count(customer_id) as count,sum(order_qty) as total_qty,
sum(sales_rev) as total_sales,
format(sum(sales_rev)/sum(order_qty), 'n2') as sales_per_qty 
into store_name_kpi from datamodel group by STORE_NAME;
select * from store_name_kpi;

select KPI = 'STORE_SIZE', STORE_SIZE as value, count(customer_id) as count,sum(order_qty) as total_qty,
sum(sales_rev) as total_sales,
format(sum(sales_rev)/sum(order_qty), 'n2') as sales_per_qty 
into store_size_kpi from datamodel group by STORE_SIZE;
select * from store_size_kpi;

select KPI = 'VISIT_MONTH',VISIT_MONTH as value, count(customer_id) as count,sum(order_qty) as total_qty,
sum(sales_rev ) as total_sales,
format(sum(sales_rev)/sum(order_qty), 'n2') as sales_per_qty 
into month_kpi from datamodel group by visit_month;
select * from month_kpi;

alter table month_kpi
alter column value varchar(10);

select KPI = 'VISIT_YEAR', VISIT_YEAR as value, count(customer_id) as count,sum(order_qty) as total_qty,
sum(sales_rev ) as total_sales,
format(sum(sales_rev)/sum(order_qty), 'n2') as sales_per_qty 
into year_kpi from datamodel group by VISIT_YEAR;
select * from year_kpi;

alter table year_kpi
alter column value varchar(10)

--APPENDING ALL THE SEPARATE KPIS TO ONE 
select * into KPI from [dbo].[product_kpi]
union all 
select * from [dbo].[category_kpi]
union all 
select * from [dbo].[sub_cat_kpi]
union all
select * from [dbo].[brand_kpi]
union all
select * from [dbo].[gender_kpi]
union all
select * from [dbo].[age_cat_kpi]
union all 
select * from [dbo].[rltnshp_cat_kpi]
union all 
select * from [dbo].[store_name_kpi]
union all 
select * from [dbo].[store_size_kpi]
union all 
select * from [dbo].[store_type_kpi]
union all 
select * from [dbo].[month_kpi]
union all 
select * from [dbo].[year_kpi];

select * from kpi
--exported all the kpis into an excel file named - KPI's.xlsx and then deleted the previous 
--tables as well as these KPIs to reduce storage consumption



--STEP 4
-- CUSTOMER ANALYSIS

--CUSTOMER WISE TRENDS
--1.	CUSTOMER_WISEUNIQUE COUNT OFMONTH VISITED, 
--		TOTAL_VISITS, TOTAL_SPENT, SPENT_PER_MONTH, SPENT_PER_VISITS
SELECT CUSTOMER_ID, COUNT(DISTINCT VISIT_MONTH) AS MONTHS_VISITED, 
COUNT(CUSTOMER_ID) AS TOTAL_TRIPS, SUM(SALES_REV) AS TOTAL_SPENT,
SUM(SALES_REV)/COUNT(DISTINCT VISIT_MONTH) AS SPENT_PER_MONTH, 
SUM(SALES_REV)/COUNT(CUSTOMER_ID) AS SPENT_PER_VISIT 
FROM DATAMODEL GROUP BY CUSTOMER_ID;

--YEARLY TRENDS
--2.	YEAR WISE UNIQUE COUNT OF CUSTOMERS, TOTAL_VISITS, TOTAL_SPENT,
--		SPENT_PER_MONTH, SPENT_PER_VISIT
SELECT VISIT_YEAR,
COUNT(CUSTOMER_ID) AS TOTAL_TRIPS, SUM(SALES_REV) AS TOTAL_SPENT,
SUM(SALES_REV)/COUNT(DISTINCT VISIT_MONTH) AS SPENT_PER_MONTH, 
SUM(SALES_REV)/COUNT(CUSTOMER_ID) AS SPENT_PER_VISIT 
FROM datamodel GROUP BY VISIT_YEAR;

--MONTHLY TRENDS
--3.	MONTH WISE UNIQUE COUNT OF CUSTOMERS, TOTAL_VISITS, TOTAL_SPENT,
--		SPENT_PER_MONTH, SPENT_PER_VISITS

SELECT VISIT_MONTH,
COUNT( DISTINCT CUSTOMER_ID) AS UNIQUE_CUST, COUNT(CUSTOMER_ID) AS TOTAL_TRIPS, SUM(SALES_REV) AS TOTAL_SPENT,
SUM(SALES_REV)/COUNT(DISTINCT VISIT_MONTH) AS SPENT_PER_MONTH, 
SUM(SALES_REV)/COUNT(CUSTOMER_ID) AS SPENT_PER_VISIT 
FROM DATAMODEL GROUP BY VISIT_MONTH;

--VISIT SEGMENTATION

-- VISIT_SEGMENT >= 10 ->REGULAR VISITS
-- VISIT_SEGMENT >= 8 ->SUBSEQUENT VISITS
-- VISIT_SEGMENT >= 6 ->RECURRENT VISITS
--VISIT_SEGMENT >= 2 ->NON-RECURRENT VISITS
-- VISIT_SEGMENT = 1->FIRST VISIT

alter table DATAMODEL
add  visit_segment char(20);


UPDATE datamodel
SET  DATAMODEL.visit_segment = b.segment
FROM datamodel 
INNER JOIN (select customer_id, count(distinct visit_month) as visit_month_count ,
CASE WHEN COUNT( DISTINCT visit_month) >= 10 THEN 'REGULAR VISITS'
WHEN COUNT( DISTINCT VISIT_MONTH) >= 8 THEN 'SUBSEQUENT VISITS'
WHEN COUNT( DISTINCT VISIT_MONTH) >= 6 THEN 'RECURRENT VISITS'
WHEN COUNT( DISTINCT VISIT_MONTH) >= 2 THEN 'NON RECURRENT VISITS' 
else 'FIRST VISIT' 
END AS SEGMENT from datamodel
group by customer_id) as b
on DATAMODEL.customer_id = b.customer_id;


--lets find out the total sales and average sales of each store
--FINDING OUT HOW MUCH EACH CUSTOMER HAS SPENT IN EACH STORE
select customer_id, store_id, sum(sales_rev) as total_sales into cust_segmnt from datamodel group by 
customer_id, STORE_ID;

--GETTING THE AVERAGE SPENT IN EACH STORE
select a.customer_id,a.store_id, a.total_sales, b.avg_sales from cust_segmnt as a
left join
(select store_id, avg(total_sales) as avg_sales from cust_segmnt group by store_id) as b
on a.store_id = b.store_id;

alter table cust_segmnt
add avg_sales int;

--MAPPING THIS BACK TO CUST_SEGMNT TO GET UPDATED SUBSET
update cust_segmnt
set cust_segmnt.avg_sales = b.avg_sales_store
from cust_segmnt
left join 
(select store_id, avg(total_sales) as avg_sales_store from cust_segmnt group by store_id) as b
on cust_segmnt.store_id = b.store_id


select * from cust_segmnt

--lets segment these customers into premier, power, advanced, need base

alter table cust_segmnt
add cust_segment char(15)

UPDATE cust_segmnt
SET  cust_segmnt.cust_segment = b.segment
FROM cust_segmnt 
INNER JOIN (select * , 
CASE 
when total_sales >= 1.25 * avg_sales then 'Premier' 
when total_sales >= avg_sales then 'Power'
when total_sales >= 0.5 * avg_sales then 'Advanced'
else 'Need-Base'
end as segment
from cust_segmnt ) as b
on cust_segmnt.customer_id = b.CUSTOMER_ID

-- now lets map this back to the main data
alter table DATAMODEL
add Cust_Segment char(15)


update DATAMODEL
set DATAMODEL.cust_segment = b.cust_segment
from DATAMODEL 
left join
cust_segmnt as b
on 
DATAMODEL.CUSTOMER_ID = b.customer_id

SELECT TOP 10 * FROM datamodel


--CUSTOMER TYPE
ALTER TABLE DATAMODEL
ADD CUSTOMER_TYPE VARCHAR(20)

DROP COLUMN CUSTOMER_TYPE

UPDATE datamodel
SET  DATAMODEL.CUSTOMER_TYPE = b.CUSTOMER_TYPE
FROM datamodel 
INNER JOIN (select CUSTOMER_ID , 
CASE 
WHEN VISIT_SEGMENT = 'REGULAR VISITS' AND CUST_SEGMENT = 'Premier' THEN 'A1.BONAFIED'
WHEN VISIT_SEGMENT = 'REGULAR VISITS' AND CUST_SEGMENT = 'Power' THEN 'A1.BONAFIED'
WHEN VISIT_SEGMENT = 'REGULAR VISITS' AND CUST_SEGMENT = 'Advanced' THEN 'A2.LOYAL'
WHEN VISIT_SEGMENT = 'REGULAR VISITS' AND CUST_SEGMENT = 'Need-Base' THEN 'A3.POWER'
WHEN VISIT_SEGMENT = 'SUBSEQUENT VISITS' AND CUST_SEGMENT = 'Premier' THEN 'A1.BONAFIED'
WHEN VISIT_SEGMENT = 'SUBSEQUENT VISITS' AND CUST_SEGMENT = 'Power' THEN 'A2.LOYAL'
WHEN VISIT_SEGMENT = 'SUBSEQUENT VISITS' AND CUST_SEGMENT = 'Advanced' THEN 'A3.POWER'
WHEN VISIT_SEGMENT = 'SUBSEQUENT VISITS' AND CUST_SEGMENT = 'Need-Base' THEN 'A4.ADVANCED'
WHEN VISIT_SEGMENT = 'RECURRENT VISITS' AND CUST_SEGMENT = 'Premier' THEN 'A2.LOYAL'
WHEN VISIT_SEGMENT = 'RECURRENT VISITS' AND CUST_SEGMENT = 'Power' THEN 'A3.POWER'
WHEN VISIT_SEGMENT = 'RECURRENT VISITS' AND CUST_SEGMENT = 'Advanced' THEN 'A4.ADVANCED'
WHEN VISIT_SEGMENT = 'RECURRENT VISITS' AND CUST_SEGMENT = 'Need-Base' THEN 'A5.IMPULSIVE'
WHEN VISIT_SEGMENT = 'NON RECURRENT VISITS' AND CUST_SEGMENT = 'Premier' THEN 'A3.POWER'
WHEN VISIT_SEGMENT = 'NON RECURRENT VISITS' AND CUST_SEGMENT = 'Power' THEN 'A4.ADVANCED'
WHEN VISIT_SEGMENT = 'NON RECURRENT VISITS' AND CUST_SEGMENT = 'Advanced' THEN 'A5.IMPULSIVE'
WHEN VISIT_SEGMENT = 'NON RECURRENT VISITS' AND CUST_SEGMENT = 'Need-Base' THEN 'A6.CASUAL'
WHEN VISIT_SEGMENT = 'FIRST VISIT' AND CUST_SEGMENT = 'Premier' THEN 'A4.ADVANCED'
WHEN VISIT_SEGMENT = 'FIRST VISIT' AND CUST_SEGMENT = 'Power' THEN 'A5.IMPULSIVE'
WHEN VISIT_SEGMENT = 'FIRST VISIT' AND CUST_SEGMENT = 'Advanced' THEN 'A6.CASUAL'
WHEN VISIT_SEGMENT = 'FIRST VISIT' AND CUST_SEGMENT = 'Need-Base' THEN 'A6.CASUAL'
END AS CUSTOMER_TYPE FROM DATAMODEL GROUP BY CUSTOMER_ID, visit_segment, Cust_Segment) AS B
ON DATAMODEL.CUSTOMER_ID = B.CUSTOMER_ID;

SELECT DISTINCT CUSTOMER_TYPE FROM datamodel

--CUSTOMER_TYPE TRENDS
SELECT CUSTOMER_TYPE, COUNT(DISTINCT CUSTOMER_ID) AS UNIQUE_CUST ,COUNT(CUSTOMER_ID)AS TOTAL_TRIPS, SUM(SALES_REV) AS TOTAL_SPENT,
SUM(SALES_REV)/COUNT(DISTINCT VISIT_MONTH) AS SPENT_PER_MONTH, SUM(SALES_REV)/COUNT(CUSTOMER_ID) AS SPENT_PER_VISIT
FROM DATAMODEL GROUP BY CUSTOMER_TYPE

--AGE BUCKET AND CUSTOMER_TYPE TRENDS
SELECT AGE_BUCKET, CUSTOMER_TYPE,
COUNT( DISTINCT CUSTOMER_ID) AS UNIQUE_CUST, COUNT(CUSTOMER_ID) AS TOTAL_TRIPS, SUM(SALES_REV) AS TOTAL_SPENT,
SUM(SALES_REV)/COUNT(DISTINCT VISIT_MONTH) AS SPENT_PER_MONTH, 
SUM(SALES_REV)/COUNT(CUSTOMER_ID) AS SPENT_PER_VISIT 
FROM DATAMODEL GROUP BY AGE_BUCKET, CUSTOMER_TYPE;


--CUSTOMER ANALYTICS

--BRANDS THAT CUSTOMERS BOUGHT MORE THAN 6 TIMES IN A YEAR
SELECT CUSTOMER_ID, BRAND , VISIT_YEAR , COUNT(BRAND) AS NUM_OF_ORDERS 
FROM DATAMODEL GROUP BY CUSTOMER_ID, VISIT_YEAR, BRAND
HAVING COUNT(BRAND) > 6


-- MONTH NAME WITH THE HIGHEST PURCHASE

SELECT VISIT_MONTH, VISIT_YEAR, SUM(SALES_REV) AS TOTAL_SALES, RANK() OVER(PARTITION BY VISIT_YEAR ORDER BY SUM(SALES_REV) DESC) AS RANK_NO  INTO MONTHLY_SALES 
FROM DATAMODEL GROUP BY VISIT_MONTH , VISIT_YEAR

SELECT * INTO MONTH_OF_MAX_SALES FROM MONTHLY_SALES
WHERE RANK_NO = 1

-- THESE ARE THE MONTHS WITH THE HIGHEST PURCHASE (OCTOBER IN 2020 AND JANUARY IN 2021)
SELECT * FROM MONTH_OF_MAX_SALES
-- WE CAN USE THE SAME MONTHLY SALES TABLE TO GET THE 12TH RANKING MONTH AS LOWEST SALES(AS 12 MONTHS IN YEAR) 
SELECT * INTO MONTH_OF_MIN_SALES FROM MONTHLY_SALES
WHERE RANK_NO = 12
SELECT*FROM MONTH_OF_MIN_SALES

--MONTH WISE CUSTOMER SEGMENTATION

SELECT CUSTOMER_ID, VISIT_MONTH, SUM(SALES_REV) AS TOTAL_MONTHLY_SPENT_BY_CUST 
INTO CUST_MONTHLY_SALES FROM DATAMODEL GROUP BY CUSTOMER_ID, VISIT_MONTH

ALTER TABLE CUST_MONTHLY_SALES
ADD SEGMENT CHAR(15),AVG_MONTHLY_SALES INT 

UPDATE CUST_MONTHLY_SALES
SET CUST_MONTHLY_SALES.AVG_MONTHLY_SALES = B.AVG 
FROM CUST_MONTHLY_SALES
INNER JOIN 
(SELECT VISIT_MONTH, AVG(TOTAL_MONTHLY_SPENT_BY_CUST) AS AVG FROM CUST_MONTHLY_SALES GROUP BY VISIT_MONTH) AS B
ON CUST_MONTHLY_SALES.VISIT_MONTH = B.VISIT_MONTH


--IF THE TOTAL SPENT BY THE CUSTOMER IS MORE THAN THE AVERAGE SALES IN THAT MONTH 
UPDATE CUST_MONTHLY_SALES
SET CUST_MONTHLY_SALES.SEGMENT = B.SEG 
FROM CUST_MONTHLY_SALES
INNER JOIN 
(SELECT *, CASE
WHEN TOTAL_MONTHLY_SPENT_BY_CUST > AVG_MONTHLY_SALES THEN 'PREMIER'
ELSE 'NON PREMIER'
END AS SEG FROM CUST_MONTHLY_SALES) AS B
ON CUST_MONTHLY_SALES.CUSTOMER_ID = B.CUSTOMER_ID
SELECT* FROM CUST_MONTHLY_SALES


--CUSTOMERS WHO ARE SHOWING PREMIUM BEHVIOUR MORE THAN 6 TIMES 
SELECT CUSTOMER_ID, SEGMENT, COUNT(CUSTOMER_ID) AS COUNT 
FROM CUST_MONTHLY_SALES 
WHERE SEGMENT='PREMIER' 
GROUP  BY CUSTOMER_ID, SEGMENT 
HAVING COUNT(CUSTOMER_ID) >6
ORDER BY CUSTOMER_ID

--CUSTOMERS WHO REPEATED THE SAME BRAND MORE THAN 10 TIMES IN THE LAST 12 MONTHS 
SELECT customer_ID, VISIT_YEAR, BRAND, COUNT(BRAND) AS ORDERS FROM DATAMODEL 
WHERE VISIT_YEAR = 2021
GROUP BY CUSTOMER_ID, VISIT_YEAR, BRAND
HAVING COUNT(BRAND) >10

--CUSTOMER TYPE AND AGE BUCKET WISE CUSTOMER BASE AND TOTAL SPENT 
SELECT CUSTOMER_TYPE,AGE_BUCKET , 
COUNT( DISTINCT CUSTOMER_ID) AS UNIQUE_CUST_BASE, SUM(SALES_REV) AS TOTAL_SPENT
INTO TYPE_VS_AGE_BUCKET
FROM DATAMODEL
GROUP BY CUSTOMER_TYPE, AGE_BUCKET


--CUSTOMER TYPE AND AGE BUCKET WISE CUSTOMER BASE AND TOTALSPENT IN PERCENT
--		SINCE WE DONT HAVE A DIRECT WAY OF FINDING THE COLUMN TOTAL PERCENT IN SQL
--		WE ARE GOING TO INDIRECTLY ACHIEVE IT

-- ADDING A COLUMN WITH ANY VALUE FILLING IT COMPLETELY, SO LATER WE CAN GET MANY TO ONE
--RELATIONSHIP WITH THE SUBQUERY

ALTER TABLE TYPE_VS_AGE_BUCKET
ADD PSUEDO INT
GO
UPDATE TYPE_VS_AGE_BUCKET
SET PSUEDO =1;

SELECT * FROM TYPE_VS_AGE_BUCKET

SELECT A.CUSTOMER_TYPE, A.AGE_BUCKET ,
format(cast(A.UNIQUE_CUST_BASE as float)/cast(B.TOTAL_CUST as float),'p2') AS UNIQUE_CUST_BASE_IN_PRCNT,
FORMAT(A.TOTAL_SPENT/B.TOTAL_SALES,'P2') AS TOTAL_SPENT_IN_PRCNT
FROM TYPE_VS_AGE_BUCKET AS A 
LEFT JOIN
(SELECT PSUEDO, SUM(UNIQUE_CUST_BASE) AS TOTAL_CUST,
SUM(TOTAL_SPENT) AS TOTAL_SALES
FROM TYPE_VS_AGE_BUCKET
GROUP BY PSUEDO) AS B
ON A.PSUEDO = B.PSUEDO


--PRODUCT ANALYTICS

--CATEGORY WISE UNIQUE CUSTOMER BASE, TOTAL ORDERS AND TOTAL_SALES
SELECT CATEGORY, COUNT(DISTINCT CUSTOMER_ID) AS UNQ_CUST_BASE, 
COUNT(CUSTOMER_ID) AS TOTAL_ORDERS,
SUM(SALES_REV) AS TOTAL_SALES
FROM DATAMODEL
GROUP BY CATEGORY

--CATEGORY AND BRAND WISE UNIQUE CUSTOMER BASE, TOTAL ORDERS AND TOTAL_SALES
SELECT CATEGORY, BRAND,COUNT(DISTINCT CUSTOMER_ID) AS UNQ_CUST_BASE, 
COUNT(CUSTOMER_ID) AS TOTAL_ORDERS,
SUM(SALES_REV) AS TOTAL_SALES
INTO CAT_BRAND
FROM DATAMODEL
GROUP BY CATEGORY, BRAND
SELECT* FROM CAT_BRAND


--CATEGORY WISE TOP 10 BRANDS BY SALES 
--AND MARKET SHARE IN %

SELECT A.CATEGORY, A.BRAND, A.TOTAL_SALES,
RANK() OVER( PARTITION BY A.CATEGORY ORDER BY A.TOTAL_SALES DESC) AS RANKING,
FORMAT(A.UNQ_CUST_BASE/CAST(B.TOTAL_CUST AS FLOAT) , 'P2')AS MARKET_SHARE
INTO BRANDS_RANKING_AND_MS
FROM CAT_BRAND AS A
LEFT JOIN (SELECT CATEGORY, SUM(UNQ_CUST_BASE) AS TOTAL_CUST FROM CAT_BRAND GROUP BY CATEGORY) AS B
ON A.CATEGORY = B.CATEGORY 

SELECT * INTO TOP_10_BRANDS FROM BRANDS_RANKING_AND_MS WHERE RANKING < 10

SELECT * FROM TOP_10_BRANDS

--CATEGORY, BRAND, AND PRODUCT WISE SALES
SELECT CATEGORY, BRAND, PRODUCT, SUM(SALES_REV) AS TOTAL_SALES 
INTO CAT_BRAND_PROD_SALES
FROM DATAMODEL 
GROUP BY CATEGORY, BRAND, PRODUCT
ORDER BY CATEGORY, BRAND, PRODUCT, TOTAL_SALES DESC



--PRODUCT SEGMENTS ACCORDING TO TOTAL BRAND's SALES AND AVERAGE CATEGORY SALES
SELECT A.CATEGORY,A.BRAND,A.PRODUCT,A.TOTAL_SALES AS PROD_SALES, B.BRAND_TOTAL, C.AVG_CAT_SALES
INTO PRODUCT_SEGMENT FROM CAT_BRAND_PROD_SALES AS A
LEFT JOIN
(
select BRAND, SUM(TOTAL_SALES) AS BRAND_TOTAL 
from CAT_BRAND_PROD_SALES
GROUP BY BRAND	) AS B
ON A.BRAND = B.BRAND
LEFT JOIN
(
SELECT CATEGORY, AVG(TOTAL_SALES) AS AVG_CAT_SALES
FROM CAT_BRAND_PROD_SALES 
GROUP BY CATEGORY
) AS C
ON A.CATEGORY = C.CATEGORY;

ALTER TABLE PRODUCT_SEGMENT
ADD PROD_SEGMENT CHAR(15)

SELECT* FROM PRODUCT_SEGMENT
--IF FOR THE PRODUCT THE BRAND'S TOTAL SALES IS MORE THAN 1.25 TIMES THE CATEGORY'S AVERAGE TE PRODUCT 
-- IS HI TECH, IF MORE THAN CATEGORY'S AVERAGE  
UPDATE PRODUCT_SEGMENT
SET PRODUCT_SEGMENT.PROD_SEGMENT = B.SEGMENT
FROM PRODUCT_SEGMENT
LEFT JOIN
(SELECT*, CASE
WHEN BRAND_TOTAL >= 1.25 * AVG_CAT_SALES THEN 'Hi-Tech'
WHEN BRAND_TOTAL >= AVG_CAT_SALES THEN 'Premier'
WHEN BRAND_TOTAL >= 0.5 * AVG_CAT_SALES THEN 'Power'
ELSE 'Retail' 
END AS SEGMENT FROM PRODUCT_SEGMENT ) AS B
ON PRODUCT_SEGMENT.PRODUCT = B.PRODUCT

--TOP 10 PRODUCTS BY EACH BRAND

SELECT CATEGORY, PROD_SEGMENT, BRAND, PRODUCT, PROD_SALES,
RANK() OVER (PARTITION BY BRAND ORDER BY PROD_SALES DESC) AS RANKING 
INTO TOP_PROD_BY_BRANDS
FROM PRODUCT_SEGMENT

SELECT PRODUCT,RANKING FROM TOP_PROD_BY_BRANDS
WHERE RANKING <10  ;

--TOP 10 PRODUCTS BY EACH BRAND AND THEIR CUSTOMER BASE

SELECT A.*, B.UNQ_CUST_BASE FROM TOP_PROD_BY_BRANDS AS A
INNER JOIN
(
SELECT PRODUCT, COUNT( DISTINCT CUSTOMER_ID) AS UNQ_CUST_BASE
FROM DATAMODEL
GROUP BY PRODUCT
)
AS B
ON A.PRODUCT = B.PRODUCT
WHERE RANKING < 10


--GET THE BRAND WISE PRODUCT SALES IN LAST 6MONTHS CONTIONOUSLY GROWING
--LETS SELECT THE LAST 6 MONTHS
SELECT BRAND , PRODUCT,VISIT_MONTH, SUM(SALES_REV) AS TOTAL_SALES
INTO LAST_6_M
FROM DATAMODEL 
WHERE VISIT_YEAR = 2021 AND VISIT_MONTH BETWEEN 6 AND 12
GROUP BY BRAND,PRODUCT, VISIT_MONTH

ALTER TABLE LAST_6_M
ADD BETTER_PERF_FLAG INT


--WE WILL FIRST CREATE A FLAG-VARIABLE(BETTER PERFORMANCE FLAG) WHICH INDICATES IF 
--THERE IS INCREASE IN SALES OF A PRODUCT COMPARED TO PREVIOUS MONTH 

UPDATE LAST_6_M
SET LAST_6_M.BETTER_PERF_FLAG = B.FLAG
FROM LAST_6_M
LEFT JOIN
(
SELECT * , CASE
WHEN TOTAL_SALES >LAG(TOTAL_SALES) OVER (PARTITION BY PRODUCT ORDER BY VISIT_MONTH ASC ) THEN 1
ELSE 0
END AS FLAG
FROM LAST_6_M ) AS B
ON LAST_6_M.VISIT_MONTH = B.VISIT_MONTH


--THEN WE COMPARE IF THIS FLAG APPEARS EVERY TIME (-1 SINCE FIRST RECORD WOULD ALWAYS HAVE 
--BETTER_PERFORMANCE_FLAG AS 0) FOR A PRODUCT (BY COMPARING COUNT AND SUM OF FLAG)
--THEN CHOSE ONLY THOSE VALUES WITH A POSITIVE RESPONSE TO THIS EXPRESSION
SELECT A.PRODUCT,A.TOTAL_SALES, A.VISIT_MONTH FROM LAST_6_M AS A
LEFT JOIN
( SELECT PRODUCT, SUM(BETTER_PERF_FLAG) AS SCORE, COUNT(PRODUCT) - 1 AS TOTAL,
CASE 
WHEN SUM(BETTER_PERF_FLAG) = COUNT(PRODUCT) - 1 THEN 1
ELSE 0 
END AS INC_PRODUCT_FLAG 
FROM LAST_6_M 
GROUP BY PRODUCT) AS B 
ON A.PRODUCT = B.PRODUCT
WHERE INC_PRODUCT_FLAG = 1;

--  ↑ THESE ARE THE PRODUCTS THAT CONTINOUSLY SHOWED IMPROVED SALES IN LAST 6 MONTHS ↑

--BRAND AND PRODUCTWISE AVERAGE QUANTITY SOLD IN A YEAR--
--FIRST WE WILL FIND OUT THE TOTAL PRODUCT, BRAND WISE SALES IN BOTH YEARS 

SELECT BRAND, PRODUCT, VISIT_YEAR, SUM(ORDER_QTY) AS TOTAL  
INTO PROD_QTY 
FROM datamodel
GROUP BY BRAND, PRODUCT, VISIT_YEAR

-- THEN WE WILL TAKE THE AVERAGE
SELECT PRODUCT, BRAND, AVG(TOTAL) AS AVG_QTY_SOLD_IN_A_YEAR
FROM PROD_QTY 
GROUP BY PRODUCT, BRAND


--TOP 10 SELLING PRODUCTS AND THE TOTAL NUMBER CUSTOMERS WHO BOUGHT ALL 10 PRODUCTS TOGETHER

--LETS GET THE TOTAL SALES BY THE PRODUCTS AND RANK THEM ACCORDING TO SALES
SELECT PROD_ID, PRODUCT, SUM(SALES_REV) AS TOTAL_SALES, 
RANK() OVER (ORDER BY SUM(SALES_REV) DESC) AS RANKING
INTO ALL_PRODUCTS
FROM DATAMODEL
GROUP BY PROD_ID,PRODUCT

SELECT * INTO TOP_10_PRODUCTS 
FROM ALL_PRODUCTS
WHERE RANKING <= 10
ORDER BY RANKING

--THE TOP 10 PRODUCTS
SELECT* FROM TOP_10_PRODUCTS

--CUSTOMERS WHO BOUGHT ALL THESE PRODUCTS TOGETHER
SELECT A.CUSTOMER_ID,b.PROD_ID,b.RANKING  FROM datamodel AS A
INNER JOIN
(
SELECT *  
FROM ALL_PRODUCTS
WHERE RANKING <= 10
) AS B
ON A.PROD_ID = B.PROD_ID
GROUP BY A.CUSTOMER_ID,B.PROD_ID, b.ranking
HAVING COUNT(A.PROD_ID) = 10
ORDER BY CUSTOMER_ID

--THERE ARE NO CUSTOMERS WHO BOUGHT ALL THE 10 TOP SELLING PRODUCTS TOGETHER


--								STORE PERFORMANCE ANALYTICS

--STORE'S TOTAL UNIQUE CUSTOMER BASE, TOTAL_VISITS, TOTAL_ORDERS AND TOTAL_SPENT
SELECT STORE_ID, STORE_NAME, COUNT( DISTINCT CUSTOMER_ID) AS UNQ_CUST_BASE, COUNT(CUSTOMER_ID) AS TOTAL_VISITS,
COUNT(CUSTOMER_ID) AS TOTAL_ORDERS, SUM(SALES_REV) AS TOTAL_SPENTS FROM DATAMODEL
GROUP BY STORE_ID, STORE_NAME

--STORE'S TOP SELLING CATEGORY WISE BRANDS
SELECT STORE_NAME, CATEGORY, BRAND , SUM(SALES_REV) AS TOTAL_SALES ,
RANK() OVER (PARTITION BY CATEGORY ORDER BY SUM(SALES_REV) DESC) AS RANKING
INTO STORE_BRAND_RANKING
FROM DATAMODEL
GROUP BY STORE_NAME, CATEGORY, BRAND
ORDER BY CATEGORY, RANKING

SELECT * FROM STORE_BRAND_RANKING 
WHERE RANKING = 1

--STORE AND CUSTOMER TYPE UNIQUE COUNT OF CUSTOMER BASE AND TOTAL SALES
SELECT STORE_NAME, CUSTOMER_TYPE, COUNT(DISTINCT CUSTOMER_ID)  AS UNQ_CUST_BASE,
SUM(SALES_REV) AS TOTAL_SALES 
FROM DATAMODEL
GROUP BY STORE_NAME, CUSTOMER_TYPE

--STORE, CUSTOMER TYPE AND PRODUCT SEGMENT WISE TOTAL ORDERS

--FIRST LETS MAP PROD-SEGMENT BACK TO DATAMODEL
ALTER TABLE DATAMODEL
ADD PRODUCT_SEGMENT CHAR(15), psuedo int

UPDATE DATAMODEL
SET DATAMODEL.PRODUCT_SEGMENT = B.PROD_SEGMENT, psuedo = 1
FROM DATAMODEL
LEFT JOIN
PRODUCT_SEGMENT AS B
ON DATAMODEL.PRODUCT = B.PRODUCT AND DATAMODEL.CATEGORY = B.CATEGORY AND DATAMODEL.BRAND = B.BRAND

--STORE, CUSTOMER TYPE AND PRODUCT SEGMENT WISE TOTAL ORDERS

select a.store_name, a.customer_type, a.product_segment, 
count(a.customer_id) as total_orders, 
format(count(a.customer_id)/cast(b.total_cust as float) , 'p2') as total_orders_in_per
from datamodel as a
left join
(select psuedo = 1, count(customer_id) as total_cust from datamodel  ) as b
on a.psuedo = b.psuedo
group by a.store_name, a.customer_type, a.PRODUCT_SEGMENT, b.total_cust

--STORE, CUSTOMER TYPE AND PRODUCT SEGMENT WISE TOTAL SALES

select a.store_name, a.customer_type, a.product_segment, 
sum(a.SALES_REV) as total_sales, 
format(sum(a.SALES_REV)/cast(b.total_sales as float) , 'p2') as total_sales_in_per
from datamodel as a
left join
(select psuedo = 1, sum(SALES_REV) as total_sales from datamodel  ) as b
on a.psuedo = b.psuedo
group by a.store_name, a.customer_type, a.PRODUCT_SEGMENT, b.total_sales

--STORE TYPE WISE UNIQUE CUSTOMERS, TOTAL VISITS, TOTAL ORDERS, AND TOTAL-SPENT

SELECT STORE_TYPE, COUNT(DISTINCT CUSTOMER_ID) AS UNQ_CUST , COUNT(CUSTOMER_ID) AS TOTAL_VISITS,
COUNT(CUSTOMER_ID) AS TOTAL_ORDERS, SUM( SALES_REV) AS TOTAL_SPENT
FROM DATAMODEL 
GROUP BY STORE_TYPE

-- END OF ANALYSIS