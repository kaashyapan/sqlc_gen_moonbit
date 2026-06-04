///|
using @time {
  type ZonedDateTime,
  type PlainDateTime,
  type PlainDate,
  type PlainTime,
  type Period,
  type Duration,
  type ZoneOffset,
}

///|
using @uuid {type UUID}

///|
/// Seconds between Unix epoch (1970-01-01) and the encoded epoch (2000-01-01)
const EPOCH_OFFSET_SECS : Int64 = 946684800L

///|
const SECONDS_PER_DAY : Int64 = 86400L

///|
const INTERVAL_OID : @proto.Oid = 1186U

///|
const TIMETZ_OID : @proto.Oid = 1266U

///|
pub(all) suberror SqlcError {
  UnexpectedNullorInvalid(String)
} derive(Debug)

///|
pub fn get_as_serial(bytes : Bytes?) -> Int raise {
  match bytes {
    Some(s) =>
      match s {
        [u32be(serial)] => return serial.reinterpret_as_int()
        _ =>
          raise UnexpectedNullorInvalid(
            "Invalid serial returned after insert. Raw bytes - \{s}",
          )
      }
    raw =>
      raise UnexpectedNullorInvalid(
        "Invalid serial returned after insert. Raw bytes - \{raw}",
      )
  }
}
