import os,random
from datetime import datetime,timedelta
from pymongo import MongoClient
URI=os.getenv('MONGO_URI','mongodb://localhost:27017'); DB=os.getenv('MONGO_DB','gigtask'); N=int(os.getenv('PING_COUNT','500000'))
def main():
 c=MongoClient(URI); col=c[DB]['WorkerLocations']; batch=[]
 for i in range(N):
  batch.append({'freelancer_id':str(random.randint(1,5000)),'is_available':random.choice([True,True,True,False]),'location':{'type':'Point','coordinates':[round(random.uniform(78.2,78.7),6),round(random.uniform(17.2,17.6),6)]},'created_at':datetime.utcnow()-timedelta(seconds=random.randint(0,7199))})
  if len(batch)==5000: col.insert_many(batch,ordered=False); batch=[]
 if batch: col.insert_many(batch,ordered=False)
 print('MongoDB seeding complete')
if __name__=='__main__': main()
