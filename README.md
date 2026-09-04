# GigTask — Complete Setup, Run & Verification Guide

This README is the **step-by-step evaluator guide** for the GigTask database assignment.

A person who clones this GitHub repository should be able to:

1. Clone the repository.
2. Install dependencies.
3. Create and configure PostgreSQL.
4. Create the PostgreSQL schema, indexes, trigger, procedures and materialized view.
5. Generate the required PostgreSQL data at scale.
6. Run and verify PostgreSQL Workflow 1 and Workflow 2.
7. Configure MongoDB.
8. Create MongoDB collections/indexes.
9. Generate the required MongoDB data at scale.
10. Run and verify MongoDB Workflow 3 and Workflow 4.
11. Check all assignment requirements.
12. Check the performance evidence files.

---

# 1. Assignment Workflow Mapping

These are the four required complex workflows and the exact files that implement them.

| Workflow | Assignment requirement | File | Database |
|---|---|---|---|
| Workflow 1 | Atomic Gig Funding using PL/pgSQL stored procedure | `sql/04_stored_procedures.sql` | PostgreSQL |
| Workflow 2 | 7-day moving average using CTEs/window functions and `DENSE_RANK()` | `sql/06_window_analytics.sql` | PostgreSQL |
| Workflow 3 | Nearest available worker using `$geoNear` | `mongo/02_workflow3_geonear.js` | MongoDB |
| Workflow 4 | Multi-faceted review analytics using `$facet` and `$unwind` | `mongo/03_workflow4_facet.js` | MongoDB |

---

# 2. Repository Structure

```text
GigTask/
├── README.md
├── requirements.txt
│
├── data_generation/
│   ├── postgres_seeder.py
│   └── mongo_seeder.py
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
├── performance/
│   ├── postgres_explain_analyzes.txt
│   └── mongo_execution_stats.json
│
└── docs/
```

---

# 3. Prerequisites

Install the following before starting:

```text
Git
Python 3
pip
PostgreSQL
MongoDB
mongosh
```

Check:

```bash
git --version
python3 --version
pip --version
psql --version
mongosh --version
```

Start PostgreSQL and MongoDB using the normal service method for your operating system.

---

# 4. Clone the GitHub Repository

Replace the repository URL with the actual GitHub repository URL.

```bash
git clone <YOUR_GITHUB_REPOSITORY_URL>
```

Enter the project:

```bash
cd GigTask
```

Check:

```bash
ls
```

You should see directories such as:

```text
data_generation
mongo
performance
sql
docs
```

---

# 5. Create Python Virtual Environment

From the project root:

```bash
python3 -m venv venv
```

Activate it on macOS/Linux:

```bash
source venv/bin/activate
```

On Windows:

```powershell
venv\Scripts\activate
```

Install dependencies:

```bash
pip install -r requirements.txt
```

---

# 6. PostgreSQL — Create Database

If the database does not already exist:

```bash
createdb gigtask
```

Alternative:

```bash
psql postgres
```

Then:

```sql
CREATE DATABASE gigtask;
\q
```

---

# 7. PostgreSQL — Configure Connection

For a local PostgreSQL installation:

```bash
export DATABASE_URL="dbname=gigtask user=$USER host=localhost port=5432"
```

If the PostgreSQL username is different:

```bash
export DATABASE_URL="dbname=gigtask user=<YOUR_POSTGRES_USER> host=localhost port=5432"
```

Test the connection:

```bash
psql "$DATABASE_URL"
```

Expected prompt:

```text
gigtask=#
```

Exit:

```sql
\q
```

## Important

Commands such as:

```sql
SELECT ...
CALL ...
CREATE ...
```

must be run inside `psql`, where the prompt looks like:

```text
gigtask=#
```

Do not run PostgreSQL SQL directly at the normal terminal prompt.

---

# 8. PostgreSQL — Create Tables

Run from the repository root:

```bash
psql "$DATABASE_URL" -f sql/01_schema_ddl.sql
```

This creates:

```text
clients
freelancers
contracts
wallet_audit_logs
```

---

# 9. PostgreSQL — Create Required Indexes

Run:

```bash
psql "$DATABASE_URL" -f sql/02_indexes.sql
```

Important index:

```sql
CREATE UNIQUE INDEX idx_active_gig
ON contracts(freelancer_id)
WHERE status = 'IN PROGRESS';
```

This is the required partial unique index for active gigs.

---

# 10. PostgreSQL — Create Escrow Audit Trigger

Run:

```bash
psql "$DATABASE_URL" -f sql/03_triggers_and_audit.sql
```

This creates:

```text
log_escrow_change()
trg_escrow_audit
```

Verify:

```bash
psql "$DATABASE_URL"
```

```sql
SELECT n.nspname AS schema_name,
       c.relname AS table_name,
       t.tgname AS trigger_name
FROM pg_trigger t
JOIN pg_class c ON c.oid = t.tgrelid
JOIN pg_namespace n ON n.oid = c.relnamespace
WHERE NOT t.tgisinternal
  AND t.tgname = 'trg_escrow_audit';
```

Expected:

```text
public | clients | trg_escrow_audit
```

Exit:

```sql
\q
```

---

# 11. PostgreSQL — Create Workflow 1 Stored Procedure

Run:

```bash
psql "$DATABASE_URL" -f sql/04_stored_procedures.sql
```

Verify:

```bash
psql "$DATABASE_URL"
```

```sql
SELECT routine_name, routine_type
FROM information_schema.routines
WHERE routine_name = 'fund_gig';
```

Expected:

```text
fund_gig | PROCEDURE
```

---

# 12. PostgreSQL — Create Materialized View

Run:

```bash
psql "$DATABASE_URL" -f sql/05_materialized_views.sql
```

This creates:

```text
freelancer_lifetime_stats
```

and:

```text
refresh_freelancer_lifetime_stats()
```

After data generation, refresh it:

```sql
CALL refresh_freelancer_lifetime_stats();
```

Verify:

```sql
SELECT *
FROM freelancer_lifetime_stats
ORDER BY total_earnings DESC
LIMIT 5;
```

---

# 13. PostgreSQL — Generate Required Data

The PostgreSQL generator is:

```text
data_generation/postgres_seeder.py
```

The default targets in the script are:

```text
CLIENTS     = 1000
FREELANCERS = 5000
CONTRACTS   = 50000
```

The script also fills `wallet_audit_logs` to at least:

```text
100000
```

Run:

```bash
python3 data_generation/postgres_seeder.py
```

The script uses the `DATABASE_URL` environment variable.

---

# 14. PostgreSQL — Verify Data Scale

Open PostgreSQL:

```bash
psql "$DATABASE_URL"
```

Run:

```sql
SELECT COUNT(*) AS clients
FROM clients;

SELECT COUNT(*) AS freelancers
FROM freelancers;

SELECT COUNT(*) AS contracts
FROM contracts;

SELECT COUNT(*) AS audit_logs
FROM wallet_audit_logs;
```

Required minimums:

```text
contracts   >= 50000
audit_logs  >= 100000
```

Expected project-scale data:

```text
clients              1000
freelancers          5000
contracts           50000
wallet_audit_logs   100000
```

---

# 15. WORKFLOW 1 — Atomic Gig Funding

## Requirement

The assignment asks for:

> A PL/pgSQL Stored Procedure that safely deducts client funds into escrow, creates a contract, and commits atomically.

## Implementation

File:

```text
sql/04_stored_procedures.sql
```

Procedure:

```text
fund_gig(...)
```

The procedure validates the request, locks the client row, checks the balance, deducts the budget, and inserts a `FUNDED` contract.

## Verify the Procedure

Inside `psql`:

```sql
SELECT routine_name, routine_type
FROM information_schema.routines
WHERE routine_name = 'fund_gig';
```

Expected:

```text
fund_gig | PROCEDURE
```

## Run a Real Test

Get one client:

```sql
SELECT id, escrow_balance
FROM clients
LIMIT 1;
```

Get one freelancer:

```sql
SELECT id, name
FROM freelancers
LIMIT 1;
```

Use the returned IDs:

```sql
CALL fund_gig(
    '<CLIENT_ID>',
    '<FREELANCER_ID>',
    100.00
);
```

Expected:

```text
CALL
```

Verify the client balance:

```sql
SELECT escrow_balance
FROM clients
WHERE id = '<CLIENT_ID>';
```

The balance should decrease by:

```text
100.00
```

Verify the contract:

```sql
SELECT client_id,
       freelancer_id,
       budget,
       status
FROM contracts
WHERE client_id = '<CLIENT_ID>'
  AND freelancer_id = '<FREELANCER_ID>'
ORDER BY created_at DESC
LIMIT 1;
```

Expected:

```text
budget | 100.00
status | FUNDED
```

Verify the audit record:

```sql
SELECT client_id,
       amount_changed,
       action_type,
       balance_after,
       created_at
FROM wallet_audit_logs
WHERE client_id = '<CLIENT_ID>'
ORDER BY created_at DESC
LIMIT 5;
```

### Workflow 1 Pass

```text
[ ] fund_gig procedure exists
[ ] CALL executes
[ ] escrow balance decreases
[ ] FUNDED contract is created
[ ] audit entry is visible
```

---

# 16. WORKFLOW 2 — SQL Window Analytics

## Requirement

The assignment asks for:

> CTEs and Window Functions to compute the 7-day moving average of contract revenue per freelancer, ranked by `DENSE_RANK()`.

## Implementation

File:

```text
sql/06_window_analytics.sql
```

The implementation uses:

```text
daily_revenue CTE
moving CTE
latest CTE
AVG(...) OVER(...)
PARTITION BY freelancer_id
RANGE BETWEEN INTERVAL '6 days' PRECEDING AND CURRENT ROW
DENSE_RANK() OVER(...)
```

## Run

From the repository root:

```bash
psql "$DATABASE_URL" -f sql/06_window_analytics.sql
```

Expected columns:

```text
freelancer_id
revenue_day
moving_average_7d
freelancer_rank
```

Example result format:

```text
freelancer_id | revenue_day | moving_average_7d | freelancer_rank
--------------+-------------+-------------------+----------------
...           | 2026-...    | 10121.31          | 1
...           | 2026-...    |  9081.67          | 2
...           | 2026-...    |  8989.38          | 3
```

### Workflow 2 Pass

```text
[ ] CTEs are used
[ ] Daily completed-contract revenue is calculated
[ ] 7-day moving average is calculated
[ ] Per-freelancer partition is used
[ ] DENSE_RANK() is used
[ ] Query returns results
```

---

# 17. MongoDB — Select Database

Start MongoDB shell:

```bash
mongosh
```

Select:

```javascript
use("gigtask");
```

Expected:

```text
switched to db gigtask
```

---

# 18. MongoDB — Create Collections and Indexes

File:

```text
mongo/01_collections_and_indexes.js
```

Run:

```javascript
load("mongo/01_collections_and_indexes.js");
```

Check WorkerLocations indexes:

```javascript
db.WorkerLocations.getIndexes();
```

The required geospatial index is:

```text
location_2dsphere
```

The required TTL behavior is:

```text
created_at
expireAfterSeconds: 7200
```

7200 seconds = 2 hours.

Check review indexes:

```javascript
db.GigReviews.getIndexes();
```

---

# 19. MongoDB — Generate Required Data

The MongoDB generator is:

```text
data_generation/mongo_seeder.py
```

Run from the project root:

```bash
python3 data_generation/mongo_seeder.py
```

Verify WorkerLocations count:

```bash
mongosh
```

```javascript
use("gigtask");

db.WorkerLocations.countDocuments();
```

Required:

```text
>= 500000
```

The target project scale is:

```text
500000 WorkerLocations
```

---

# 20. WORKFLOW 3 — Nearest Available Worker

## Requirement

The assignment asks for:

> A `$geoNear` pipeline to find the closest available freelancer to a physical job site.

## Implementation

File:

```text
mongo/02_workflow3_geonear.js
```

The pipeline uses:

```text
$geoNear
location
distanceMeters
spherical: true
is_available: true
```

## Run

From `mongosh`:

```javascript
use("gigtask");
load("mongo/02_workflow3_geonear.js");
```

The output should show nearby workers and their distance.

Expected fields include:

```text
freelancer_id
distanceMeters
location
created_at
```

## Verify Geospatial Index

```javascript
db.WorkerLocations.getIndexes();
```

Confirm:

```text
location_2dsphere
```

### Workflow 3 Pass

```text
[ ] $geoNear is used
[ ] location is the geospatial field
[ ] available workers are filtered
[ ] distance is returned
[ ] location_2dsphere index exists
[ ] script executes successfully
```

---

# 21. WORKFLOW 4 — Multi-Faceted Review Analytics

## Requirement

The assignment asks for:

> A `$facet` pipeline extracting rating distributions, top skill-tags via `$unwind`, and overall worker ratings.

## Implementation

File:

```text
mongo/03_workflow4_facet.js
```

The three facet branches are:

```text
rating_distribution
top_skill_tags
overall_worker_ratings
```

The top skill-tag branch uses:

```text
$unwind: "$skill_tags"
```

## Run

From `mongosh`:

```javascript
use("gigtask");
load("mongo/03_workflow4_facet.js");
```

The output should contain all three sections.

### Rating Distribution

Groups reviews by rating and counts them.

### Top Skill Tags

Uses `$unwind` on `skill_tags`, groups tags, calculates usage and average rating, sorts them, and returns the top tags.

### Overall Worker Ratings

Groups reviews by freelancer and calculates:

```text
average_rating
review_count
```

### Workflow 4 Pass

```text
[ ] $facet is used
[ ] rating_distribution exists
[ ] $unwind is used on skill_tags
[ ] top_skill_tags exists
[ ] overall_worker_ratings exists
[ ] script executes successfully
```

---

# 22. PostgreSQL — Verify All Engineering Requirements

Open:

```bash
psql "$DATABASE_URL"
```

## Trigger

```sql
SELECT n.nspname AS schema_name,
       c.relname AS table_name,
       t.tgname AS trigger_name
FROM pg_trigger t
JOIN pg_class c ON c.oid = t.tgrelid
JOIN pg_namespace n ON n.oid = c.relnamespace
WHERE NOT t.tgisinternal
  AND t.tgname = 'trg_escrow_audit';
```

Expected:

```text
public | clients | trg_escrow_audit
```

## Partial Unique Index

```sql
SELECT indexname, indexdef
FROM pg_indexes
WHERE indexname = 'idx_active_gig';
```

The definition must contain:

```text
UNIQUE
```

and:

```text
WHERE status = 'IN PROGRESS'
```

## Completed-Contract Index

```sql
SELECT indexname, indexdef
FROM pg_indexes
WHERE indexname = 'idx_contracts_completed_freelancer';
```

## Freelancer Availability Index

```sql
SELECT indexname, indexdef
FROM pg_indexes
WHERE indexname = 'idx_freelancers_available';
```

## Materialized View

```sql
SELECT COUNT(*)
FROM freelancer_lifetime_stats;
```

Sample:

```sql
SELECT *
FROM freelancer_lifetime_stats
ORDER BY total_earnings DESC
LIMIT 5;
```

## Concurrent Refresh

```sql
CALL refresh_freelancer_lifetime_stats();
```

---

# 23. MongoDB — Verify All Engineering Requirements

Open:

```bash
mongosh
```

Then:

```javascript
use("gigtask");
```

## WorkerLocations Scale

```javascript
db.WorkerLocations.countDocuments();
```

Required:

```text
>= 500000
```

## WorkerLocations Indexes

```javascript
db.WorkerLocations.getIndexes();
```

Required:

```text
location_2dsphere
created_at TTL
expireAfterSeconds: 7200
```

## Portfolios

```javascript
db.Portfolios.countDocuments();
```

## GigReviews

```javascript
db.GigReviews.countDocuments();
```

## GigReviews Indexes

```javascript
db.GigReviews.getIndexes();
```

---

# 24. Performance Evidence

The submission contains exactly these two performance files:

```text
performance/postgres_explain_analyzes.txt
performance/mongo_execution_stats.json
```

## PostgreSQL

Actual PostgreSQL plans should be collected with:

```sql
EXPLAIN (ANALYZE, BUFFERS)
<QUERY>;
```

The actual output belongs in:

```text
performance/postgres_explain_analyzes.txt
```

Do not fabricate execution times or plan operators.

A sequential scan is not automatically a failure. Report the actual PostgreSQL plan produced by the database.

## MongoDB

Actual MongoDB execution evidence should be collected with:

```javascript
db.<collection>.explain("executionStats").aggregate([
    // workflow pipeline
]);
```

The actual evidence belongs in:

```text
performance/mongo_execution_stats.json
```

For Workflow 3, important plan evidence includes:

```text
GEO_NEAR_2DSPHERE
IXSCAN
location_2dsphere
```

Do not invent:

```text
executionTimeMillis
totalKeysExamined
totalDocsExamined
```

---

# 25. Exact Evaluator Run Order

A clean-clone evaluator can follow this order:

```text
1. git clone <YOUR_GITHUB_REPOSITORY_URL>
2. cd GigTask
3. python3 -m venv venv
4. source venv/bin/activate
5. pip install -r requirements.txt
6. Create PostgreSQL database gigtask
7. export DATABASE_URL="..."
8. psql "$DATABASE_URL" -f sql/01_schema_ddl.sql
9. psql "$DATABASE_URL" -f sql/02_indexes.sql
10. psql "$DATABASE_URL" -f sql/03_triggers_and_audit.sql
11. psql "$DATABASE_URL" -f sql/04_stored_procedures.sql
12. psql "$DATABASE_URL" -f sql/05_materialized_views.sql
13. python3 data_generation/postgres_seeder.py
14. Verify PostgreSQL counts
15. Test Workflow 1
16. Run Workflow 2
17. Start MongoDB
18. mongosh
19. use("gigtask")
20. load("mongo/01_collections_and_indexes.js")
21. python3 data_generation/mongo_seeder.py
22. Verify MongoDB counts
23. Run Workflow 3
24. Run Workflow 4
25. Verify PostgreSQL indexes/trigger/view
26. Verify MongoDB indexes
27. Check performance/postgres_explain_analyzes.txt
28. Check performance/mongo_execution_stats.json
```

---

# 26. Final Assignment Checklist

## Data Generation

```text
[ ] PostgreSQL >= 50,000 contracts
[ ] PostgreSQL >= 100,000 audit/ledger entries
[ ] MongoDB >= 500,000 WorkerLocations pings
```

## Workflow 1 — Atomic Gig Funding

```text
[ ] PL/pgSQL procedure exists
[ ] Client balance is safely checked
[ ] Client row is locked
[ ] Funds are deducted
[ ] FUNDED contract is created
[ ] Audit entry is generated
[ ] Operation is atomic
```

## Workflow 2 — SQL Window Analytics

```text
[ ] CTEs
[ ] Daily revenue
[ ] 7-day moving average
[ ] Window function
[ ] Per-freelancer partition
[ ] DENSE_RANK()
```

## Workflow 3 — Nearest Available Worker

```text
[ ] $geoNear
[ ] GeoJSON Point
[ ] Available-worker filtering
[ ] Distance calculation
[ ] 2dsphere index
```

## Workflow 4 — Multi-Faceted Review Analytics

```text
[ ] $facet
[ ] Rating distribution
[ ] $unwind skill_tags
[ ] Top skill tags
[ ] Overall worker ratings
```

## PostgreSQL Engineering

```text
[ ] Escrow audit trigger
[ ] Partial unique active-gig index
[ ] Completed-contract index
[ ] Freelancer availability index
[ ] Materialized view
[ ] Unique index on materialized view
[ ] Concurrent refresh procedure
```

## MongoDB Engineering

```text
[ ] Portfolios collection
[ ] GigReviews collection
[ ] WorkerLocations collection
[ ] 2dsphere index
[ ] 2-hour TTL
[ ] Review indexes
```

## Performance

```text
[ ] performance/postgres_explain_analyzes.txt
[ ] performance/mongo_execution_stats.json
[ ] Actual execution evidence
[ ] No fabricated metrics
```

---

# 27. Important Terminal / Database Prompt Difference

## Terminal

Looks like:

```text
Dev-MacBook:GigTask user$
```

Use:

```bash
cd
python3
pip
psql
mongosh
```

## PostgreSQL

Looks like:

```text
gigtask=#
```

Use:

```sql
SELECT ...
CALL ...
CREATE ...
EXPLAIN ...
```

## MongoDB

Looks like:

```text
gigtask>
```

Use:

```javascript
db.WorkerLocations.countDocuments()
db.GigReviews.getIndexes()
load("mongo/02_workflow3_geonear.js")
```

This distinction is important when following the commands in this README.

---

# 28. Definition of Done

The GitHub project is ready for evaluation when the evaluator can clone it and successfully verify all of the following:

```text
[x] PostgreSQL data-scale requirement
[x] MongoDB data-scale requirement
[x] Workflow 1 — Atomic Gig Funding
[x] Workflow 2 — SQL Window Analytics
[x] Workflow 3 — Nearest Available Worker
[x] Workflow 4 — Multi-Faceted Review Analytics
[x] PostgreSQL trigger
[x] PostgreSQL partial unique index
[x] PostgreSQL materialized view
[x] MongoDB 2dsphere index
[x] MongoDB 2-hour TTL
[x] Performance evidence files
```

The `[x]` marks above are the final target state. The evaluator should verify each item by running the commands in this README.
