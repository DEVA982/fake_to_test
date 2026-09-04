# GigTask — Complete Setup, Workflow Demo & Verification Guide

This README is written for an evaluator who has **only the GitHub repository** and wants to run the project from start to finish.

The four assignment workflows are explicitly mapped below to the exact source files and commands.

---

# 1. Assignment Workflows — Where They Are Implemented

| Workflow | Requirement | Implementation file | Database |
|---|---|---|---|
| **Workflow 1** | Atomic Gig Funding using PL/pgSQL stored procedure | `sql/04_stored_procedures.sql` | PostgreSQL |
| **Workflow 2** | 7-day moving average using CTEs/window functions + `DENSE_RANK()` | `sql/06_window_analytics.sql` | PostgreSQL |
| **Workflow 3** | Find nearest available worker using `$geoNear` | `mongo/02_workflow3_geonear.js` | MongoDB |
| **Workflow 4** | `$facet` with rating distribution, `$unwind` top skill tags, worker ratings | `mongo/03_workflow4_facet.js` | MongoDB |

The evaluator should not have to guess which file implements which requirement.

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
├── mongo/
│   ├── 01_collections_and_indexes.js
│   ├── 02_workflow3_geonear.js
│   └── 03_workflow4_facet.js
│
├── sql/
│   ├── 01_schema_ddl.sql
│   ├── 02_indexes.sql
│   ├── 03_triggers_and_audit.sql
│   ├── 04_stored_procedures.sql
│   ├── 05_materialized_views.sql
│   └── 06_window_analytics.sql
│
├── performance/
│   ├── postgres_explain_analyzes.txt
│   └── mongo_execution_stats.json
│
└── docs/
```

---

# 3. Prerequisites

Install:

```text
Git
Python 3
PostgreSQL
MongoDB
mongosh
```

Check:

```bash
git --version
python3 --version
psql --version
mongosh --version
```

---

# 4. Clone and Enter the Project

```bash
git clone <YOUR_GITHUB_REPOSITORY_URL>
cd GigTask
```

Verify:

```bash
ls
```

---

# 5. Python Setup

Create virtual environment:

```bash
python3 -m venv venv
```

Activate:

```bash
source venv/bin/activate
```

Install dependencies:

```bash
pip install -r requirements.txt
```

---

# 6. PostgreSQL Setup

## 6.1 Create Database

If `gigtask` does not exist:

```bash
createdb gigtask
```

Or:

```bash
psql postgres
```

Then:

```sql
CREATE DATABASE gigtask;
\q
```

---

## 6.2 Set Connection

Example for a local PostgreSQL user:

```bash
export DATABASE_URL="dbname=gigtask user=$USER host=localhost port=5432"
```

If the PostgreSQL username is different:

```bash
export DATABASE_URL="dbname=gigtask user=<YOUR_POSTGRES_USER> host=localhost port=5432"
```

Test:

```bash
psql "$DATABASE_URL"
```

The prompt should become:

```text
gigtask=#
```

Exit:

```sql
\q
```

> **Important:** `SELECT` and `CALL` are PostgreSQL commands. They must be run after the `gigtask=#` prompt appears, not directly in the macOS/Linux terminal.

---

# 7. Create PostgreSQL Tables

Run from the project root:

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

# 8. Create PostgreSQL Indexes

```bash
psql "$DATABASE_URL" -f sql/02_indexes.sql
```

Important index:

```sql
CREATE UNIQUE INDEX idx_active_gig
ON contracts(freelancer_id)
WHERE status = 'IN PROGRESS';
```

This is the required partial unique index preventing a freelancer from having multiple active gigs.

---

# 9. Create Escrow Audit Trigger

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

# 10. Create Workflow 1 Stored Procedure

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

# 11. Create Workflow 1 Materialized-View Support

Run:

```bash
psql "$DATABASE_URL" -f sql/05_materialized_views.sql
```

This creates:

```text
freelancer_lifetime_stats
refresh_freelancer_lifetime_stats()
```

Verify:

```sql
SELECT COUNT(*)
FROM freelancer_lifetime_stats;
```

After data generation, refresh:

```sql
CALL refresh_freelancer_lifetime_stats();
```

---

# 12. Generate PostgreSQL Stress-Test Data

The generator is:

```text
data_generation/postgres_seeder.py
```

Its default generation targets are:

```text
1,000 clients
5,000 freelancers
50,000 contracts
100,000 wallet audit entries
```

Run:

```bash
python3 data_generation/postgres_seeder.py
```

Verify:

```bash
psql "$DATABASE_URL"
```

```sql
SELECT COUNT(*) AS clients FROM clients;
SELECT COUNT(*) AS freelancers FROM freelancers;
SELECT COUNT(*) AS contracts FROM contracts;
SELECT COUNT(*) AS audit_logs FROM wallet_audit_logs;
```

Required:

```text
contracts   >= 50,000
audit_logs  >= 100,000
```

---

# 13. WORKFLOW 1 — ATOMIC GIG FUNDING

## Assignment Requirement

> Write a PL/pgSQL Stored Procedure that safely deducts client funds into escrow, creates a contract, and commits atomically.

## Source File

```text
sql/04_stored_procedures.sql
```

## What to Verify

The procedure is:

```text
fund_gig(...)
```

It performs:

```text
Validate budget
      ↓
Lock client row with FOR UPDATE
      ↓
Check client exists
      ↓
Check sufficient escrow balance
      ↓
Check freelancer exists
      ↓
Deduct escrow balance
      ↓
Create FUNDED contract
      ↓
Complete as one database transaction
```

## Run a Real Test

Inside:

```text
gigtask=#
```

Get a client:

```sql
SELECT id, escrow_balance
FROM clients
LIMIT 1;
```

Get a freelancer:

```sql
SELECT id, name
FROM freelancers
LIMIT 1;
```

Then use those real IDs:

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

Verify the balance:

```sql
SELECT escrow_balance
FROM clients
WHERE id = '<CLIENT_ID>';
```

The balance should be reduced by `100.00`.

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

Verify the audit:

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

### Workflow 1 Pass Condition

```text
[ ] fund_gig exists as PROCEDURE
[ ] CALL executes successfully
[ ] escrow balance decreases by requested budget
[ ] FUNDED contract is created
[ ] audit entry is generated
```

---

# 14. WORKFLOW 2 — SQL WINDOW ANALYTICS

## Assignment Requirement

> Utilize CTEs and Window Functions to compute the 7-day moving average of contract revenue per freelancer, ranked by DENSE RANK().

## Source File

```text
sql/06_window_analytics.sql
```

## Required SQL Concepts

The file contains:

```text
CTE daily_revenue
CTE moving
CTE latest
AVG(...) OVER(...)
PARTITION BY freelancer_id
RANGE BETWEEN INTERVAL '6 days' PRECEDING AND CURRENT ROW
DENSE_RANK() OVER(...)
```

The query:

1. Selects completed contracts.
2. Calculates daily revenue per freelancer.
3. Calculates the 7-day moving average.
4. Takes the latest available day for each freelancer.
5. Ranks freelancers using `DENSE_RANK()`.

## Run It

From the project root:

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

### Workflow 2 Pass Condition

```text
[ ] CTEs are present
[ ] 7-day moving average is calculated
[ ] Calculation is partitioned by freelancer
[ ] DENSE_RANK() is used
[ ] Query executes and returns ranked results
```

---

# 15. MongoDB Setup

Start MongoDB using the normal service method for your operating system.

Open:

```bash
mongosh
```

Select database:

```javascript
use("gigtask");
```

---

# 16. Create MongoDB Collections and Indexes

Source file:

```text
mongo/01_collections_and_indexes.js
```

Run:

```javascript
load("mongo/01_collections_and_indexes.js");
```

Then inspect:

```javascript
db.WorkerLocations.getIndexes();
```

Required geospatial index:

```text
location_2dsphere
```

Required TTL behavior:

```text
created_at
expireAfterSeconds: 7200
```

`7200` seconds = 2 hours.

Also inspect:

```javascript
db.GigReviews.getIndexes();
```

---

# 17. Generate MongoDB Stress-Test Data

The generator is:

```text
data_generation/mongo_seeder.py
```

Run from the project root:

```bash
python3 data_generation/mongo_seeder.py
```

Verify the required geospatial scale:

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

Also verify:

```javascript
db.Portfolios.countDocuments();
db.GigReviews.countDocuments();
```

---

# 18. WORKFLOW 3 — NEAREST AVAILABLE WORKER

## Assignment Requirement

> Write a `$geoNear` pipeline to find the closest available freelancer to a physical job site.

## Source File

```text
mongo/02_workflow3_geonear.js
```

## Required MongoDB Concepts

The script uses:

```text
$geoNear
location
distanceMeters
spherical: true
is_available: true
```

The `WorkerLocations.location` field uses GeoJSON:

```text
{
  type: "Point",
  coordinates: [longitude, latitude]
}
```

## Run the Workflow

From `mongosh`:

```javascript
use("gigtask");

load("mongo/02_workflow3_geonear.js");
```

The script should print nearby available workers.

Expected output contains fields such as:

```text
freelancer_id
distanceMeters
location
created_at
```

## Verify the Index

```javascript
db.WorkerLocations.getIndexes();
```

Confirm:

```text
location_2dsphere
```

## Workflow 3 Pass Condition

```text
[ ] $geoNear is used
[ ] location is the geospatial field
[ ] available workers are filtered
[ ] distance is returned
[ ] location_2dsphere index exists
[ ] script executes successfully
```

---

# 19. WORKFLOW 4 — MULTI-FACETED REVIEW ANALYTICS

## Assignment Requirement

> Write a `$facet` pipeline extracting rating distributions, top skill-tags via `$unwind`, and overall worker ratings.

## Source File

```text
mongo/03_workflow4_facet.js
```

## Required Facets

The script contains:

```text
rating_distribution
top_skill_tags
overall_worker_ratings
```

The skill-tag analysis uses:

```javascript
$unwind: "$skill_tags"
```

## Run the Workflow

From `mongosh`:

```javascript
use("gigtask");

load("mongo/03_workflow4_facet.js");
```

Expected output contains:

```text
rating_distribution
top_skill_tags
overall_worker_ratings
```

### What Each Facet Does

### Rating distribution

Groups reviews by:

```text
rating
```

and counts reviews.

### Top skill tags

Uses:

```text
$unwind skill_tags
```

then calculates tag usage and average rating, sorts the results, and returns the top tags.

### Overall worker ratings

Groups reviews by:

```text
freelancer_id
```

and calculates:

```text
average_rating
review_count
```

## Workflow 4 Pass Condition

```text
[ ] $facet is used
[ ] rating_distribution exists
[ ] $unwind is used on skill_tags
[ ] top_skill_tags exists
[ ] overall_worker_ratings exists
[ ] script executes successfully
```

---

# 20. PostgreSQL Requirement Verification

## Row Counts

```sql
SELECT COUNT(*) FROM clients;
SELECT COUNT(*) FROM freelancers;
SELECT COUNT(*) FROM contracts;
SELECT COUNT(*) FROM wallet_audit_logs;
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

## Partial Unique Index

```sql
SELECT indexname, indexdef
FROM pg_indexes
WHERE indexname = 'idx_active_gig';
```

## Materialized View

```sql
SELECT COUNT(*)
FROM freelancer_lifetime_stats;
```

## Refresh Procedure

```sql
SELECT routine_name, routine_type
FROM information_schema.routines
WHERE routine_name = 'refresh_freelancer_lifetime_stats';
```

---

# 21. MongoDB Requirement Verification

## WorkerLocations Scale

```javascript
db.WorkerLocations.countDocuments();
```

Required:

```text
>= 500000
```

## Worker Location Indexes

```javascript
db.WorkerLocations.getIndexes();
```

Required:

```text
location_2dsphere
created_at TTL with expireAfterSeconds = 7200
```

## Review Indexes

```javascript
db.GigReviews.getIndexes();
```

---

# 22. Performance Evidence

Only these two performance files belong in the submission:

```text
performance/
├── postgres_explain_analyzes.txt
└── mongo_execution_stats.json
```

## PostgreSQL

Use:

```sql
EXPLAIN (ANALYZE, BUFFERS)
<query>;
```

Save the actual output in:

```text
performance/postgres_explain_analyzes.txt
```

Do not invent execution times or plan information.

A sequential scan in an actual plan is not automatically a failure. The submitted file must report the real PostgreSQL plan.

## MongoDB

Use:

```javascript
db.<collection>.explain("executionStats").aggregate([
    // actual workflow pipeline
]);
```

Save actual evidence in:

```text
performance/mongo_execution_stats.json
```

For Workflow 3, look for:

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

# 23. Complete Evaluator Run Order

A person cloning the repository should run the following in order:

```text
1. Clone GitHub repository
2. cd GigTask
3. Create Python virtual environment
4. Install requirements
5. Create PostgreSQL database
6. Set DATABASE_URL
7. Run sql/01_schema_ddl.sql
8. Run sql/02_indexes.sql
9. Run sql/03_triggers_and_audit.sql
10. Run sql/04_stored_procedures.sql
11. Run sql/05_materialized_views.sql
12. Run data_generation/postgres_seeder.py
13. Verify PostgreSQL counts
14. Test Workflow 1
15. Run Workflow 2
16. Start MongoDB
17. Run mongo/01_collections_and_indexes.js
18. Run data_generation/mongo_seeder.py
19. Verify MongoDB counts
20. Run Workflow 3
21. Run Workflow 4
22. Verify PostgreSQL indexes/triggers/views
23. Verify MongoDB indexes
24. Check PostgreSQL performance evidence
25. Check MongoDB performance evidence
```

---

# 24. Final Submission Checklist

## Data Scale

- [ ] At least 50,000 PostgreSQL contracts
- [ ] At least 100,000 PostgreSQL audit/ledger entries
- [ ] At least 500,000 MongoDB WorkerLocations pings

## Workflow 1

- [ ] `fund_gig()` stored procedure exists
- [ ] Client funds are deducted
- [ ] Contract is created
- [ ] Contract status is `FUNDED`
- [ ] Audit entry is generated
- [ ] Operation is atomic

## Workflow 2

- [ ] CTEs
- [ ] Daily revenue
- [ ] 7-day moving average
- [ ] Window function
- [ ] `DENSE_RANK()`
- [ ] Per-freelancer ranking

## Workflow 3

- [ ] `$geoNear`
- [ ] GeoJSON Point
- [ ] Available-worker filter
- [ ] Distance calculation
- [ ] `location_2dsphere`

## Workflow 4

- [ ] `$facet`
- [ ] Rating distribution
- [ ] `$unwind` skill tags
- [ ] Top skill tags
- [ ] Overall worker ratings

## PostgreSQL Engineering

- [ ] Escrow audit trigger
- [ ] Partial unique active-gig index
- [ ] Materialized view
- [ ] Concurrent refresh
- [ ] Required indexes

## MongoDB Engineering

- [ ] 2dsphere index
- [ ] 2-hour TTL index
- [ ] Review indexes
- [ ] Required collections

## Performance

- [ ] `performance/postgres_explain_analyzes.txt`
- [ ] `performance/mongo_execution_stats.json`
- [ ] Actual execution evidence
- [ ] No fabricated metrics

---

# 25. Quick Rule for the Evaluator

If you want to check only the four complex workflows:

### Workflow 1

```bash
psql "$DATABASE_URL" -f sql/04_stored_procedures.sql
```

Then inside `psql`:

```sql
CALL fund_gig('<CLIENT_ID>', '<FREELANCER_ID>', 100.00);
```

### Workflow 2

```bash
psql "$DATABASE_URL" -f sql/06_window_analytics.sql
```

### Workflow 3

```bash
mongosh
```

```javascript
use("gigtask");
load("mongo/02_workflow3_geonear.js");
```

### Workflow 4

```javascript
load("mongo/03_workflow4_facet.js");
```

That directly demonstrates the four requirements from the assignment.
