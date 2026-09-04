# GigTask – Freelance Micro-Jobs Marketplace

A database implementation of a freelance micro-jobs marketplace using PostgreSQL and MongoDB.

The project demonstrates transactional gig funding, escrow auditing, indexing, materialized views, SQL window analytics, MongoDB geospatial search, faceted review analytics, TTL indexes, and large-scale test data generation.

---

## 1. Project Overview

GigTask models a freelance marketplace where:

- Clients maintain escrow balances.
- Freelancers can accept gigs.
- Contracts connect clients and freelancers.
- Escrow changes are automatically audited.
- Completed contracts are used for lifetime earnings analytics.
- MongoDB stores flexible portfolio/review data and real-time worker locations.
- Geospatial queries find nearby available freelancers.

---

## 2. Tech Stack

- PostgreSQL 16
- MongoDB
- Python 3
- SQL
- MongoDB Shell (`mongosh`)

---

## 3. Prerequisites

Install the following before running the project:

- PostgreSQL 16
- MongoDB
- Python 3
- `mongosh`
- Git

Make sure PostgreSQL and MongoDB are running.

---

## 4. Installation and Setup

Run all commands from the repository root.

### 4.1 Clone the Repository

```bash
git clone https://github.com/DEVA982/fake_to_test.git
cd fake_to_test
```

### 4.2 Create PostgreSQL Database

```bash
createdb gigtask
```

### 4.3 Create Python Virtual Environment

```bash
python3 -m venv venv
source venv/bin/activate
```

### 4.4 Install Python Dependencies

```bash
python3 -m pip install -r requirements.txt
```

### 4.5 Configure PostgreSQL Connection

Replace `YOUR_POSTGRES_USER` with your local PostgreSQL username:

```bash
export DATABASE_URL="dbname=gigtask user=YOUR_POSTGRES_USER host=localhost port=5432"
```

### 4.6 Create PostgreSQL Schema

Run the SQL files in order:

```bash
psql gigtask -f sql/01_schema_ddl.sql
psql gigtask -f sql/02_indexes.sql
psql gigtask -f sql/03_triggers_and_audit.sql
psql gigtask -f sql/04_stored_procedures.sql
psql gigtask -f sql/05_materialized_views.sql
psql gigtask -f sql/06_window_analytics.sql
```

### 4.7 Generate PostgreSQL Data

```bash
python3 data_generation/postgres_seeder.py
```

Expected approximate dataset:

```text
clients             1,000
freelancers         5,000
contracts          50,000
wallet_audit_logs 100,000
```

### 4.8 Start MongoDB

Start MongoDB using the method appropriate for your operating system.

Check the connection:

```bash
mongosh --eval 'db.runCommand({ ping: 1 })'
```

### 4.9 Create MongoDB Collections and Indexes

```bash
mongosh gigtask mongo/01_collections_and_indexes.js
```

### 4.10 Generate MongoDB Data

```bash
python3 data_generation/mongo_seeder.py
```

The location seeder generates approximately 500,000 worker-location documents.

---

## 5. Project Structure

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

# PostgreSQL

## 6. PostgreSQL Schema

**File:** `sql/01_schema_ddl.sql`

This script creates the core relational schema.

### Main Tables

- `clients` — stores client information and escrow balances.
- `freelancers` — stores freelancer information, location, and availability.
- `contracts` — stores gigs between clients and freelancers.
- `wallet_audit_logs` — stores audit records for escrow balance changes.

### Key Features

- UUID primary keys.
- Foreign-key relationships.
- Non-negative escrow balance constraint.
- Contract budget and status.
- Contract timestamps.
- Supporting indexes.

### Execute

```bash
psql gigtask -f sql/01_schema_ddl.sql
```

---

## 7. PostgreSQL Indexing

**File:** `sql/02_indexes.sql`

This script creates indexes for performance and business-rule enforcement.

### Active Gig Partial Unique Index

The partial unique index prevents a freelancer from having more than one `IN PROGRESS` contract:

```sql
CREATE UNIQUE INDEX idx_active_gig
ON contracts(freelancer_id)
WHERE status = 'IN PROGRESS';
```

### Additional Indexes

Indexes are created for:

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

## 8. PostgreSQL Trigger and Audit Logging

**File:** `sql/03_triggers_and_audit.sql`

This script implements automatic auditing of escrow balance changes.

### Trigger

The trigger fires when a client's `escrow_balance` is inserted or updated.

The audit record contains:

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

## 9. Atomic Gig Funding – Stored Procedure

**File:** `sql/04_stored_procedures.sql`

This script creates the `fund_gig` PostgreSQL procedure.

### Call the Procedure

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
6. Deducts the budget from escrow.
7. Creates a contract with status `FUNDED`.
8. Commits the transaction.

### Execute

```bash
psql gigtask -f sql/04_stored_procedures.sql
```

> Call `fund_gig` directly. Do not wrap the procedure call inside an explicit `BEGIN`/`COMMIT` block.

---

## 10. Materialized View

**File:** `sql/05_materialized_views.sql`

This script creates:

```text
freelancer_lifetime_stats
```

### Purpose

The materialized view stores precomputed freelancer lifetime statistics based on completed contracts.

### Statistics

- Freelancer ID.
- Freelancer name.
- Completed contract count.
- Total lifetime earnings.

### Refresh

```sql
CALL refresh_freelancer_lifetime_stats();
```

The refresh uses:

```sql
REFRESH MATERIALIZED VIEW CONCURRENTLY freelancer_lifetime_stats;
```

A unique index on `freelancer_id` supports concurrent refresh.

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

## 11. SQL Window Analytics

**File:** `sql/06_window_analytics.sql`

This script performs revenue trend analysis using CTEs and SQL window functions.

### Daily Revenue

Completed contracts are grouped by freelancer and date to calculate daily revenue.

### Seven-Day Moving Average

The moving average is calculated using:

```sql
AVG(daily_revenue) OVER (
    PARTITION BY freelancer_id
    ORDER BY revenue_day
    RANGE BETWEEN INTERVAL '6 days' PRECEDING
          AND CURRENT ROW
)
```

### Freelancer Ranking

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

The query prints the analytics result directly.

---

# MongoDB

## 12. MongoDB Collections and Indexes

**File:** `mongo/01_collections_and_indexes.js`

This script creates:

- `Portfolios`
- `GigReviews`
- `WorkerLocations`

### Worker Location Index

Worker locations use GeoJSON and a `2dsphere` index:

```javascript
db.WorkerLocations.createIndex({
    location: "2dsphere"
});
```

### Two-Hour TTL Index

Location records automatically expire after two hours:

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

## 13. MongoDB Data Generation

**File:** `data_generation/mongo_seeder.py`

The MongoDB seeder generates approximately 500,000 worker-location documents.

The TTL index removes documents older than two hours, so the exact collection count can fluctuate.

### Run

```bash
source venv/bin/activate
python3 data_generation/mongo_seeder.py
```

### Verify Counts

```bash
mongosh gigtask
```

```javascript
db.Portfolios.countDocuments()
db.GigReviews.countDocuments()
db.WorkerLocations.countDocuments()
```

---

## 14. Workflow 3 – `$geoNear`

**File:** `mongo/02_workflow3_geonear.js`

This workflow finds the nearest available worker using MongoDB `$geoNear`.

### Search Location

```text
Longitude: 78.4867
Latitude: 17.3850
```

The workflow:

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

## 15. Workflow 4 – `$facet`

**File:** `mongo/03_workflow4_facet.js`

This workflow uses `$facet` to perform multiple review analyses in one aggregation pipeline.

### Rating Distribution

Groups reviews by rating and counts the number of reviews for each rating.

### Top Skill Tags

Uses `$unwind` on `skill_tags` and calculates:

- Number of reviews per skill.
- Average rating per skill.

### Overall Worker Ratings

Groups reviews by freelancer and calculates:

- Average rating.
- Review count.

### Run

```bash
mongosh gigtask mongo/03_workflow4_facet.js
```

---

# Verification

## 16. PostgreSQL Verification

### Check Dataset Size

```sql
SELECT COUNT(*) FROM clients;
SELECT COUNT(*) FROM freelancers;
SELECT COUNT(*) FROM contracts;
SELECT COUNT(*) FROM wallet_audit_logs;
```

### Check Materialized View

```sql
SELECT *
FROM freelancer_lifetime_stats
ORDER BY total_earnings DESC
LIMIT 10;
```

### Check PostgreSQL Indexes

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

---

## 17. MongoDB Verification

### Check Dataset Size

```javascript
use gigtask

db.Portfolios.countDocuments()
db.GigReviews.countDocuments()
db.WorkerLocations.countDocuments()
```

### Check Worker Location Indexes

```javascript
db.WorkerLocations.getIndexes()
```

### Test GeoNear

```bash
mongosh gigtask mongo/02_workflow3_geonear.js
```

### Test Facet Analytics

```bash
mongosh gigtask mongo/03_workflow4_facet.js
```

---

# Performance

## 18. PostgreSQL Performance Testing

Performance testing was performed using:

```sql
EXPLAIN (ANALYZE, BUFFERS)
```

### Completed Contract Lookup

```text
Execution Time: 4.227 ms
```

Index used:

```text
idx_contracts_completed_freelancer
```

### Active Gig Lookup

```text
Execution Time: 0.222 ms
```

Index used:

```text
idx_active_gig
```

### Wallet Audit Lookup

```text
Execution Time: 1.348 ms
```

Index used:

```text
idx_audit_client_created
```

### Materialized View Lookup

```text
Execution Time: 1.898 ms
```

The detailed performance information is available in:

```text
performance/README.md
```

---

## 19. Performance Summary

| Workload | Execution Time |
|---|---:|
| Completed contract lookup | 4.227 ms |
| Active gig lookup | 0.222 ms |
| Wallet audit lookup | 1.348 ms |
| Materialized view lookup | 1.898 ms |

---

# Quick Demo

## 20. Run the Main Workflows

After completing the setup:

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

# Notes

## 21. Important Notes

- Run PostgreSQL SQL scripts in numerical order.
- The PostgreSQL seeder generates approximately 50,000 contracts and 100,000 wallet audit records.
- The MongoDB location seeder targets approximately 500,000 location documents.
- Worker location documents expire automatically after two hours.
- Therefore, the `WorkerLocations` count can fluctuate.
- The `2dsphere` index is required for `$geoNear`.
- The `fund_gig` procedure should be called directly because it manages its own transaction boundary.
- `06_window_analytics.sql` is an analytics query and does not create a permanent table or view.
- Generated databases and large raw datasets are not stored in GitHub.
