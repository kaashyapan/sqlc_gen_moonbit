///|
struct PgTimestamp {
  year : Int
  month : Int
  day : Int
  hour : Int
  minute : Int
  second : Int
  microsecond : Int
} derive(Show)

///|
pub fn PgTimestamp::of_plain_date_time(
  datetime : @time.PlainDateTime,
) -> PgTimestamp {
  PgTimestamp::{
    year: datetime.year(),
    month: datetime.month(),
    day: datetime.day(),
    hour: datetime.hour(),
    minute: datetime.minute(),
    second: datetime.second(),
    microsecond: datetime.nanosecond() / 1000,
  }
}

///|
pub fn PgTimestamp::to_plain_date_time(
  self : Self,
) -> @time.PlainDateTime raise {
  @time.PlainDateTime::of(
    self.year,
    self.month,
    self.day,
    hour=self.hour,
    minute=self.minute,
    second=self.second,
    nanosecond=self.microsecond * 1000,
  )
}

///|
pub fn PgTimestamp::to_string(self : Self) -> Unit {
  println(
    "PgTimestamp - Year: \{self.year}, Month: \{self.month}, Day: \{self.day}, Hour:\{self.hour}, Minute:\{self.minute}, Second:\{self.second}, Microsecond:\{self.microsecond}}",
  )
}

///|
pub impl @pgclient.ToSql for PgTimestamp with format(_, _) {
  @pgclient.WireFormat::Binary
}

///|
pub impl @pgclient.ToSql for PgTimestamp with accepts(_, type_) {
  type_.oid == @pgclient.Type::timestamp().oid
}

///|
pub impl @pgclient.ToSql for PgTimestamp with moonbit_type_name(_) {
  "PgTimestamp"
}

///|
pub impl @pgclient.ToSql for PgTimestamp with to_sql(self, _, buf) {
  let datetime = PgTimestamp::to_plain_date_time(self)
  let unix_seconds = datetime.to_unix_second()

  let us_since_2000 = (unix_seconds - EPOCH_OFFSET_SECS) * 1_000_000L +
    datetime.nanosecond().to_int64() / 1_000L
  buf.write_int64_be(us_since_2000)
  No
}

///|
pub impl @pgclient.FromSql for PgTimestamp with accepts(type_) {
  type_.oid == @pgclient.Type::timestamp().oid
}

///|
pub impl @pgclient.FromSql for PgTimestamp with moonbit_type_name() {
  "PgTimestamp"
}

///|
pub impl @pgclient.FromSql for PgTimestamp with from_sql(_, format, raw) {
  match format {
    @pgclient.WireFormat::Binary =>
      match raw {
        [i64be(us_since_2000)] => {
          let seconds_since_2000 = us_since_2000 / 1_000_000L
          let sub_microseconds = us_since_2000 % 1_000_000L
          let unix_seconds = seconds_since_2000 + EPOCH_OFFSET_SECS
          let nanoseconds = (sub_microseconds * 1_000L).to_int()
          let plaindatetime = PlainDateTime::from_unix_second(
            unix_seconds, nanoseconds, @time.utc_offset,
          )
          PgTimestamp::of_plain_date_time(plaindatetime)
        }
        _ =>
          raise UnexpectedNullorInvalid(
            "PgTimestamp -> PlainDateTime. Raw bytes - \{raw}",
          )
      }
  }
}
