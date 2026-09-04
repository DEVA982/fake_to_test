# Performance Proof

All measurements below were collected from the seeded PostgreSQL database.

## Dataset Size

- Clients: 1,000
- Freelancers: 5,000
- Contracts: 50,000
- Wallet audit logs: 100,000

## 1. Completed Contracts Index

Query:

EXPLAIN (ANALYZE, BUFFERS)
SELECT *
FROM contracts
WHERE freelancer_id = (
    SELECT freelancer_id
    FROM freelancer_lifetime_stats
    ORDER BY total_earnings DESC
    LIMIT 1
)
AND status = 'COMPLETED';

Key result:

Bitmap Index Scan on idx_contracts_completed_freelancer
Execution Time: 4.803 ms
Buffers: shared hit=74

The execution plan confirms that idx_contracts_completed_freelancer is used.

## 2. Active Gig Partial Unique Index

Query:

EXPLAIN (ANALYZE, BUFFERS)
SELECT *
FROM contracts
WHERE freelancer_id = (
    SELECT id
    FROM freelancers
    LIMIT 1
)
AND status = 'IN PROGRESS';

Key result:

Index Scan using idx_active_gig on contracts
Index Cond: (freelancer_id = $0)
Execution Time: 0.130 ms
Buffers: shared hit=4

The execution plan confirms that the partial index idx_active_gig is used.

## 3. Wallet Audit Lookup

Query:

EXPLAIN (ANALYZE, BUFFERS)
SELECT *
FROM wallet_audit_logs
WHERE client_id = (
    SELECT id
    FROM clients
    LIMIT 1
)
ORDER BY created_at DESC;

Key result:

Bitmap Index Scan on idx_audit_client_created
Index Cond: (client_id = $0)
Execution Time: 36.723 ms
Buffers: shared hit=107

The execution plan confirms that idx_audit_client_created is used.

## 4. Materialized View Query

Query:

EXPLAIN (ANALYZE, BUFFERS)
SELECT *
FROM freelancer_lifetime_stats
ORDER BY total_earnings DESC
LIMIT 10;

Key result:

Seq Scan on freelancer_lifetime_stats
Sort Method: top-N heapsort
Execution Time: 4.572 ms
Buffers: shared hit=52

The materialized view contains 5,000 freelancer summary rows and the top-10 query completes in approximately 4.6 ms.

## Performance Summary

- Completed contracts index: 4.803 ms
- Active gig index: 0.130 ms
- Audit lookup index: 36.723 ms
- Materialized view top-10 query: 4.572 ms

All measurements were obtained using PostgreSQL EXPLAIN (ANALYZE, BUFFERS) against the seeded dataset.

