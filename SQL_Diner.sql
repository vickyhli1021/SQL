-- 1. What is the total amount each customer spent at the restaurant?
SELECT s.customer_id, SUM(m.price) AS total_spent
FROM dannys_diner.sales s
LEFT JOIN dannys_diner.menu m ON s.product_id=m.product_id
GROUP BY customer_id;

-- 2. How many days has each customer visited the restaurant?
SELECT customer_id, COUNT(order_date)
FROM dannys_diner.sales
GROUP BY customer_id;


-- 3. What was the first item from the menu purchased by each customer?
CREATE VIEW ordered_sales AS
SELECT s.customer_id, s.order_date, m.product_name,
 DENSE_RANK() OVER(PARTITION BY s.customer_id ORDER BY s.order_date ASC) AS rank
FROM dannys_diner.sales s
LEFT JOIN dannys_diner.menu m ON s.product_id=m.product_id;

SELECT customer_id, product_name
FROM ordered_sales
WHERE rank=1
GROUP BY customer_id, product_name;


-- 4. What is the most purchased item on the menu and how many times was it purchased by all customers?
SELECT COUNT(s.product_id) AS purchase_feq, m.product_name
FROM dannys_diner.sales s
LEFT JOIN dannys_diner.menu m on s.product_id=m.product_id
GROUP BY m.product_name
ORDER BY purchase_feq DESC
LIMIT 1;


-- 5. Which item was the most popular for each customer?
CREATE VIEW popular_dish AS
SELECT s.customer_id, m.product_name, COUNT(s.product_id) AS item_freq,
  DENSE_RANK()OVER(PARTITION BY s.customer_id ORDER BY COUNT(s.product_id)DESC) AS rank
FROM dannys_diner.sales s
LEFT JOIN dannys_diner.menu m on s.product_id=m.product_id
GROUP BY s.customer_id, m.product_name;

SELECT customer_id, product_name, item_freq
FROM popular_dish 
WHERE rank = 1;


-- 6. Which item was purchased first by the customer after they became a member?
WITH join_member AS (
  SELECT mb.customer_id, s.product_id,
    ROW_NUMBER() OVER (PARTITION BY mb.customer_id ORDER BY s.order_date) AS row_num
  FROM dannys_diner.members mb
  LEFT JOIN dannys_diner.sales s on s.customer_id=mb.customer_id
  AND s.order_date > mb.join_date
)

SELECT j.customer_id, m.product_name
FROM join_member j
LEFT JOIN dannys_diner.menu m ON j.product_id=m.product_id
WHERE row_num=1;

-- CTE is used to simplify the code, but only exists in memory while the query is running
-- CTE cannot be used in the next query unless define it again, while views are stored in the memory


-- 7. Which item was purchased just before the customer became a member?
WITH before_member AS (
  SELECT mb.customer_id, s.product_id,
    ROW_NUMBER() OVER (PARTITION BY mb.customer_id ORDER BY s.order_date DESC) AS row_num
  FROM dannys_diner.members mb
  LEFT JOIN dannys_diner.sales s on s.customer_id=mb.customer_id
  AND s.order_date < mb.join_date
)

SELECT b.customer_id, m.product_name
FROM before_member b
LEFT JOIN dannys_diner.menu m ON b.product_id=m.product_id
WHERE row_num=1;


-- 8. What is the total items and amount spent for each member before they became a member?
SELECT s.customer_id, COUNT(s.product_id) AS total_items, SUM(m.price) AS total_amount
FROM dannys_diner.sales s
LEFT JOIN dannys_diner.menu m on s.product_id=m.product_id
LEFT JOIN dannys_diner.members mb ON s.customer_id=mb.customer_id
WHERE s.order_date < mb.join_date
GROUP BY s.customer_id;

-- 9.  If each $1 spent equates to 10 points and sushi has a 2x points multiplier - how many points would each customer have?
CREATE VIEW points AS
SELECT product_id, 
  CASE WHEN product_id=1 THEN price*20
  ELSE price*10 END AS points
FROM dannys_diner.menu;

SELECT s.customer_id, SUM(p.points)
FROM dannys_diner.sales s
LEFT JOIN points p on s.product_id=p.product_id
GROUP BY s.customer_id;


-- 10. In the first week after a customer joins the program (including their join date) they earn 2x points on all items, not just sushi - how many points do customer A and B have at the end of January?
WITH dates_cte AS (
  SELECT 
    customer_id, 
    join_date, 
    join_date + 6 AS valid_date, 
    DATE_TRUNC(
      'day', '2021-01-31'::DATE) AS last_date
  FROM dannys_diner.members
)

SELECT 
  s.customer_id, 
  SUM(CASE
    WHEN m.product_name = 'sushi' THEN 20 * m.price
    WHEN s.order_date BETWEEN d.join_date AND d.valid_date THEN 20 * m.price
    ELSE 10 * m.price END) AS points
FROM dannys_diner.sales s
JOIN dates_cte d
  ON s.customer_id = d.customer_id
  AND s.order_date <= d.last_date
JOIN dannys_diner.menu m
  ON s.product_id = m.product_id
GROUP BY s.customer_id;






