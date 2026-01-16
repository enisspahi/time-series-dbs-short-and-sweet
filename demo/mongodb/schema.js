use smart-meters;

db.createCollection("readings", {
  timeseries: {
    timeField: "reading_time",
    metaField: "metadata",
    granularity: "minutes"
  },
  expireAfterSeconds: 315360000  // 10 years retention
});