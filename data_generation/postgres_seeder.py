import os, random
from datetime import datetime,timedelta
import psycopg2
from faker import Faker
fake=Faker()
DSN=os.getenv('DATABASE_URL','dbname=gigtask user=postgres password=postgres host=localhost port=5432')
CLIENTS=int(os.getenv('CLIENTS','1000')); FREELANCERS=int(os.getenv('FREELANCERS','5000')); CONTRACTS=int(os.getenv('CONTRACTS','50000'))
def main():
 conn=psycopg2.connect(DSN); cur=conn.cursor()
 cur.executemany('INSERT INTO clients(name,escrow_balance) VALUES(%s,%s)',[(fake.name(),round(random.uniform(1000,100000),2)) for _ in range(CLIENTS)])
 cur.executemany('INSERT INTO freelancers(name,latitude,longitude,is_available) VALUES(%s,%s,%s,%s)',[(fake.name(),round(random.uniform(17.2,17.6),6),round(random.uniform(78.2,78.7),6),random.choice([True,True,True,False])) for _ in range(FREELANCERS)])
 conn.commit(); cur.execute('SELECT id FROM clients'); clients=[x[0] for x in cur.fetchall()]; cur.execute('SELECT id FROM freelancers'); freelancers=[x[0] for x in cur.fetchall()]
 active=set(); rows=[]
 for i in range(CONTRACTS):
  f=random.choice(freelancers); status=random.choices(['FUNDED','IN PROGRESS','COMPLETED'],weights=[20,10,70])[0]
  if status=='IN PROGRESS' and f in active: status='COMPLETED'
  if status=='IN PROGRESS': active.add(f)
  created=datetime.utcnow()-timedelta(days=random.randint(0,90),hours=random.randint(0,23))
  completed=created+timedelta(days=random.randint(1,10)) if status=='COMPLETED' else None
  rows.append((random.choice(clients),f,round(random.uniform(25,5000),2),status,created,completed))
  if len(rows)==5000:
   cur.executemany('INSERT INTO contracts(client_id,freelancer_id,budget,status,created_at,completed_at) VALUES(%s,%s,%s,%s,%s,%s)',rows); conn.commit(); rows=[]
 if rows:
  cur.executemany('INSERT INTO contracts(client_id,freelancer_id,budget,status,created_at,completed_at) VALUES(%s,%s,%s,%s,%s,%s)',rows); conn.commit()
 cur.execute('SELECT COUNT(*) FROM wallet_audit_logs'); current=cur.fetchone()[0]; remaining=max(0,100000-current); rows=[]
 for i in range(remaining):
  rows.append((random.choice(clients),round(random.uniform(-1000,1000),2),random.choice(['DEPOSIT','WITHDRAWAL','ESCROW_DEBIT','REFUND']),round(random.uniform(0,100000),2),datetime.utcnow()-timedelta(days=random.randint(0,90))))
  if len(rows)==5000:
   cur.executemany('INSERT INTO wallet_audit_logs(client_id,amount_changed,action_type,balance_after,created_at) VALUES(%s,%s,%s,%s,%s)',rows); conn.commit(); rows=[]
 if rows: cur.executemany('INSERT INTO wallet_audit_logs(client_id,amount_changed,action_type,balance_after,created_at) VALUES(%s,%s,%s,%s,%s)',rows); conn.commit()
 cur.close(); conn.close(); print('PostgreSQL seeding complete')
if __name__=='__main__': main()
