GigTask – Freelance Micro-Jobs Marketplace

GigTask is a database-focused freelance micro-jobs marketplace demonstrating PostgreSQL and MongoDB features for transactional data, auditing, indexing, analytics, and geospatial workloads.

Tech Stack

PostgreSQL 16

MongoDB

Python 3

SQL

MongoDB Shell (mongosh)

Repository Structure

GigTask/
├── README.md
├── requirements.txt
├── docs/
│   ├── relational_erd.png
│   └── mongo_schema_map.json
├── sql/
│   ├── 01_schema_ddl.sql
│   ├── 02_indexes.sql
│   ├── 03_triggers_and_audit.sql
│   ├── 04_stored_procedures.sql
│   ├── 05_materialized_views.sql
│   └── 06_window_analytics.sql
├── mongo/
│   ├── 01_collections_and_indexes.js
│   ├── 02_workflow3_geonear.js
│   └── 03_workflow4_facet.js
├── data_generation/
│   ├── postgres_seeder.py
│   └── mongo_seeder.py
└── performance/
    └── README.md

Database Design

PostgreSQL

The relational database contains:

clients

freelancers

contracts

wallet_audit_logs

Main relationships:

A client can have multiple contracts.

A freelancer can have multiple contracts.

Each contract references one client and one freelancer.

Wallet balance changes are recorded in wallet_audit_logs.

The relational ER diagram is available at docs/relational_erd.png.

MongoDB

The MongoDB database contains:

Portfolios

GigReviews

WorkerLocations

MongoDB is used for flexible portfolio/review data and real-time worker location data.

The MongoDB schema map is available at docs/mongo_schema_map.json.

Scale Requirements

The project is designed to demonstrate database operations at approximately:

1,000 clients

5,000 freelancers

50,000 contracts

100,000 wallet audit records

500,000 worker location records

Worker location records use a 2-hour TTL, so the exact document count can fluctuate as old records expire.

PostgreSQL Setup

Create the database:

createdb gigtask

Set the PostgreSQL connection string:

export DATABASE_URL="dbname=gigtask user=YOUR_POSTGRES_USER host=localhost port=5432"

Create a Python virtual environment:

python3 -m venv venv
source venv/bin/activate

Install dependencies:

python3 -m pip install -r requirements.txt

Run the SQL files in order:

psql gigtask -f sql/01_schema_ddl.sql
psql gigtask -f sql/02_indexes.sql
psql gigtask -f sql/03_triggers_and_audit.sql
psql gigtask -f sql/04_stored_procedures.sql
psql gigtask -f sql/05_materialized_views.sql
psql gigtask -f sql/06_window_analytics.sql

PostgreSQL Data Generation

Run:

python3 data_generation/postgres_seeder.py

Expected approximate counts:

clients             1,000
freelancers         5,000
contracts          50,000
wallet_audit_logs 100,000

PostgreSQL Indexing

A partial unique index prevents a freelancer from having more than one active gig:

CREATE UNIQUE INDEX idx_active_gig
ON contracts(freelancer_id)
WHERE status = 'IN PROGRESS';

Additional indexes are created for completed contracts, available freelancers, contract clients, contract freelancers, contract creation time, and wallet audit records.

Wallet Audit Trigger

A PostgreSQL trigger automatically records escrow balance changes.

The audit log records:

Client ID

Amount changed

Action type

Balance after the change

Timestamp

Example:

UPDATE clients
SET escrow_balance = escrow_balance - 1000
WHERE id = 'CLIENT_UUID';

The corresponding wallet change is automatically inserted into wallet_audit_logs.

Atomic Gig Funding Procedure

Call the stored procedure directly:

CALL fund_gig(
    'CLIENT_UUID',
    'FREELANCER_UUID',
    1000.00
);

The procedure:

Locks the client row.

Checks that the client exists.

Checks that the budget is positive.

Checks that sufficient escrow balance exists.

Checks that the freelancer exists.

Deducts the budget from escrow.

Creates a new FUNDED contract.

Commits the transaction.

Do not wrap the call in an explicit BEGIN/COMMIT block.

Materialized View

The project creates freelancer_lifetime_stats, containing:

Freelancer ID

Freelancer name

Completed contract count

Total lifetime earnings

Refresh it using:

CALL refresh_freelancer_lifetime_stats();

The refresh uses:

REFRESH MATERIALIZED VIEW CONCURRENTLY freelancer_lifetime_stats;

A unique index on freelancer_id allows concurrent refreshes.

Window Function Analytics

sql/06_window_analytics.sql calculates:

Daily freelancer revenue

7-day moving average revenue

Freelancer ranking

The moving average uses:

AVG(daily_revenue) OVER (
    PARTITION BY freelancer_id
    ORDER BY revenue_day
    RANGE BETWEEN INTERVAL '6 days' PRECEDING
          AND CURRENT ROW
)

Freelancers are ranked using:

DENSE_RANK() OVER (
    ORDER BY moving_avg_7d DESC
)

MongoDB Setup

Start MongoDB and connect:

mongosh

Create/use the database:

use gigtask

Create collections and indexes:

mongosh gigtask mongo/01_collections_and_indexes.js

The script creates:

Portfolios
GigReviews
WorkerLocations

MongoDB Indexes

Worker locations use a 2dsphere index:

db.WorkerLocations.createIndex({
    location: "2dsphere"
});

A TTL index automatically removes location records after two hours:

db.WorkerLocations.createIndex(
    { created_at: 1 },
    { expireAfterSeconds: 7200 }
);

Verify the indexes:

db.WorkerLocations.getIndexes()

MongoDB Data Generation

Run:

python3 data_generation/mongo_seeder.py

The location seeder generates approximately 500,000 worker-location records.

Because the collection has a 2-hour TTL index, older records are automatically deleted.

Workflow 3 – GeoNear

The project uses MongoDB $geoNear to find nearby available workers.

Example:

db.WorkerLocations.aggregate([
    {
        $geoNear: {
            near: {
                type: "Point",
                coordinates: [78.4867, 17.3850]
            },
            key: "location",
            distanceField: "distanceMeters",
            spherical: true,
            query: {
                is_available: true
            }
        }
    },
    {
        $limit: 1
    }
])

Example result:

freelancer_id: "1307"
distanceMeters: 57.480576756392985

Workflow 4 – Facet Analytics

The project uses MongoDB $facet to perform multiple analyses in one aggregation pipeline.

The workflow includes:

Rating distribution

Top skill tags

Overall worker ratings

The top skill tags are calculated using $unwind.

Example:

db.GigReviews.aggregate([
    {
        $facet: {
            rating_distribution: [
                {
                    $group: {
                        _id: "$rating",
                        count: { $sum: 1 }
                    }
                }
            ],
            top_skill_tags: [
                { $unwind: "$skill_tags" },
                {
                    $group: {
                        _id: "$skill_tags",
                        count: { $sum: 1 },
                        average_rating: { $avg: "$rating" }
                    }
                }
            ],
            overall_worker_ratings: [
                {
                    $group: {
                        _id: "$freelancer_id",
                        average_rating: { $avg: "$rating" },
                        review_count: { $sum: 1 }
                    }
                }
            ]
        }
    }
])

Performance Testing

Performance tests were performed using:

EXPLAIN (ANALYZE, BUFFERS)

Completed Contract Lookup

QUERY PLAN
------------------------------------------------------------------------------------------------------------------------------------------------
 Bitmap Heap Scan on contracts  (cost=131.48..161.25 rows=8 width=79) (actual time=4.083..4.153 rows=22 loops=1)
   Recheck Cond: ((freelancer_id = $0) AND ((status)::text = 'COMPLETED'::text))
   Heap Blocks: exact=27
   Buffers: shared hit=82
   -> Bitmap Index Scan on idx_contracts_completed_freelancer
         Index Cond: (freelancer_id = $0)
 Planning Time: 2.041 ms
 Execution Time: 4.227 ms

Active Gig Lookup

QUERY PLAN
---------------------------------------------------------------------------------------------------------------------------
 Index Scan using idx_active_gig on contracts  (cost=0.30..8.32 rows=1 width=79) (actual time=0.169..0.171 rows=0 loops=1)
   Index Cond: (freelancer_id = $0)
   Buffers: shared hit=5
 Planning Time: 0.530 ms
 Execution Time: 0.222 ms

Wallet Audit Lookup

QUERY PLAN
------------------------------------------------------------------------------------------------------------------------------------------
 Sort  (cost=308.12..308.37 rows=100 width=55) (actual time=1.261..1.271 rows=94 loops=1)
   Sort Key: wallet_audit_logs.created_at DESC
   Buffers: shared hit=95
   -> Bitmap Heap Scan on wallet_audit_logs
         Recheck Cond: (client_id = $0)
         -> Bitmap Index Scan on idx_audit_client_created
               Index Cond: (client_id = $0)
 Planning Time: 0.286 ms
 Execution Time: 1.348 ms

Materialized View Lookup

QUERY PLAN
----------------------------------------------------------------------------------------------------------------------------------------
 Limit  (cost=210.05..210.07 rows=10 width=46) (actual time=1.834..1.838 rows=10 loops=1)
   Buffers: shared hit=52
   -> Sort  (cost=210.05..222.55 rows=5000 width=46) (actual time=1.833..1.834 rows=10 loops=1)
         Sort Key: total_earnings DESC
         Sort Method: top-N heapsort  Memory: 27kB
         -> Seq Scan on freelancer_lifetime_stats  (cost=0.00..102.00 rows=5000 width=46) (actual time=0.021..0.872 rows=5000 loops=1)
 Planning Time: 0.620 ms
 Execution Time: 1.898 ms

Performance Summary

Workload

Execution Time

Completed contract lookup

4.227 ms

Active gig lookup

0.222 ms

Wallet audit lookup

1.348 ms

Materialized view lookup

1.898 ms

Detailed performance information is available in performance/README.md.

Verification Commands

PostgreSQL Counts

SELECT COUNT(*) FROM clients;
SELECT COUNT(*) FROM freelancers;
SELECT COUNT(*) FROM contracts;
SELECT COUNT(*) FROM wallet_audit_logs;

MongoDB Counts

db.Portfolios.countDocuments()
db.GigReviews.countDocuments()
db.WorkerLocations.countDocuments()

Check WorkerLocations Indexes

db.WorkerLocations.getIndexes()

Check PostgreSQL Indexes

SELECT indexname, indexdef
FROM pg_indexes
WHERE tablename IN (
    'clients',
    'freelancers',
    'contracts',
    'wallet_audit_logs'
);

Notes

PostgreSQL SQL scripts should be executed in numerical order.

The data generators are intended for creating the large test dataset.

The MongoDB TTL index intentionally removes location records older than two hours.

The stored procedure fund_gig should be called directly because it manages its own transaction boundary.

06_window_analytics.sql is an analytics query and does not create a permanent table or view.