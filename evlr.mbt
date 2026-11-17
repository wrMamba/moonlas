///|
/// Extended records carry 64-bit lengths on disk; allocations remain bounded by Limits.
pub(all) struct Evlr {
  user_id : String
  record_id : Int32
  description : String
  payload : Bytes
  reserved : Int32
  raw_text : Bytes
} derive(Debug, Eq)

///|
pub fn Evlr::new(
  user_id : String,
  record_id : Int32,
  description : String,
  payload : Bytes,
) -> Evlr {
  { user_id, record_id, description, payload, reserved: 0, raw_text: b"", }
}

///|
pub fn Evlr::validate(self : Evlr) -> Unit raise LasError {
  require(self.record_id >= 0 && self.record_id <= 65535, "invalid EVLR ID")
  require(
    self.reserved >= 0 && self.reserved <= 65535,
    "invalid EVLR reserved word",
  )
  require(
    self.raw_text.is_empty() || self.raw_text.length() == 48,
    "invalid EVLR text bytes",
  )
  let out : Array[Byte] = []
  put_record_text(out, self.user_id, self.description, self.raw_text)
}

///|
fn read_evlr(r : Reader, limits : Limits) -> Evlr raise LasError {
  let reserved = r.u16()
  let user = r.take(16)
  let user_id = fixed_text(user)
  let record_id = r.u16()
  let length = r.u64(limits.max_bytes)
  let text = r.take(32)
  let description = fixed_text(text)
  let payload = r.take(length)
  let raw_text = record_raw_text(user, text, user_id, description)
  { user_id, record_id, description, payload, reserved, raw_text, }
}

///|
fn put_evlr(out : Array[Byte], record : Evlr) -> Unit raise LasError {
  record.validate()
  put16(out, record.reserved)
  put_preserved_text(out, record.user_id, 16, raw_part(record.raw_text, 0, 16))
  put16(out, record.record_id)
  put64(out, record.payload.length())
  put_preserved_text(
    out,
    record.description,
    32,
    raw_part(record.raw_text, 16, 32),
  )
  append(out, record.payload)
}

///|
fn point_end(h : Header) -> Int32 {
  h.point_offset + h.point_count * h.record_length
}

///|
fn tail_records(
  h : Header,
  tail : Bytes,
  limits : Limits,
) -> (Array[Evlr], Int32) raise LasError {
  require(
    h.evlr_count >= 0 && h.evlr_count <= limits.max_vlrs,
    "EVLR count exceeds limit",
  )
  if h.evlr_count == 0 {
    return ([], 0)
  }
  require(h.minor == 4, "EVLRs require LAS 1.4")
  let start = h.evlr_offset - point_end(h)
  let r = Reader::new(tail, start, tail.length())
  checked_size(h.evlr_count, 60, tail.length() - start)
  let records : Array[Evlr] = []
  for _ in 0..<h.evlr_count {
    records.push(read_evlr(r, limits))
  }
  (records, r.pos)
}

///|
fn validate_tail(
  h : Header,
  tail : Bytes,
  limits : Limits,
) -> Unit raise LasError {
  require((h.global_encoding & 6) != 6, "conflicting waveform storage flags")
  require(
    h.evlr_offset >= 0 && h.waveform_offset >= 0,
    "negative metadata offset",
  )
  require(
    h.evlr_count != 0 || h.evlr_offset == 0,
    "EVLR offset without records",
  )
  let (records, _) = tail_records(h, tail, limits)
  if h.waveform_offset > 0 {
    require(h.minor >= 3, "waveform data requires LAS 1.3")
    require(
      (h.global_encoding & 4) == 0,
      "external waveform flag with internal data",
    )
    let start = h.waveform_offset - point_end(h)
    let r = Reader::new(tail, start, tail.length())
    let packet = read_evlr(r, limits)
    require(
      packet.user_id == "LASF_Spec" && packet.record_id == 65535,
      "invalid waveform data record",
    )
    if h.evlr_count > 0 {
      let mut pos = h.evlr_offset
      let mut found = false
      for record in records {
        if pos == h.waveform_offset {
          found = true
        }
        pos += 60 + record.payload.length()
      }
      require(found, "waveform offset is not an EVLR boundary")
    }
  }
}

///|
/// Unknown records are returned unchanged, in original order.
pub fn Document::evlrs(
  self : Document,
  limits~ : Limits = Limits::default(),
) -> Array[Evlr] raise LasError {
  self.validate(limits~)
  let (records, _) = tail_records(self.header, self.tail, limits)
  records
}

///|
/// Replace the EVLR chain, retaining pre-chain bytes and trailing bytes. Internal
/// waveform offsets are recalculated by record identity, never by guessed byte patterns.
pub fn Document::with_evlrs(
  self : Document,
  records : Array[Evlr],
  limits~ : Limits = Limits::default(),
) -> Document raise LasError {
  self.validate(limits~)
  require(self.header.minor == 4, "EVLRs require LAS 1.4")
  if records.length() > limits.max_vlrs {
    raise Limit("EVLR count budget exceeded")
  }
  let h = self.header
  let (_, old_end) = tail_records(h, self.tail, limits)
  let start = if h.evlr_count > 0 {
    h.evlr_offset - point_end(h)
  } else {
    self.tail.length()
  }
  let prefix = slice_bytes(self.tail, 0, start)
  let suffix = if h.evlr_count > 0 {
    slice_bytes(self.tail, old_end, self.tail.length() - old_end)
  } else {
    b""
  }
  let mut total = point_end(h) + prefix.length() + suffix.length()
  let mut wave = if h.waveform_offset > 0 &&
    h.waveform_offset < point_end(h) + start {
    h.waveform_offset
  } else {
    0
  }
  let mut pos = point_end(h) + start
  for record in records {
    record.validate()
    if record.payload.length() > limits.max_bytes - total - 60 {
      raise Limit("EVLR byte budget exceeded")
    }
    total += 60 + record.payload.length()
    if record.user_id == "LASF_Spec" && record.record_id == 65535 {
      require(wave == 0, "multiple internal waveform data records")
      wave = pos
    }
    pos += 60 + record.payload.length()
  }
  if h.waveform_offset > 0 && wave == 0 {
    require(
      !self.points.any(p => p.waveform is Some(w) && w.descriptor_index != 0),
      "cannot remove waveform data referenced by points",
    )
  }
  let out = prefix.to_array()
  for record in records {
    put_evlr(out, record)
  }
  append(out, suffix)
  let global_encoding = if wave > 0 {
    (h.global_encoding | 2) & -5
  } else {
    h.global_encoding & -3
  }
  let result = {
    ..self,
    tail: bytes_of(out),
    header: {
      ..h,
      evlr_offset: if records.is_empty() {
        0
      } else {
        point_end(h) + start
      },
      evlr_count: records.length(),
      waveform_offset: wave,
      global_encoding,
    },
  }
  result.validate(limits~)
  result
}

///|
pub extend Evlr with @debug.Debug::{to_repr}

///|
pub extend Evlr with Eq::{equal, not_equal}
