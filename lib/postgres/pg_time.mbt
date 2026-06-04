///|
struct PgTime {
  hour : Int
  minute : Int
  second : Int
  microsecond : Int
} derive(Show)

///|
pub fn PgTime::of_plain_time(time : @time.PlainTime) -> PgTime {
  PgTime::{
    hour: time.hour(),
    minute: time.minute(),
    second: time.second(),
    microsecond: time.nanosecond() / 1000,
  }
}

///|
pub fn PgTime::to_plain_time(self : Self) -> @time.PlainTime raise {
  @time.PlainTime::of(
    self.hour,
    self.minute,
    self.second,
    self.microsecond * 1000,
  )
}

///|
pub fn PgTime::to_string(self : Self) -> Unit {
  println(
    "PgTime - Hour:\{self.hour}, Minute:\{self.minute}, Second:\{self.second}, Microsecond:\{self.microsecond}}",
  )
}

///|
pub impl @pgclient.ToSql for PgTime with format(_, _) {
  @pgclient.WireFormat::Binary
}

///|
pub impl @pgclient.ToSql for PgTime with accepts(_, type_) {
  type_.oid == @pgclient.Type::time().oid
}

///|
pub impl @pgclient.ToSql for PgTime with moonbit_type_name(_) {
  "PgTime"
}

///|
pub impl @pgclient.ToSql for PgTime with to_sql(self, _, buf) {
  let total_microseconds : Int64 = self.hour.to_int64() * 3_600_000_000L +
    self.minute.to_int64() * 60_000_000L +
    self.second.to_int64() * 1_000_000L +
    self.microsecond.to_int64()
  buf.write_uint64_be(total_microseconds.reinterpret_as_uint64())
  No
}

///|
pub impl @pgclient.FromSql for PgTime with accepts(type_) {
  type_.oid == @pgclient.Type::time().oid
}

///|
pub impl @pgclient.FromSql for PgTime with moonbit_type_name() {
  "PgTime"
}

///|
pub impl @pgclient.FromSql for PgTime with from_sql(_, format, raw) {
  match format {
    @pgclient.WireFormat::Binary =>
      match raw {
        [u64be(micros)] => {
          let plaintime = PlainTime::from_nanosecond_of_day(
            micros.reinterpret_as_int64() * 1_000L,
          )
          return PgTime::of_plain_time(plaintime)
        }
        _ =>
          raise UnexpectedNullorInvalid(
            "PgTime -> PlainTime. Raw bytes - \{raw}",
          )
      }
  }
}
