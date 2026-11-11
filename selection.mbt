///|
pub(all) enum ReturnMode {
  Any
  First
  Last
  Single
} derive(Debug, Eq)

///|
/// Empty membership lists impose no restriction. All criteria are intersected.
pub(all) struct Selection {
  classifications : Array[Int32]
  source_ids : Array[Int32]
  min_intensity : Int32
  max_intensity : Int32
  return_mode : ReturnMode
  include_withheld : Bool
  gps_min : Double?
  gps_max : Double?
} derive(Debug)

///|
pub fn Selection::all() -> Selection {
  {
    classifications: [],
    source_ids: [],
    min_intensity: 0,
    max_intensity: 65535,
    return_mode: Any,
    include_withheld: true,
    gps_min: None,
    gps_max: None,
  }
}

///|
pub fn Selection::validate(self : Selection) -> Unit raise LasError {
  require(
    self.min_intensity >= 0 &&
    self.max_intensity <= 65535 &&
    self.min_intensity <= self.max_intensity,
    "invalid intensity interval",
  )
  for c in self.classifications {
    require(c >= 0 && c <= 255, "invalid selection class")
  }
  for s in self.source_ids {
    require(s >= 0 && s <= 65535, "invalid source selection")
  }
  if self.gps_min is Some(v) {
    require(finite(v), "nonfinite GPS minimum")
  }
  if self.gps_max is Some(v) {
    require(finite(v), "nonfinite GPS maximum")
  }
  if self.gps_min is Some(lo) {
    if self.gps_max is Some(hi) {
      require(lo <= hi, "reversed GPS interval")
    }
  }
}

///|
fn Selection::matches(self : Selection, p : Point) -> Bool {
  if !self.classifications.is_empty() &&
    !self.classifications.contains(p.classification) {
    return false
  }
  if !self.source_ids.is_empty() && !self.source_ids.contains(p.source_id) {
    return false
  }
  if p.intensity < self.min_intensity || p.intensity > self.max_intensity {
    return false
  }
  if !self.include_withheld && (p.flags & 4) != 0 {
    return false
  }
  let accepted = match self.return_mode {
    Any => true
    First => p.return_number == 1
    Last => p.return_number == p.returns
    Single => p.returns == 1
  }
  if !accepted {
    return false
  }
  if self.gps_min is Some(lo) {
    match p.gps_time {
      Some(t) => if t < lo { return false }
      None => return false
    }
  }
  if self.gps_max is Some(hi) {
    match p.gps_time {
      Some(t) => if t > hi { return false }
      None => return false
    }
  }
  true
}

///|
/// Stable-order selection retains every attribute and all opaque metadata.
pub fn Document::select(
  self : Document,
  selection : Selection,
  limits~ : Limits = Limits::default(),
) -> Document raise LasError {
  self.validate(limits~)
  selection.validate()
  self.with_points(self.points.filter(p => selection.matches(p)), limits~)
}

///|
pub extend ReturnMode with @debug.Debug::{to_repr}

///|
pub extend ReturnMode with Eq::{equal, not_equal}

///|
pub extend Selection with @debug.Debug::{to_repr}
