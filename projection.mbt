///|
/// Opaque CRS records keep the declared WKT/GeoTIFF payload and original location.
pub(all) struct ProjectionRecord {
  record_id : Int32
  extended : Bool
  payload : Bytes
} derive(Debug, Eq)

///|
/// Collect both VLR and EVLR projection records, including vendor extensions.
/// This method does not choose a CRS or reinterpret its units and axis order.
pub fn Document::projection_records(
  self : Document,
  limits~ : Limits = Limits::default(),
) -> Array[ProjectionRecord] raise LasError {
  self.validate(limits~)
  let result : Array[ProjectionRecord] = []
  for record in self.vlrs {
    if record.user_id == "LASF_Projection" {
      result.push({
        record_id: record.record_id,
        extended: false,
        payload: record.payload,
      })
    }
  }
  for record in self.evlrs(limits~) {
    if record.user_id == "LASF_Projection" {
      result.push({
        record_id: record.record_id,
        extended: true,
        payload: record.payload,
      })
    }
  }
  result
}

///|
pub extend ProjectionRecord with @debug.Debug::{to_repr}

///|
pub extend ProjectionRecord with Eq::{equal, not_equal}
