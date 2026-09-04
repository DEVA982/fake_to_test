use("gigtask");

const result = db.GigReviews.aggregate([
  {
    $facet: {

      rating_distribution: [
        {
          $group: {
            _id: "$rating",
            review_count: { $sum: 1 }
          }
        },
        {
          $sort: { _id: 1 }
        }
      ],

      top_skill_tags: [
        {
          $unwind: "$skill_tags"
        },
        {
          $group: {
            _id: "$skill_tags",
            usage_count: { $sum: 1 },
            avg_rating: { $avg: "$rating" }
          }
        },
        {
          $sort: {
            usage_count: -1,
            avg_rating: -1
          }
        },
        {
          $limit: 10
        }
      ],

      overall_worker_ratings: [
        {
          $group: {
            _id: "$freelancer_id",
            review_count: { $sum: 1 },
            average_rating: { $avg: "$rating" }
          }
        },
        {
          $sort: {
            average_rating: -1,
            review_count: -1
          }
        }
      ]

    }
  }
]).toArray();

printjson(result);