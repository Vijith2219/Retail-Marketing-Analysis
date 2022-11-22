/* DECLARING LIBRARY  */
libname DV '/home/u62213856/DV Analytics SAS/USA Retail Marketing Project';


/* READING THE DATASETS */

proc import datafile='/home/u62213856/DV Analytics SAS/USA Retail Marketing Project/data/STORE_MASTER_DUMP.XLSX' 
out= dv.Store_master dbms=xlsx replace;
run;


proc import datafile='/home/u62213856/DV Analytics SAS/USA Retail Marketing Project/data/RETAIL_PROD_MASTER_FINAL.XLSX'
out= dv.Prod_master dbms=xlsx replace;
run;

proc import datafile='/home/u62213856/DV Analytics SAS/USA Retail Marketing Project/data/RETAIL_CUSTOMER_MASTER_FINAL.TXT'
out= dv.cust_master dbms=DLM replace;
delimiter='09'x;
run;

proc import datafile='/home/u62213856/DV Analytics SAS/USA Retail Marketing Project/data/CUSTOMER_TRANSACTION_CT_FINAL.TXT'
out= dv.trans_ct dbms=DLM replace;
delimiter=',';
run;


/* NOW WE HAVE ALL THE DATASETS LOADED INTO OUR SAS ENVIORNMENT */

/* ******************************************************************** */
/* 					DATA PREPARATION AND CLEANING 						*/
/* ******************************************************************** */

/* -------------------------------------------------------------------- */
/*		 					CUSTOMER MASTER								*/
/* -------------------------------------------------------------------- */

/* GETTING AGE OF THE CUSTOMER */
DATA DV.CUST_MASTER;
length age_bucket $20. aon $20.;
SET DV.CUST_MASTER;
CUSTOMER_AGE = INTCK('YEAR', DATE_OF_BIRTH, TODAY());
/* AGE BUCKET */
IF CUSTOMER_AGE >= 60 THEN CUSTOMER_TYPE = AGE_BUCKET='A5.OLD-AGE';
ELSE IF CUSTOMER_AGE >= 50 THEN CUSTOMER_TYPE = AGE_BUCKET='A4.MID-OLD-AGE';
ELSE IF CUSTOMER_AGE >= 40 THEN CUSTOMER_TYPE = AGE_BUCKET='A3.MID-AGE';
ELSE IF CUSTOMER_AGE >= 30 THEN CUSTOMER_TYPE = AGE_BUCKET='A2.MID-YOUNG-AGE';
ELSE AGE_BUCKET=' A1.YOUNG-AGE' ;
/* GETTING RELATIONSHIP AGE OF THE CUSTOMER */
RELATIONSHIP_AGE = INTCK('MONTH', STORE_REG_DATE, TODAY());
/*  AON (Age On network */
IF RELATIONSHIP_AGE >= 60 THEN CUSTOMER_TYPE = AON='A1.5+ YEARS';
ELSE IF RELATIONSHIP_AGE >= 48 THEN CUSTOMER_TYPE = AON='A2.4+ YEARS';
ELSE IF RELATIONSHIP_AGE >= 36 THEN CUSTOMER_TYPE = AON='A3.3+ YEARS';
ELSE IF RELATIONSHIP_AGE >= 24 THEN CUSTOMER_TYPE = AON='A4.2+ YEARS';
ELSE IF RELATIONSHIP_AGE >= 12 THEN CUSTOMER_TYPE = AON='A5.1+ YEARS';
ELSE IF RELATIONSHIP_AGE >= 6 THEN CUSTOMER_TYPE = AON='A6.6+ MONTHS ';
ELSE AON='A7.NEW';
RUN;

/* -------------------------------------------------------------------- */
/*		 					STORE MASTER								*/
/* -------------------------------------------------------------------- */

DATA DV.STORE_MASTER;
length store_size $15. store_type $15.;
SET DV.STORE_MASTER;
/* STORE_SIZE */
IF STORE_SIZE_SQ_FT >= 5000 THEN CUSTOMER_TYPE = STORE_SIZE='BIG STORE';
ELSE IF STORE_SIZE_SQ_FT >= 3000 THEN CUSTOMER_TYPE = STORE_SIZE='MID STORE';
ELSE STORE_SIZE='MINI STORE';
STORE_AGE = INTCK('YEAR', STORE_INC_DATE, TODAY());
IF STORE_AGE > 10 THEN CUSTOMER_TYPE = STORE_TYPE='OLD-AGE';
ELSE IF STORE_AGE > 5 THEN CUSTOMER_TYPE = STORE_TYPE='MID-AGE';
ELSE IF STORE_AGE > 2 THEN CUSTOMER_TYPE = STORE_TYPE='GROWTH-AGE';
ELSE STORE_TYPE='NEW-AGE';
RUN;

/* -------------------------------------------------------------------- */
/*		 					TRANSACTION MASTER							*/
/* -------------------------------------------------------------------- */

/* LETS CHECK THE STORES IN CONNECTICUT */
PROC SQL;
select distinct store_id from 
DV.CUST_MASTER where state = 'CT' ;
QUIT;

/* 
STORE_122 
STORE_4
STORE_41
STORE_6
STORE_93 
THESE ARE THE STORES THAT ARE IN THE STATE CONNECTICUT, SO WE WILL SELECT
ONE FROM THIS-- STORE_93
*/

/* WE ARE GOING TO RETRIEVE THE TRANSACTION DATA OF THOSE STORES ONLY. */

/* SO FOR THAT LETS GET THE STORE DETAILS FROM CUSTOMER MASTER INTO THE TRANSACTION TABLE */

PROC SORT DATA=DV.cust_master;
BY CUSTOMER_ID;
RUN;

DATA DV.TRANSACTION_MASTER;
MERGE DV.TRANS_CT(IN=A) DV.CUST_MASTER(IN=B KEEP=CUSTOMER_ID STORE_ID);
BY CUSTOMER_ID;
IF A AND B;
RUN;

/* 
 WE GOT TRANSACTION DATA FOR ALL THE STORES IN THE WHOLE STATE 
 LETS FILTER IT OUT BASED ON OUR STORE
 */

DATA DV.TRANSACTION_MASTER;
SET DV.TRANSACTION_MASTER;
WHERE STORE_ID = 'STORE_93';
RUN;

/* NOW WE HAVE OUR TRANSACTION DATA FULLY PREPARED FOR THE STORE 93 (REMKE'S MARKET) */
PROC PRINT DATA= DV.TRANSACTION_MASTER (OBS=100);
RUN;

/* ************************************************************* */
/*					 DESGINING THE DATA MODEL					 */
/* ************************************************************* */

/* getting the customer data only for store_93 */
data dv.cust_master;
set dv.cust_master;
where state = 'CT' and store_id = 'STORE_93';
run;
/* getting transaction data for year 2020 */
data dv.transaction_master;
set dv.transaction_master;
where visit_year = 2020;
run;

PROC DELETE data=DV.DATAMODEL;
RUN; 

proc sort data=dv.prod_master;
by prod_id;
run;
proc sort data= dv.store_master;
by store_id;
proc sort data=dv.transaction_master;
by customer_id;

/* since customer master was already sorted. no need for that */

PROC SQL;
CREATE TABLE DV.DATAMODEL AS
SELECT A.*,B.*,C.*,D.* FROM DV.TRANSACTION_MASTER AS A 
LEFT JOIN
DV.CUST_MASTER AS B
ON A.CUSTOMER_ID = B.CUSTOMER_ID
left join
dv.prod_master as C
on a.prod_id = C.prod_id AND A.PROD_CAT = C.CAT AND A.VISIT_YEAR = C.PRICE_YEAR
left join dv.store_master as d
on A.store_id = d.store_id;
QUIT;

DATA DV.DATAMODEL(DROP= SALES_PRICE_INR MARKET_PRICE RATING DESCRPITION RAND_NO PD_ID COST_PRICE_INR CNT);
SET DV.DATAMODEL;
SALES_REV = SALE_PRICE_USD * ORDER_QTY;
RUN;

/* WE NOW HAVE ALL THE DATA WE NEED */

/* ******************************************************************** */
/* 							CUSTOMER ANALYTICS 							*/
/* ******************************************************************** */

/*  CUSTOMER WISE UNIQUE COUNT OF MONTHS VISITED CUSTOMERS, TOTAL VISITS , TOTAL ORDERS
SPENT PER MONTH, SPENT_PER_VIST */

PROC SQL;
SELECT CUSTOMER_ID, COUNT(DISTINCT VISIT_MONTH) AS MONTHS_VISITED, 
COUNT(CUSTOMER_ID) AS TOTAL_TRIPS, SUM(SALES_REV) AS TOTAL_SPENT,
SUM(ORDER_QTY) AS TOTAL_ORDERS,
SUM(SALES_REV)/COUNT(DISTINCT VISIT_MONTH) AS SPENT_PER_MONTH, 
SUM(SALES_REV)/COUNT(CUSTOMER_ID) AS SPENT_PER_VISIT 
FROM DV.DATAMODEL GROUP BY CUSTOMER_ID;
QUIT;

/* 2.	YEAR WISE UNIQUE COUNT OF CUSTOMERS, TOTAL_VISITS, TOTAL_SPENT, 
SPENT_PER_MONTH, SPENT_PER_VISIT */

PROC SQL;
SELECT VISIT_YEAR,
COUNT(CUSTOMER_ID) AS TOTAL_TRIPS, SUM(SALES_REV) AS TOTAL_SPENT,
SUM(SALES_REV)/COUNT(DISTINCT VISIT_MONTH) AS SPENT_PER_MONTH, 
SUM(SALES_REV)/COUNT(CUSTOMER_ID) AS SPENT_PER_VISIT 
FROM DV.DATAMODEL GROUP BY VISIT_YEAR;
QUIT;

/* 3.	MONTH WISE UNIQUE COUNT OF CUSTOMERS, TOTAL_VISITS, TOTAL_SPENT
, SPENT_PER_MONTH, SPENT_PER_VISITS */

PROC SQL;
SELECT VISIT_MONTH,
COUNT( DISTINCT CUSTOMER_ID) AS UNIQUE_CUST, COUNT(CUSTOMER_ID) AS TOTAL_TRIPS, SUM(SALES_REV) AS TOTAL_SPENT,
SUM(SALES_REV)/COUNT(DISTINCT VISIT_MONTH) AS SPENT_PER_MONTH, 
SUM(SALES_REV)/COUNT(CUSTOMER_ID) AS SPENT_PER_VISIT 
FROM DV.DATAMODEL GROUP BY VISIT_MONTH;
QUIT;

/* VISIT SEGMENTATION */

/* --VISIT_SEGMENT >= 10 ->REGULAR VISITS 
--VISIT_SEGMENT >= 8 ->SUBSEQUENT VISITS
--VISIT_SEGMENT >= 6 ->RECURRENT VISITS
--VISIT_SEGMENT >= 2 ->NON-RECURRENT VISITS
--VISIT_SEGMENT = 1->FIRST VISIT */

/* FIRST WE WILL FIND OUT HOW MANY MANY VISIT DOES EACH CUSTOMER HAVE THEN WE WILL SEGMENT IT */
PROC SQL;
CREATE TABLE DV.ANALYSIS AS
SELECT CUSTOMER_ID, COUNT(DISTINCT VISIT_MONTH) as VISIT_MONTH_COUNT ,
CASE 
WHEN COUNT( DISTINCT VISIT_MONTH) >= 10 THEN 'REGULAR VISITS'
WHEN COUNT( DISTINCT VISIT_MONTH) >= 8 THEN 'SUBSEQUENT VISITS'
WHEN COUNT( DISTINCT VISIT_MONTH) >= 6 THEN 'RECURRENT VISITS'
WHEN COUNT( DISTINCT VISIT_MONTH) >= 2 THEN 'NON RECURRENT VISITS' 
ELSE 'FIRST VISIT' 
END AS VISIT_SEGMENT from DV.DATAMODEL
GROUP BY CUSTOMER_ID;
QUIT;

/* THEN CUSTOMER_TYPE = WE WILL SORT THE DATAMODEL ACCORDING TO CUSTOMER_ID*/
PROC SORT DATA=DV.DATAMODEL;
BY CUSTOMER_ID;
RUN;

/* NOW WE WILL MAP THIS BACK TO DATAMODEL TO USE THIS INFO FURTHER AHEAD IN THE ANALYSIS */
/* SINCE THIS WILL BE A MANY TO ONE RELATIONSHIP WE CANT USE MERGE STATEMENT  */

DATA DV.DATAMODEL;
LENGTH VISIT_SEGMENT $25.;
SET DV.DATAMODEL;
VISIT_SEGMENT = '';
RUN;

PROC SQL;
UPDATE DV.DATAMODEL AS A 
SET VISIT_SEGMENT = 
(SELECT VISIT_SEGMENT FROM DV.ANALYSIS AS B
WHERE A.CUSTOMER_ID = B.CUSTOMER_ID);
QUIT;


/* CUSTOMER SEGMENTATION */


/* If the customer's total spent is 125% or more , than store's avg sales then the customer is a 'Premier' Customer 

If the customer's total spent is more than or equal to store's average sales then 'Power' Customer

If the customer's total spent is more than or equal to 50 % store's average sales then 'Advanced' Customer

else If the total spent is less than 50% if store's average sales then 'Need Base' Customer */


/* First, let's find the total spent by each customer in the store*/

proc sql;
create table dv.cust_sales as 
select customer_id, store_id, sum(sales_rev) as total_sales from dv.datamodel group by 
customer_id, STORE_ID;
quit;

/* Now let's find how much each customer has spent on average in the store(store average) */

proc sql;
create table dv.cust_segment as
select a.customer_id,a.store_id, a.total_sales, b.avg_sales from dv.cust_sales as a
left join
(select store_id, avg(total_sales) as avg_sales from dv.cust_sales group by store_id) as b
on a.store_id = b.store_id;
quit;

/* Now we can easily segment these values */

data dv.cust_segment;
format customer_segment $10. ;
set dv.cust_segment;
if total_sales >= 1.25*avg_sales then CUSTOMER_SEGMENT = 'Premier';
else if total_sales >= avg_sales then customer_segment = 'Power';
else if total_sales >= 0.5 * avg_sales then customer_segment = 'Advanced';
else customer_segment = 'Need Base';
run;

proc sort data = dv.cust_segment;
by customer_id;
run;

/* also lets map them back to the datamodel */

DATA DV.DATAMODEL;
LENGTH CUSTOMER_SEGMENT $10.;
SET DV.DATAMODEL;
CUSTOMER_SEGMENT = '';
RUN;

PROC SQL;
UPDATE DV.DATAMODEL AS A 
SET CUSTOMER_SEGMENT = 
(SELECT CUSTOMER_SEGMENT FROM DV.CUST_SEGMENT AS B
WHERE A.CUSTOMER_ID = B.CUSTOMER_ID);
QUIT;

/* Customer Type */
/* Each cross product from visit segments and customer segments are used to define 6 different customer types */
/*  
-A1.BONAFIED 
-A2.LOYAL
-A3.POWER
-A4.ADVANCED
-A5.IMPULSIVE
-A6.CASUAL*/


DATA DV.DATAMODEL;
LENGTH CUSTOMER_TYPE $25.;
SET DV.DATAMODEL;
IF VISIT_SEGMENT = 'REGULAR VISITS' AND CUSTOMER_SEGMENT = 'Premier' THEN CUSTOMER_TYPE = 'A1.BONAFIED';
ELSE IF VISIT_SEGMENT = 'REGULAR VISITS' AND CUSTOMER_SEGMENT = 'Power' THEN CUSTOMER_TYPE = 'A1.BONAFIED';
ELSE IF VISIT_SEGMENT = 'REGULAR VISITS' AND CUSTOMER_SEGMENT = 'Advanced' THEN CUSTOMER_TYPE = 'A2.LOYAL';
ELSE IF VISIT_SEGMENT = 'REGULAR VISITS' AND CUSTOMER_SEGMENT = 'Need Base' THEN CUSTOMER_TYPE = 'A3.POWER';
ELSE IF VISIT_SEGMENT = 'SUBSEQUENT VISITS' AND CUSTOMER_SEGMENT = 'Premier' THEN CUSTOMER_TYPE = 'A1.BONAFIED';
ELSE IF VISIT_SEGMENT = 'SUBSEQUENT VISITS' AND CUSTOMER_SEGMENT = 'Power' THEN CUSTOMER_TYPE = 'A2.LOYAL';
ELSE IF VISIT_SEGMENT = 'SUBSEQUENT VISITS' AND CUSTOMER_SEGMENT = 'Advanced' THEN CUSTOMER_TYPE = 'A3.POWER';
ELSE IF VISIT_SEGMENT = 'SUBSEQUENT VISITS' AND CUSTOMER_SEGMENT = 'Need Base' THEN CUSTOMER_TYPE = 'A4.ADVANCED';
ELSE IF VISIT_SEGMENT = 'RECURRENT VISITS' AND CUSTOMER_SEGMENT = 'Premier' THEN CUSTOMER_TYPE = 'A2.LOYAL';
ELSE IF VISIT_SEGMENT = 'RECURRENT VISITS' AND CUSTOMER_SEGMENT = 'Power' THEN CUSTOMER_TYPE = 'A3.POWER';
ELSE IF VISIT_SEGMENT = 'RECURRENT VISITS' AND CUSTOMER_SEGMENT = 'Advanced' THEN CUSTOMER_TYPE = 'A4.ADVANCED';
ELSE IF VISIT_SEGMENT = 'RECURRENT VISITS' AND CUSTOMER_SEGMENT = 'Need Base' THEN CUSTOMER_TYPE = 'A5.IMPULSIVE';
ELSE IF VISIT_SEGMENT = 'NON RECURRENT VISITS' AND CUSTOMER_SEGMENT = 'Premier' THEN CUSTOMER_TYPE = 'A3.POWER';
ELSE IF VISIT_SEGMENT = 'NON RECURRENT VISITS' AND CUSTOMER_SEGMENT = 'Power' THEN CUSTOMER_TYPE = 'A4.ADVANCED';
ELSE IF VISIT_SEGMENT = 'NON RECURRENT VISITS' AND CUSTOMER_SEGMENT = 'Advanced' THEN CUSTOMER_TYPE = 'A5.IMPULSIVE';
ELSE IF VISIT_SEGMENT = 'NON RECURRENT VISITS' AND CUSTOMER_SEGMENT = 'Need Base' THEN CUSTOMER_TYPE = 'A6.CASUAL';
ELSE IF VISIT_SEGMENT = 'FIRST VISIT' AND CUSTOMER_SEGMENT = 'Premier' THEN CUSTOMER_TYPE = 'A4.ADVANCED';
ELSE IF VISIT_SEGMENT = 'FIRST VISIT' AND CUSTOMER_SEGMENT = 'Power' THEN CUSTOMER_TYPE = 'A5.IMPULSIVE';
ELSE IF VISIT_SEGMENT = 'FIRST VISIT' AND CUSTOMER_SEGMENT = 'Advanced' THEN CUSTOMER_TYPE = 'A6.CASUAL';
ELSE IF VISIT_SEGMENT = 'FIRST VISIT' AND CUSTOMER_SEGMENT = 'Need Base' THEN CUSTOMER_TYPE = 'A6.CASUAL';
RUN;

/* Customer type wise Unique customers, Total Visits, total Spent, Spent per Month and spent per visit. */

PROC SQL;
SELECT CUSTOMER_TYPE, COUNT(DISTINCT CUSTOMER_ID) AS UNIQUE_CUST_COUNT ,COUNT(CUSTOMER_ID)AS TOTAL_TRIPS, SUM(SALES_REV) AS TOTAL_SPENT,
SUM(SALES_REV)/COUNT(DISTINCT VISIT_MONTH) AS SPENT_PER_MONTH, SUM(SALES_REV)/COUNT(CUSTOMER_ID) AS SPENT_PER_VISIT
FROM DV.DATAMODEL GROUP BY CUSTOMER_TYPE;
QUIT;

/* Age bucket and Customer type wise Unique customers, Total Visits, total Spent, Spent per Month and spent per visit. */

PROC SQL;
SELECT AGE_BUCKET, CUSTOMER_TYPE,
COUNT( DISTINCT CUSTOMER_ID) AS UNIQUE_CUST, COUNT(CUSTOMER_ID) AS TOTAL_TRIPS, SUM(SALES_REV) AS TOTAL_SPENT,
SUM(SALES_REV)/COUNT(DISTINCT VISIT_MONTH) AS SPENT_PER_MONTH, 
SUM(SALES_REV)/COUNT(CUSTOMER_ID) AS SPENT_PER_VISIT 
FROM DV.DATAMODEL GROUP BY AGE_BUCKET, CUSTOMER_TYPE;
QUIT;

/* The customers who bought the same brand for more than 6 times in a year */

PROC SQL;
SELECT CUSTOMER_ID, BRAND , VISIT_YEAR , COUNT(BRAND) AS NUM_OF_ORDERS 
FROM DV.DATAMODEL GROUP BY CUSTOMER_ID, VISIT_YEAR, BRAND
HAVING COUNT(BRAND) > 6;
QUIT;

/* Each Month wise which customer did the highest purchase */
PROC SQL;
CREATE TABLE DV.ANALYSIS AS
SELECT CUSTOMER_ID, VISIT_MONTH, VISIT_YEAR, SUM(SALES_REV) AS TOTAL_SALES 
FROM DV.DATAMODEL GROUP BY CUSTOMER_ID, VISIT_MONTH , VISIT_YEAR;
QUIT;

PROC SORT DATA = DV.ANALYSIS;
BY CUSTOMER_ID DESCENDING TOTAL_SALES ;
RUN;

PROC RANK  data=DV.ANALYSIS OUT = DV.ANALYSIS DESCENDING;
VAR TOTAL_SALES;
RANKS RANKING;
BY CUSTOMER_ID;
RUN;

/* CUSTOMER WISE TOP SPENDING MONTH  */
DATA DV.ANALYSIS;
SET DV.ANALYSIS;
WHERE RANKING = 1;
RUN;

/* CUSTOMER WISE LEAST SPENDING MONTH */
DATA DV.ANALYSIS;
SET DV.ANALYSIS;
BY CUSTOMER_ID;
IF LAST.CUSTOMER_ID;
RUN;

/*  MONTH WISE CUSTOMER SEGMENTATION */
/* IF CUSTOMER'S SPENT FOR THE MONTH
 IS ABOVE AVG SALES OF THE MONTH THEN PREMIER ELSE NON PREMIER  */

/* FIRST WE WILL CREATE A SUMMARY TABLE FOR EACH CUSTOMER WISE MONTHLY SPENT */
PROC SQL;
CREATE TABLE DV.MONTHLY_SALES AS
SELECT CUSTOMER_ID, VISIT_MONTH, SUM(SALES_REV) AS TOTAL_MONTHLY_SPENT_BY_CUST 
FROM DV.DATAMODEL GROUP BY CUSTOMER_ID, VISIT_MONTH;
QUIT;

/* THEN WE WILLFIND HOW MUCH EACH CUSTOMER ON AN AVERAGE SPENT IN THAT MONTH */
PROC SQL;
CREATE TABLE DV.ANALYSIS AS 
SELECT VISIT_MONTH, AVG(TOTAL_MONTHLY_SPENT_BY_CUST) AS AVERAGE FROM DV.MONTHLY_SALES
GROUP BY VISIT_MONTH;
RUN;

/* THEN WE WILL JOIN THESE VALUES TO COMPARE */
PROC SQL;
CREATE TABLE DV.MONTHLY_SALES AS
SELECT A.*, B.AVERAGE FROM DV.MONTHLY_SALES AS A 
LEFT JOIN DV.ANALYSIS AS B
ON A.VISIT_MONTH = B.VISIT_MONTH;
QUIT;

/* THEN WE WILL COMPARE AND ASSIGN VALUES */
DATA DV.MONTHLY_SALES ;
SET DV.MONTHLY_SALES ;
IF TOTAL_MONTHLY_SPENT_BY_CUST > AVERAGE THEN SEGMENT = 'Premier';
ELSE SEGMENT = 'Non Premier';
RUN;


/* CUSTOMERS WHO ARE SHOWING PREMIUM BEHVIOUR MORE THAN 6 TIMES  */
PROC SQL;
SELECT CUSTOMER_ID, SEGMENT, COUNT(CUSTOMER_ID) AS COUNT 
FROM DV.MONTHLY_SALES 
WHERE SEGMENT='Premier' 
GROUP BY CUSTOMER_ID, SEGMENT 
HAVING COUNT > 6;
QUIT;

/* CUSTOMERS WHO REPEATED THE SAME BRAND MORE THAN 10 TIMES IN THE LAST 12 MONTHS  */

PROC SQL;
SELECT CUSTOMER_ID, VISIT_YEAR, BRAND, COUNT(BRAND) AS ORDERS FROM DV.DATAMODEL 
GROUP BY CUSTOMER_ID, VISIT_YEAR, BRAND
HAVING COUNT(BRAND) >10;
QUIT;


/* CUSTOMER TYPE AND AGE BUCKET WISE CUSTOMER BASE AND TOTAL SPENT  */
PROC SQL;
CREATE TABLE DV.TYPE_VS_AGE_BUCKET AS
SELECT CUSTOMER_TYPE,AGE_BUCKET , 
COUNT( DISTINCT CUSTOMER_ID) AS UNIQUE_CUST_BASE, SUM(SALES_REV) AS TOTAL_SPENT
FROM DV.DATAMODEL
GROUP BY CUSTOMER_TYPE, AGE_BUCKET;
QUIT;


/* CUSTOMER TYPE AND AGE BUCKET WISE CUSTOMER BASE AND TOTALSPENT IN PERCENT */
/* ASSIGNING A NEW VARIABLE CALLED KEY WITH VALUE 1(OR ANYTHING ELSE) TO GET  MANY TO ONE RELATION*/
DATA DV.TYPE_VS_AGE_BUCKET;
SET DV.TYPE_VS_AGE_BUCKET;
KEY = 1;
RUN;

/* USING THIS TABLE/DATAMODEL WE FIND TOTAL CUSTOMERS AND TOTAL SALES */
PROC SQL;
CREATE TABLE DV.ANALYSIS AS 
SELECT KEY, SUM(UNIQUE_CUST_BASE) AS TOTAL_CUST, SUM(TOTAL_SPENT) AS TOTAL_SALES FROM 
DV.TYPE_VS_AGE_BUCKET GROUP BY KEY;
QUIT;

/* THEN WE DIVIDE THE INDIVIDUAL SALES AND CUSTOMER BASE BY THE TOTAL */
PROC SQL;
CREATE TABLE DV.TYPE_VS_AGE_BUCKET AS 
SELECT A.CUSTOMER_TYPE, A.AGE_BUCKET, (A.UNIQUE_CUST_BASE/B.TOTAL_CUST) AS UNQ_CUST_BASE,
(A.TOTAL_SPENT/B.TOTAL_SALES) AS TOTAL_SALES_PER FROM DV.TYPE_VS_AGE_BUCKET AS A
LEFT JOIN DV.ANALYSIS AS B
ON A.KEY = B.KEY;
QUIT;
/* THEN CONVERT INTO PERCENTAGE FORMAT */
DATA DV.TYPE_VS_AGE_BUCKET;
SET DV.type_vs_age_bucket;
FORMAT UNQ_CUST_BASE PERCENT5. TOTAL_SALES_PER PERCENT5.;
RUN;



/* ******************************************************************** */
/* 							PRODUCT ANALYTICS 							*/
/* ******************************************************************** */



/* CATEGORY WISE UNIQUE CUSTOMER BASE, TOTAL ORDERS AND TOTAL_SALES */
PROC SQL;
SELECT CATEGORY, COUNT(DISTINCT CUSTOMER_ID) AS UNQ_CUST_BASE, 
COUNT(CUSTOMER_ID) AS TOTAL_ORDERS,
SUM(SALES_REV) AS TOTAL_SALES
FROM DV.DATAMODEL
GROUP BY CATEGORY;
QUIT;



/* CATEGORY AND BRAND WISE UNIQUE CUSTOMER BASE, TOTAL ORDERS AND TOTAL_SALES */
PROC SQL;
CREATE TABLE DV.CAT_BRAND AS 
SELECT CATEGORY, BRAND,COUNT(DISTINCT CUSTOMER_ID) AS UNQ_CUST_BASE, 
SUM(ORDER_QTY) AS TOTAL_ORDERS,
SUM(SALES_REV) AS TOTAL_SALES
FROM DV.DATAMODEL
GROUP BY CATEGORY, BRAND;
QUIT;


/* CATEGORY WISE TOP 10 BRANDS BY SALES AND MARKET SHARE IN % */

/* FIRST WE WILL FIND OUT EACH CATEGORY AND BRAND WISE TOTAL SALES AND EACH BRAND MARKET SHARE */
PROC SQL;
SELECT A.CATEGORY, A.BRAND, A.TOTAL_SALES,
(A.UNQ_CUST_BASE/B.TOTAL_CUST) AS MARKET_SHARE
FROM DV.CAT_BRAND AS A
LEFT JOIN (SELECT CATEGORY, SUM(UNQ_CUST_BASE) AS TOTAL_CUST FROM DV.CAT_BRAND GROUP BY CATEGORY) AS B
ON A.CATEGORY = B.CATEGORY ;
QUIT;

/* THEN WE WILL RANK THEM BASED ON SALES */
PROC RANK DATA=DV.CAT_BRAND OUT = DV.CAT_BRAND DESCENDING;
VAR TOTAL_SALES;
BY CATEGORY;
RANKS RANKING;
RUN;

/* NOW ONLY THE TOP TEN BRANDS AND THEIR MARKET SHARES */
DATA DV.CAT_BRAND;
SET DV.CAT_BRAND;
WHERE RANKING < 10;
RUN;


/* CATEGORY, BRAND, AND PRODUCT WISE SALES */

PROC SQL;
CREATE TABLE DV.CAT_BRAND_PROD_SALES AS
SELECT CATEGORY, BRAND, PRODUCT, SUM(SALES_REV) AS TOTAL_SALES 
FROM DV.DATAMODEL 
GROUP BY CATEGORY, BRAND, PRODUCT;
QUIT;

PROC SORT DATA=DV.CAT_BRAND_PROD_SALES;
BY CATEGORY BRAND DESCENDING TOTAL_SALES;
RUN;


/* PRODUCT SEGMENTS ACCORDING TO TOTAL BRAND's SALES AND AVERAGE CATEGORY SALES */

/* FIRST WE WILL FIND EACH CATEGORY WISE BRAND SALES. AND AVERAGE CATEGORY SALES */
PROC SQL;
CREATE TABLE DV.PRODUCT_SEGMENT AS
SELECT A.CATEGORY,A.BRAND,A.PRODUCT,A.TOTAL_SALES AS PROD_SALES, B.BRAND_TOTAL, C.AVG_CAT_SALES
FROM DV.CAT_BRAND_PROD_SALES AS A
LEFT JOIN
(
SELECT BRAND, SUM(TOTAL_SALES) AS BRAND_TOTAL 
FROM DV.CAT_BRAND_PROD_SALES
GROUP BY BRAND	) AS B
ON A.BRAND = B.BRAND
LEFT JOIN
(
SELECT CATEGORY, AVG(TOTAL_SALES) AS AVG_CAT_SALES
FROM DV.CAT_BRAND_PROD_SALES 
GROUP BY CATEGORY
) AS C
ON A.CATEGORY = C.CATEGORY;
QUIT;


/* THEN WE WILL SEGMENT THE PRODUCTS BASED ON THE CRITERIA */
/* IF THE BRAND SALES IS MORE THAN 125% OF THE AVERAGE SALES OF CATEGORY PRODUCT IS 'HI TECH'
OR IF BRAND SALES IS MORE THAN AVERAGE SALES THEN 'PREMIER', IF MORE THAN 50% THEN POWER ELSE 'RETAIL'*/
DATA DV.PRODUCT_SEGMENT;
LENGTH PRODUCT_SEGMENT $15.;
SET DV.PRODUCT_SEGMENT;
IF  BRAND_TOTAL >= 1.25 * AVG_CAT_SALES THEN PRODUCT_SEGMENT = 'Hi-Tech';
ELSE IF BRAND_TOTAL >= AVG_CAT_SALES THEN PRODUCT_SEGMENT = 'Premier';
ELSE IF BRAND_TOTAL >= 0.5 * AVG_CAT_SALES THEN PRODUCT_SEGMENT = 'Power';
ELSE PRODUCT_SEGMENT ='Retail' ;
RUN;

/* THEN LETS MAP IT BACK TO THE DATAMODEL */

PROC SQL;
CREATE TABLE DV.DATAMODEL AS 
SELECT A.*, B.PRODUCT_SEGMENT FROM DV.DATAMODEL AS A
LEFT JOIN
DV.PRODUCT_SEGMENT AS B
ON A.PRODUCT = B.PRODUCT;
QUIT;


/* CATEGORY , PRODUCT SEGMENT AND BRAND WISE TOP 10 SELLING PRODUCT */
/* FIRST WE WILL CREATE A TABLE WITH PRODUCT SALES */
PROC SQL;
CREATE TABLE DV.TOP_PROD_BY_BRANDS AS
SELECT CATEGORY, PRODUCT_SEGMENT, BRAND, PRODUCT, SUM(PROD_SALES) AS PROD_SALES
FROM DV.PRODUCT_SEGMENT
GROUP BY CATEGORY, PRODUCT_SEGMENT, BRAND, PRODUCT;
QUIT;

/* THEN WE WILL SORT */
PROC SORT DATA = DV.TOP_PROD_BY_BRANDS;
BY CATEGORY BRAND;
RUN;

/* THEN RANK */
PROC RANK DATA= DV.TOP_PROD_BY_BRANDS OUT = DV.TOP_PROD_BY_BRANDS DESCENDING;
VAR PROD_SALES;
BY CATEGORY BRAND;
RANKS RANKING;
RUN;

/* THEN FILTER RANK TO GET TOP 10 */
DATA DV.TOP_PROD_BY_BRANDS;
SET DV.TOP_PROD_BY_BRANDS;
WHERE RANKING <=10;
RUN;

/* TOP 10 PRODUCTS BY EACH BRAND AND THEIR CUSTOMER BASE */

PROC SQL;
SELECT A.*, B.UNQ_CUST_BASE FROM DV.TOP_PROD_BY_BRANDS AS A
INNER JOIN
(
SELECT PRODUCT, COUNT( DISTINCT CUSTOMER_ID) AS UNQ_CUST_BASE
FROM DV.DATAMODEL
GROUP BY PRODUCT
)
AS B
ON A.PRODUCT = B.PRODUCT;
QUIT;


/* GET THE BRAND WISE PRODUCT SALES IN LAST 6MONTHS CONTIONOUSLY GROWING */

/* LETS SELECT THE LAST 6 MONTHS DETAILS*/


PROC SQL;
CREATE TABLE DV.LAST_6_MONTHS AS
SELECT BRAND , PRODUCT,VISIT_MONTH, SUM(SALES_REV) AS TOTAL_SALES
FROM DV.DATAMODEL 
WHERE VISIT_MONTH BETWEEN 6 AND 12
GROUP BY BRAND,PRODUCT, VISIT_MONTH
ORDER BY BRAND, PRODUCT, VISIT_MONTH;
QUIT;

DATA DV.LAST_6_MONTHS;
SET DV.LAST_6_MONTHS;
IF TOTAL_SALES > LAG(TOTAL_SALES) THEN FLAG = 1;
ELSE FLAG = 0;
RUN;

PROC SORT DATA=DV.last_6_months;
BY BRAND PRODUCT;
RUN;

DATA DV.LAST_6_MONTHS;
SET DV.LAST_6_MONTHS;
BY BRAND PRODUCT;
IF FIRST.PRODUCT THEN DO;
COUNT = 0;
TOTAL_FLAG = 0;
END;
COUNT + 1;
TOTAL_FLAG + FLAG;
IF LAST.PRODUCT;
RUN;

DATA DV.LAST_6_MONTHS;
SET DV.LAST_6_MONTHS;
WHERE (TOTAL_FLAG = COUNT - 1) AND (TOTAL_FLAG <> 0);


/* BRAND AND PRODUCTWISE AVERAGE QUANTITY SOLD IN A YEAR-- */


/* WE WILL FIND OUT THE TOTAL PRODUCT, BRAND WISE SALES  */

PROC SQL;
CREATE TABLE PROD_QTY AS
SELECT BRAND, PRODUCT, SUM(ORDER_QTY) AS TOTAL  
FROM DV.DATAMODEL
GROUP BY BRAND, PRODUCT;
QUIT;

/* THEN WE WILL TAKE THE AVERAGE */
PROC SQL;
SELECT PRODUCT , AVG(TOTAL) AS AVG_QTY_SOLD_IN_A_YEAR
FROM PROD_QTY 
GROUP BY PRODUCT; 
QUIT;

/* TOP 10 SELLING PRODUCTS AND THE CUSTOMERS WHO BOUGHT THEM TOGETHER */

/* TOP SELLING PRODUCTS */

/* LETS GET THW PRODUCT WISE SALES DETAILS */
PROC SQL;
CREATE TABLE TOP_PROD AS
SELECT  PRODUCT, SUM(SALES_REV) AS TOTAL_SALES 
FROM DV.DATAMODEL
GROUP BY PRODUCT;
QUIT;

/* THEN RANK BASED ON SALES */
PROC RANK DATA= TOP_PROD OUT = TOP_PROD DESCENDING;
VAR TOTAL_SALES ;
RANKS RANKING;

/* SELECTING ONLY THE TOP 10 */
DATA TOP_PROD;
SET TOP_PROD;
WHERE RANKING <= 10;
RUN;


/* GETTING THE CUSTOMER WISE PRODUCT DETAILS FOR EACH CUSTOMER */
PROC SQL;
CREATE TABLE DV.CUST_PROD AS 
SELECT CUSTOMER_ID, PRODUCT, SUM(SALES_REV) FROM DV.DATAMODEL GROUP BY CUSTOMER_ID, PRODUCT;
QUIT;


/* GETTING THE CUSTOMERS WHO BOUGHT PRODUCTS FROM THIS LIST(TOP 10 PRODUCTS) */
PROC SQL;
CREATE TABLE DV.CUST_PROD AS 
SELECT A.*, B.RANKING FROM  DV.CUST_PROD AS A
INNER JOIN 
TOP_PROD AS B
ON A.PRODUCT = B.PRODUCT;
QUIT;

/* SELECTING ONLY WHERE CUSTOMER BOUGHT ALL 10 FROM THE LIST */
PROC SQL;
SELECT CUSTOMER_ID, COUNT(PRODUCT) FROM DV.CUST_PROD GROUP BY CUSTOMER_ID
HAVING COUNT(PRODUCT)=10;
QUIT;



/* ******************************************************************** */
/* 							STORE ANALYTICS 							*/
/* ******************************************************************** */

/* STORE'S TOTAL UNIQUE CUSTOMER BASE, TOTAL_VISITS, TOTAL_ORDERS AND TOTAL_SPENT */

PROC SQL;
SELECT STORE_ID, STORE_NAME, COUNT( DISTINCT CUSTOMER_ID) AS UNQ_CUST_BASE, COUNT(CUSTOMER_ID) AS TOTAL_VISITS,
COUNT(CUSTOMER_ID) AS TOTAL_ORDERS, SUM(SALES_REV) AS TOTAL_SPENTS FROM DV.DATAMODEL
GROUP BY STORE_ID, STORE_NAME;
QUIT;


/* STORE'S TOP SELLING CATEGORY WISE BRANDS */
PROC SQL;
CREATE TABLE STORE_BRAND AS
SELECT STORE_NAME, CATEGORY, BRAND , SUM(SALES_REV) AS TOTAL_SALES 
FROM DV.DATAMODEL
GROUP BY STORE_NAME, CATEGORY, BRAND
ORDER BY CATEGORY;
QUIT;

/* RANKING THE DATASET BASED ON SALES */
PROC RANK DATA=STORE_BRAND OUT = STORE_BRAND DESCENDING ;
VAR TOTAL_SALES;
RANKS RANKING;
BY CATEGORY;
RUN;

/* GETTING THE TOP BRANDS IN EACH CATEGORY*/
DATA STORE_BRAND;
SET STORE_BRAND;
WHERE RANKING = 1;
RUN;



/* STORE AND CUSTOMER TYPE UNIQUE COUNT OF CUSTOMER BASE AND TOTAL SALES */

PROC SQL;
SELECT STORE_NAME, CUSTOMER_TYPE, COUNT(DISTINCT CUSTOMER_ID)  AS UNQ_CUST_BASE,
SUM(SALES_REV) AS TOTAL_SALES 
FROM DV.DATAMODEL
GROUP BY STORE_NAME, CUSTOMER_TYPE;
QUIT;

/* STORE, CUSTOMER TYPE AND PRODUCT SEGMENT WISE TOTAL ORDERS */

/* creating asummary table with store_name, customer_type and product segment */
proc sql;
create table dv.cust_vs_prod_types as
select store_name, customer_type, product_segment, 
count(customer_id) as total_orders
from dv.datamodel 
group by store_name, customer_type, product_segment ;
quit;

/* assigning a new variable called key */
data dv.cust_vs_prod_types;
set dv.cust_vs_prod_types;
key = 1;
run;

/* joining the subquery using key and then also giving order details in percent*/
proc sql;
create table cust_vs_prod_types as
select a.*,(a.total_orders/b.total) as in_perc format=percent5.4 from dv.cust_vs_prod_types as a
left join
(select key, sum(total_orders) as total from dv.cust_vs_prod_types group by key) as b
on a.key = b.key;
quit;


/* STORE, CUSTOMER TYPE AND PRODUCT SEGMENT WISE TOTAL SALES */

/* finding the total sales by each customer type and product segment */
proc sql;
create table dv.cust_vs_prod_types as
select store_name, customer_type, product_segment, 
sum(sales_rev) as total_sales
from dv.datamodel 
group by store_name, customer_type, product_segment ;
quit;

/* key */
data dv.cust_vs_prod_types;
set dv.cust_vs_prod_types;
key = 1;
run;

/* total sales in % */
proc sql;
create table cust_vs_prod_types as
select a.*,(a.total_sales/b.total) as in_perc format=percent5.4 from dv.cust_vs_prod_types as a
left join
(select key, sum(total_sales) as total from dv.cust_vs_prod_types group by key) as b
on a.key = b.key;
quit;


/* STORE TYPE WISE UNIQUE CUSTOMERS, TOTAL VISITS, TOTAL ORDERS, AND TOTAL-SPENT */

PROC SQL;
SELECT STORE_TYPE, COUNT(DISTINCT CUSTOMER_ID) AS UNQ_CUST , COUNT(CUSTOMER_ID) AS TOTAL_VISITS,
COUNT(CUSTOMER_ID) AS TOTAL_ORDERS, SUM( SALES_REV) AS TOTAL_SPENT
FROM DV.DATAMODEL 
GROUP BY STORE_TYPE;
QUIT;



/*-------------------------------------END OF ANALYSIS ---------------------------------------*/
