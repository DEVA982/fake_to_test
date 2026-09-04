WITH daily_revenue AS (
 SELECT freelancer_id, created_at::date AS revenue_day, SUM(budget) AS daily_revenue
 FROM contracts WHERE status='COMPLETED'
 GROUP BY freelancer_id,created_at::date
), moving AS (
 SELECT freelancer_id,revenue_day,daily_revenue,
 AVG(daily_revenue) OVER(
   PARTITION BY freelancer_id ORDER BY revenue_day
   RANGE BETWEEN INTERVAL '6 days' PRECEDING AND CURRENT ROW
 ) AS moving_avg_7d
 FROM daily_revenue
), latest AS (
 SELECT *,ROW_NUMBER() OVER(PARTITION BY freelancer_id ORDER BY revenue_day DESC) rn
 FROM moving
)
SELECT freelancer_id,revenue_day,ROUND(moving_avg_7d,2) AS moving_average_7d,
 DENSE_RANK() OVER(ORDER BY moving_avg_7d DESC) AS freelancer_rank
FROM latest WHERE rn=1 ORDER BY freelancer_rank,freelancer_id;
