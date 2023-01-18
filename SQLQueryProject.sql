use Basic_Zomato_Data

--1. Total amount spent by each user

SELECT s.userid, sum(p.price) AS Total_Amount_Paid
FROM sales s
LEFT JOIN product p
ON s.product_id=p.product_id
GROUP BY s.userid


--2. No of days each user has visited app

SELECT userid, COUNT(DISTINCT(created_date)) AS Count_of_Days
FROM sales
GROUP BY userid


--3. First product purchased by each user

SELECT fi.userid,fi.product_id FROM
(SELECT *, RANK() OVER(PARTITION BY userid ORDER BY created_date) AS rnk
FROM sales) fi
WHERE fi.rnk=1


--4.What is the most purchased item and how many times it was purchased by all user

SELECT userid, COUNT(created_date) AS No_of_Purchases FROM sales
WHERE product_id=
(SELECT TOP (1) product_id FROM
(SELECT product_id, count(product_id) AS Cnt
FROM sales
GROUP BY product_id) A
ORDER BY Cnt desc)
GROUP BY userid


--5.Favourite item of each user(Most ordered)

SELECT * ,RANK() OVER(PARTITION BY userid ORDER BY Cnt DESC) AS Rnk FROM
(SELECT userid,product_id, count(product_id) AS Cnt
FROM sales
GROUP BY userid,product_id
) A

SELECT userid,product_id FROM
(SELECT * ,RANK() OVER(PARTITION BY userid ORDER BY Cnt DESC) AS Rnk FROM
(SELECT userid,product_id, count(product_id) AS Cnt
FROM sales
GROUP BY userid,product_id
) A) B
WHERE Rnk=1


--6. What is the item that was first purchased by a user after buying gold membership?

SELECT * FROM sales 
WHERE userid IN (
SELECT distinct(userid) FROM goldusers_signup)
GROUP BY userid, created_date,product_id
ORDER BY userid, created_date desc

SELECT userid,product_id FROM
(SELECT *, RANK() OVER (PARTITION BY userid ORDER BY created_date ) AS Rnk FROM
(SELECT s.userid,s.created_date,s.product_id,g.gold_signup_date 
FROM sales s
INNER JOIN goldusers_signup g
ON s.userid=g.userid ) A
WHERE created_date>gold_signup_date) B
WHERE Rnk=1


--7. What was the item that was last purchased by a user before buying gold membership?

SELECT * FROM 
(SELECT *, RANK() OVER (PARTITION BY userid ORDER BY created_date desc) AS Rnk FROM
(SELECT s.userid,s.created_date,s.product_id,g.gold_signup_date 
FROM sales s
INNER JOIN goldusers_signup g
ON s.userid=g.userid ) A
WHERE created_date<gold_signup_date
) B
WHERE Rnk =1 


--8. What is the total orders and amount paid by a user before becoming a memmber

WITH Before_Total AS 
(
SELECT A.userid,A.created_date,A.product_id,A.gold_signup_date, RANK() OVER (PARTITION BY userid ORDER BY created_date desc) AS Rnk FROM
	(SELECT s.userid,s.created_date,s.product_id,g.gold_signup_date  FROM sales s
	INNER JOIN goldusers_signup g
	ON s.userid = g.userid) A
	WHERE created_date<gold_signup_date
)
SELECT BT.userid, COUNT(BT.product_id) AS No_of_orders ,SUM(p.price) AS Total_Amount
FROM Before_Total BT
INNER JOIN product p
ON BT.product_id=p.product_id
GROUP BY BT.userid


--9. If buying a product adds to Reward_Points, Assume
--P1 5rs spent gives 1 Reward_Point
--P2 10rs spent gives 5 Reward_Point
--P3 5rs spent gives 1 Reward_Point
--Calculate total points collected by each user and for which product max points have been given.

CREATE VIEW Total_Price AS 
	SELECT s.userid, s.product_id, SUM(price) AS Total 
	FROM sales s
	INNER JOIN product p
	ON s.product_id = p.product_id
	GROUP BY s.userid,s.product_id 

CREATE VIEW Reward AS
	SELECT *,
	CASE
		WHEN product_id=1 Then Total/5 
		WHEN product_id=2 Then (Total/10)*5
		WHEN product_id=3 Then Total/5
	END AS Reward
	FROM Total_Price

SELECT * From Reward

SELECT userid,SUM(Reward) AS Total_Reward_Points 
FROM Reward 
GROUP BY userid

SELECT TOP 1 product_id, SUM(Reward) AS Total_Rewards 
FROM Reward 
GROUP BY product_id
ORDER BY Total_Rewards DESC


--10. After one year of joing gold membership user gets 5 Reward Points for every 10rs spent, 
--what is total points earned after one year of joining gold

--5RP=10rs thus 0.5RP=1rs

SELECT B.userid,B.product_id,B.created_date,B.gold_signup_date,p.price*0.5 AS Total_Reward_Points 
FROM 
	(
	SELECT s.userid,s.product_id, s.created_date,g.gold_signup_date 
	FROM sales s
	INNER JOIN goldusers_signup g
	ON s.userid=g.userid
	WHERE s.created_date >= g.gold_signup_date AND
	s.created_date < DATEADD(year,1,g.gold_signup_date)
	) B
INNER JOIN product p
ON B.product_id=p.product_id



--11. Rank all transactions of each gold user and mark NA for non-gold members

SELECT C.userid,C.created_date,C.product_id,C.gold_signup_date, CASE WHEN Rnk=0 THEN 'NA' ELSE Rnk END AS True_Rnk FROM
(SELECT *, 
	CAST((CASE 
	WHEN gold_signup_date IS NULL THEN 0 
	ELSE RANK() OVER (PARTITION BY userid ORDER BY created_date DESC) 
	END)AS varchar) AS Rnk 
FROM
(SELECT s.userid,s.created_date,s.product_id,g.gold_signup_date
FROM sales s
LEFT JOIN goldusers_signup g
ON s.userid=g.userid
AND s.created_date>=g.gold_signup_date
) B)C
