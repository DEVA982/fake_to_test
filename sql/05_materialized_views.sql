DROP MATERIALIZED VIEW IF EXISTS freelancer_lifetime_stats;
CREATE MATERIALIZED VIEW freelancer_lifetime_stats AS
SELECT f.id AS freelancer_id, f.name,
 COUNT(c.id) FILTER (WHERE c.status='COMPLETED') AS completed_contracts,
 COALESCE(SUM(c.budget) FILTER (WHERE c.status='COMPLETED'),0)::DECIMAL(14,2) AS total_earnings
FROM freelancers f LEFT JOIN contracts c ON c.freelancer_id=f.id
GROUP BY f.id,f.name;

CREATE UNIQUE INDEX idx_freelancer_lifetime_stats_pk
ON freelancer_lifetime_stats(freelancer_id);

CREATE OR REPLACE PROCEDURE refresh_freelancer_lifetime_stats()
LANGUAGE plpgsql AS $$
BEGIN
 REFRESH MATERIALIZED VIEW CONCURRENTLY freelancer_lifetime_stats;
END; $$;
-- CALL refresh_freelancer_lifetime_stats();
