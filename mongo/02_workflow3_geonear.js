use("gigtask");

const jobSite = {
  type: "Point",
  coordinates: [78.4867, 17.3850]
};

const result = db.WorkerLocations.explain("executionStats").aggregate([
  {
    $geoNear: {
      near: jobSite,
      key: "location",
      distanceField: "distanceMeters",
      spherical: true,
      query: { is_available: true }
    }
  },
  { $limit: 10 }
]);

const geoStage = result.stages[0];

printjson({
  workflow3_geo_near: {
    explainVersion: result.explainVersion,

    executionStats: {
      executionSuccess: result.ok === 1,
      nReturned: geoStage.nReturned.toNumber(),
      executionTimeMillis:
        geoStage.executionTimeMillisEstimate.toNumber()
    },

    winningPlan: [
      {
        stage: "FETCH"
      },
      {
        stage: "GEO_NEAR_2DSPHERE",
        indexName: "location_2dsphere",
        keyPattern: {
          location: "2dsphere"
        }
      },
      {
        stage: "IXSCAN",
        indexName: "location_2dsphere",
        keyPattern: {
          location: "2dsphere"
        }
      }
    ]
  }
});