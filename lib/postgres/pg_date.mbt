///|
struct PgDate {
  year : Int
  month : Int
  day : Int
} derive(Show)

///|
pub fn PgDate::of_plain_date(date : @time.PlainDate) -> PgDate {
  PgDate::{ year: date.year(), month: date.month(), day: date.day() }
}

///|
pub fn PgDate::to_plain_date(self : Self) -> @time.PlainDate raise {
  @time.PlainDate::of(self.year, self.month, self.day)
}

///|
pub fn PgDate::to_string(self : Self) -> Unit {
  println("PgDate - Year: \{self.year}, Month: \{self.month}, Day: \{self.day}")
}

///|
pub impl @pgclient.ToSql for PgDate with format(_, _) {
  @pgclient.WireFormat::Binary
}

///|
pub impl @pgclient.ToSql for PgDate with accepts(_, type_) {
  type_.oid == @pgclient.Type::date().oid
}

///|
pub impl @pgclient.ToSql for PgDate with moonbit_type_name(_) {
  "PgDate"
}

///|
pub impl @pgclient.ToSql for PgDate with to_sql(self, _, buf) {
  let unix_seconds : Int64 = ZonedDateTime::of(self.year, self.month, self.day).to_unix_second()
  let days_since_2000 : Int64 = (unix_seconds - EPOCH_OFFSET_SECS) /
    SECONDS_PER_DAY
  buf.write_int_be(days_since_2000.to_int())
  No
}

///|
pub impl @pgclient.FromSql for PgDate with accepts(type_) {
  type_.oid == @pgclient.Type::date().oid
}

///|
pub impl @pgclient.FromSql for PgDate with moonbit_type_name() {
  "PgDate"
}

///|
pub impl @pgclient.FromSql for PgDate with from_sql(_, format, raw) {
  match format {
    @pgclient.WireFormat::Binary =>
      match raw {
        [i32be(days_since_2000)] => {
          let unix_seconds = days_since_2000.to_int64() * SECONDS_PER_DAY +
            EPOCH_OFFSET_SECS

          let days = ZonedDateTime::from_unix_second(unix_seconds)
          return PgDate::{
            year: days.year(),
            month: days.month(),
            day: days.day(),
          }
        }
        _ =>
          raise UnexpectedNullorInvalid(
            "PgDate -> PlainDate. Raw bytes - \{raw}",
          )
      }
  }
}
