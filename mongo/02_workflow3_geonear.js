const jobSite={type:'Point',coordinates:[78.4867,17.3850]};
db.WorkerLocations.aggregate([
 {$geoNear:{near:jobSite,key:'location',distanceField:'distanceMeters',spherical:true,query:{is_available:true}}},
 {$limit:1},
 {$project:{_id:0,freelancer_id:1,is_available:1,distanceMeters:1,location:1,created_at:1}}
]);
