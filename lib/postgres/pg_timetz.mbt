///|
pub struct TimeTz {
  time : @time.PlainTime
  zone_offset : @time.ZoneOffset
} derive(Show, Eq, Compare)

///|
struct PgTimeTz {
  hour : Int
  minute : Int
  second : Int
  microsecond : Int
  offset_seconds : Int
} derive(Show)

///|
pub fn PgTimeTz::of_timetz(timetz : TimeTz) -> PgTimeTz {
  let hour = timetz.time.hour()
  let minute = timetz.time.minute()
  let second = timetz.time.second()
  let microsecond = timetz.time.nanosecond() / 1000
  let offset_seconds = timetz.zone_offset.seconds()
  PgTimeTz::{ hour, minute, second, microsecond, offset_seconds }
}

///|
pub fn PgTimeTz::to_timetz(self : Self) -> TimeTz raise {
  let time = @time.PlainTime::of(
    self.hour,
    self.minute,
    self.second,
    self.microsecond * 1000,
  )
  let zone_offset = ZoneOffset::from_seconds(self.offset_seconds)

  TimeTz::{ time, zone_offset }
}

///|
pub impl @pgclient.ToSql for PgTimeTz with format(_, _) {
  @pgclient.WireFormat::Binary
}

///|
pub impl @pgclient.ToSql for PgTimeTz with accepts(_, type_) {
  type_.oid == TIMETZ_OID
}

///|
pub impl @pgclient.ToSql for PgTimeTz with moonbit_type_name(_) {
  "PgTimeTz"
}

///|
pub impl @pgclient.ToSql for PgTimeTz with to_sql(self, _, buf) {
  let total_microseconds : Int64 = self.hour.to_int64() * 3_600_000_000L +
    self.minute.to_int64() * 60_000_000L +
    self.second.to_int64() * 1_000_000L +
    self.microsecond.to_int64()
  let pg_zone = self.offset_seconds * -1
  buf.write_int64_be(total_microseconds)
  buf.write_int_be(pg_zone)
  No
}

///|
pub impl @pgclient.FromSql for PgTimeTz with accepts(type_) {
  type_.oid == TIMETZ_OID
}

///|
pub impl @pgclient.FromSql for PgTimeTz with moonbit_type_name() {
  "PgTimeTz"
}

///|
pub impl @pgclient.FromSql for PgTimeTz with from_sql(_, format, raw) {
  match format {
    @pgclient.WireFormat::Binary =>
      match raw {
        [i64be(micros), i32be(pg_zone)] => {
          let time = PlainTime::from_nanosecond_of_day(micros * 1_000L)
          let zone_offset = ZoneOffset::from_seconds(pg_zone * -1)
          let interval = TimeTz::{ time, zone_offset }
          return PgTimeTz::of_timetz(interval)
        }
        _ =>
          raise UnexpectedNullorInvalid(
            "PgTimeTz -> TimeTz. Raw bytes - \{raw}",
          )
      }
  }
}
