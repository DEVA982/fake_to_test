# GigTask – Freelance Micro-Jobs Marketplace

A database implementation of a freelance micro-jobs marketplace using PostgreSQL and MongoDB.

The project demonstrates transactional gig funding, escrow auditing, indexing, materialized views, SQL window analytics, MongoDB geospatial search, faceted review analytics, TTL indexes, and large-scale test data generation.

---

## 1. PostgreSQL Schema

**File:** `sql/01_schema_ddl.sql`

This script creates the core relational schema for GigTask.

### Main Tables

- `clients` — stores client information and escrow balances.
- `freelancers` — stores freelancer information, location, and availability.
- `contracts` — stores gigs between clients and freelancers.
- `wallet_audit_logs` — stores automatic audit records for escrow changes.

### Key Features

- UUID primary keys.
- Foreign-key relationships between clients, freelancers, and contracts.
- Non-negative escrow balance constraint.
- Contract budget and status fields.
- Contract timestamps.
- Indexes for common lookups.

### Execute

```bash
psql gigtask -f sql/01_schema_ddl.sql
```

---

## 2. PostgreSQL Indexing

**File:** `sql/02_indexes.sql`

This script creates indexes required for query performance and business-rule enforcement.

### Active Gig Partial Unique Index

The following partial unique index prevents a freelancer from having more than one contract with status `IN PROGRESS`:

```sql
CREATE UNIQUE INDEX idx_active_gig
ON contracts(freelancer_id)
WHERE status = 'IN PROGRESS';
```

### Other Indexes

Indexes are also created for:

- Completed contracts.
- Available freelancers.
- Client contract lookups.
- Freelancer contract lookups.
- Contract creation time.
- Wallet audit records.

### Execute

```bash
psql gigtask -f sql/02_indexes.sql
```

---

## 3. PostgreSQL Trigger and Wallet Audit

**File:** `sql/03_triggers_and_audit.sql`

This script implements automatic auditing of escrow balance changes.

### Trigger

The trigger fires when a client's `escrow_balance` is inserted or updated.

It records:

- Client ID.
- Amount changed.
- Action type.
- Balance after the change.
- Timestamp.

For an update, the amount changed is calculated as:

```text
NEW.escrow_balance - OLD.escrow_balance
```

### Example

```sql
UPDATE clients
SET escrow_balance = escrow_balance - 1000
WHERE id = 'CLIENT_UUID';
```

The corresponding change is automatically inserted into:

```text
wallet_audit_logs
```

### Verify

```sql
SELECT *
FROM wallet_audit_logs
ORDER BY created_at DESC
LIMIT 10;
```

### Execute

```bash
psql gigtask -f sql/03_triggers_and_audit.sql
```

---

## 4. Atomic Gig Funding – Stored Procedure

**File:** `sql/04_stored_procedures.sql`

This script creates the `fund_gig` PostgreSQL procedure.

### Procedure

```sql
CALL fund_gig(
    'CLIENT_UUID',
    'FREELANCER_UUID',
    1000.00
);
```

### Workflow

The procedure:

1. Locks the client row using `FOR UPDATE`.
2. Checks that the client exists.
3. Validates that the budget is greater than zero.
4. Checks that the client has sufficient escrow balance.
5. Checks that the freelancer exists.
6. Deducts the budget from the client's escrow.
7. Creates a new contract with status `FUNDED`.
8. Commits the transaction.

The wallet deduction and contract creation therefore occur atomically.

### Execute

```bash
psql gigtask -f sql/04_stored_procedures.sql
```

> The procedure should be called directly and should not be wrapped inside an explicit `BEGIN`/`COMMIT` block.

---

## 5. Materialized View

**File:** `sql/05_materialized_views.sql`

This script creates:

```text
freelancer_lifetime_stats
```

### Purpose

The materialized view provides precomputed lifetime statistics for freelancers based on completed contracts.

### Statistics

The view contains:

- Freelancer ID.
- Freelancer name.
- Completed contract count.
- Total lifetime earnings.

### Refresh

A concurrent refresh procedure is also provided:

```sql
CALL refresh_freelancer_lifetime_stats();
```

Internally it uses:

```sql
REFRESH MATERIALIZED VIEW CONCURRENTLY freelancer_lifetime_stats;
```

A unique index on `freelancer_id` supports the concurrent refresh.

### Verify

```sql
SELECT *
FROM freelancer_lifetime_stats
ORDER BY total_earnings DESC
LIMIT 10;
```

### Execute

```bash
psql gigtask -f sql/05_materialized_views.sql
```

---

## 6. SQL Window Analytics

**File:** `sql/06_window_analytics.sql`

This script performs freelancer revenue trend analysis using CTEs and SQL window functions.

### Step 1 — Daily Revenue

Completed contracts are grouped by freelancer and date to calculate daily revenue.

### Step 2 — Seven-Day Moving Average

A seven-day moving average is calculated using:

```sql
AVG(daily_revenue) OVER (
    PARTITION BY freelancer_id
    ORDER BY revenue_day
    RANGE BETWEEN INTERVAL '6 days' PRECEDING
          AND CURRENT ROW
)
```

### Step 3 — Freelancer Ranking

Freelancers are ranked using:

```sql
DENSE_RANK() OVER (
    ORDER BY moving_avg_7d DESC
)
```

### Execute

```bash
psql gigtask -f sql/06_window_analytics.sql
```

The query prints the calculated analytics results directly.

---

# MongoDB

## 7. MongoDB Collections and Indexes

**File:** `mongo/01_collections_and_indexes.js`

This script creates the MongoDB collections:

- `Portfolios`
- `GigReviews`
- `WorkerLocations`

### WorkerLocations

Worker locations use GeoJSON:

```text
{
  type: "Point",
  coordinates: [longitude, latitude]
}
```

A `2dsphere` index supports geospatial queries:

```javascript
db.WorkerLocations.createIndex({
    location: "2dsphere"
});
```

### Two-Hour TTL

Worker locations automatically expire after two hours:

```javascript
db.WorkerLocations.createIndex(
    { created_at: 1 },
    { expireAfterSeconds: 7200 }
);
```

### Execute

```bash
mongosh gigtask mongo/01_collections_and_indexes.js
```

### Verify

```javascript
use gigtask

db.WorkerLocations.getIndexes()
```

---

## 8. MongoDB Data Generation

**File:** `data_generation/mongo_seeder.py`

The MongoDB seeder generates approximately 500,000 worker-location documents.

Because `WorkerLocations` has a two-hour TTL index, the count can decrease as old documents expire.

### Run

First activate the Python environment:

```bash
source venv/bin/activate
```

Then run:

```bash
python3 data_generation/mongo_seeder.py
```

### Verify Counts

```bash
mongosh gigtask
```

Then:

```javascript
db.Portfolios.countDocuments()
db.GigReviews.countDocuments()
db.WorkerLocations.countDocuments()
```

---

## 9. Workflow 3 — `$geoNear`

**File:** `mongo/02_workflow3_geonear.js`

This workflow finds the nearest available worker using MongoDB `$geoNear`.

### Query

The search point is:

```text
Longitude: 78.4867
Latitude: 17.3850
```

The query:

- Uses the `location` GeoJSON field.
- Uses the `2dsphere` index.
- Filters for available workers.
- Calculates distance in meters.
- Returns the nearest worker.

### Run

```bash
mongosh gigtask mongo/02_workflow3_geonear.js
```

### Example Result

```text
freelancer_id: "1307"
distanceMeters: 57.480576756392985
```

---

## 10. Workflow 4 — `$facet`

**File:** `mongo/03_workflow4_facet.js`

This workflow uses `$facet` to perform multiple review analyses in one aggregation pipeline.

### Analyses

#### Rating Distribution

Groups reviews by rating and counts the number of reviews for each rating.

#### Top Skill Tags

Uses `$unwind` on `skill_tags` and calculates:

- Number of reviews per skill.
- Average rating per skill.

#### Overall Worker Ratings

Groups reviews by freelancer and calculates:

- Average rating.
- Review count.

### Run

```bash
mongosh gigtask mongo/03_workflow4_facet.js
```

---

# Data Generation

## 11. PostgreSQL Data Generation

**File:** `data_generation/postgres_seeder.py`

The PostgreSQL seeder creates approximately:

```text
Clients             1,000
Freelancers         5,000
Contracts          50,000
Wallet audit logs 100,000
```

### Run

Set the database connection first:

```bash
export DATABASE_URL="dbname=gigtask user=YOUR_POSTGRES_USER host=localhost port=5432"
```

Then:

```bash
python3 data_generation/postgres_seeder.py
```

### Verify

```bash
psql gigtask
```

```sql
SELECT COUNT(*) FROM clients;
SELECT COUNT(*) FROM freelancers;
SELECT COUNT(*) FROM contracts;
SELECT COUNT(*) FROM wallet_audit_logs;
```

---

# Complete Setup

## 12. Prerequisites

Install:

- PostgreSQL 16
- MongoDB
- Python 3
- `mongosh`

Make sure PostgreSQL and MongoDB are running before executing the project.

---

## 13. Clone the Repository

```bash
git clone https://github.com/DEVA982/fake_to_test.git
cd fake_to_test
```

---

## 14. PostgreSQL Setup

Create the database:

```bash
createdb gigtask
```

Create and activate the Python environment:

```bash
python3 -m venv venv
source venv/bin/activate
```

Install dependencies:

```bash
python3 -m pip install -r requirements.txt
```

Set the database connection:

```bash
export DATABASE_URL="dbname=gigtask user=YOUR_POSTGRES_USER host=localhost port=5432"
```

Run all SQL files in order:

```bash
psql gigtask -f sql/01_schema_ddl.sql
psql gigtask -f sql/02_indexes.sql
psql gigtask -f sql/03_triggers_and_audit.sql
psql gigtask -f sql/04_stored_procedures.sql
psql gigtask -f sql/05_materialized_views.sql
psql gigtask -f sql/06_window_analytics.sql
```

Generate PostgreSQL data:

```bash
python3 data_generation/postgres_seeder.py
```

---

## 15. MongoDB Setup

Start MongoDB according to your operating system.

Check the connection:

```bash
mongosh --eval 'db.runCommand({ ping: 1 })'
```

Create the collections and indexes:

```bash
mongosh gigtask mongo/01_collections_and_indexes.js
```

Generate worker location data:

```bash
python3 data_generation/mongo_seeder.py
```

Run Workflow 3:

```bash
mongosh gigtask mongo/02_workflow3_geonear.js
```

Run Workflow 4:

```bash
mongosh gigtask mongo/03_workflow4_facet.js
```

---

# Performance Proof

## 16. PostgreSQL Performance Testing

PostgreSQL performance was tested using:

```sql
EXPLAIN (ANALYZE, BUFFERS)
```

### Completed Contract Lookup

```text
Execution Time: 4.227 ms
```

The query uses:

```text
idx_contracts_completed_freelancer
```

### Active Gig Lookup

```text
Execution Time: 0.222 ms
```

The query uses:

```text
idx_active_gig
```

### Wallet Audit Lookup

```text
Execution Time: 1.348 ms
```

The query uses:

```text
idx_audit_client_created
```

### Materialized View Lookup

```text
Execution Time: 1.898 ms
```

The materialized view contains 5,000 freelancer rows.

The detailed performance evidence is available in:

```text
performance/README.md
```

---

## 17. Verification Checklist

### PostgreSQL

```sql
SELECT COUNT(*) FROM clients;
SELECT COUNT(*) FROM freelancers;
SELECT COUNT(*) FROM contracts;
SELECT COUNT(*) FROM wallet_audit_logs;
```

Check materialized view:

```sql
SELECT *
FROM freelancer_lifetime_stats
ORDER BY total_earnings DESC
LIMIT 10;
```

Check indexes:

```sql
SELECT indexname, indexdef
FROM pg_indexes
WHERE tablename IN (
    'clients',
    'freelancers',
    'contracts',
    'wallet_audit_logs'
);
```

### MongoDB

```javascript
use gigtask

db.Portfolios.countDocuments()
db.GigReviews.countDocuments()
db.WorkerLocations.countDocuments()

db.WorkerLocations.getIndexes()
```

---

## 18. Quick Demo

If PostgreSQL, MongoDB, and dependencies are already installed:

### PostgreSQL

```bash
source venv/bin/activate

export DATABASE_URL="dbname=gigtask user=YOUR_POSTGRES_USER host=localhost port=5432"

python3 data_generation/postgres_seeder.py
```

### MongoDB

```bash
mongosh gigtask mongo/01_collections_and_indexes.js
python3 data_generation/mongo_seeder.py
mongosh gigtask mongo/02_workflow3_geonear.js
mongosh gigtask mongo/03_workflow4_facet.js
```

---

## 19. Repository Structure

```text
GigTask/
├── README.md
├── requirements.txt
├── .gitignore
│
├── docs/
│   ├── relational_erd.png
│   └── mongo_schema_map.json
│
├── sql/
│   ├── 01_schema_ddl.sql
│   ├── 02_indexes.sql
│   ├── 03_triggers_and_audit.sql
│   ├── 04_stored_procedures.sql
│   ├── 05_materialized_views.sql
│   └── 06_window_analytics.sql
│
├── mongo/
│   ├── 01_collections_and_indexes.js
│   ├── 02_workflow3_geonear.js
│   └── 03_workflow4_facet.js
│
├── data_generation/
│   ├── postgres_seeder.py
│   └── mongo_seeder.py
│
└── performance/
    └── README.md
```

---

## 20. Important Notes

- Run PostgreSQL SQL scripts in numerical order.
- The PostgreSQL seeder creates approximately 50,000 contracts and 100,000 audit records.
- The MongoDB location seeder targets approximately 500,000 location documents.
- Worker location documents expire automatically after two hours because of the TTL index.
- Therefore, the exact `WorkerLocations` count may fluctuate.
- The `2dsphere` index is required for `$geoNear`.
- The `fund_gig` procedure should be called directly because it manages its own transaction boundary.
- `06_window_analytics.sql` is an analytics query; it does not create a permanent table or view.
- Generated databases and large raw datasets are not stored in GitHub.
