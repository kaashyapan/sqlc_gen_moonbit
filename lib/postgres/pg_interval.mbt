///|
pub struct Interval {
  period : @time.Period
  duration : @time.Duration
} derive(Show, Eq, Compare)

///|
struct PgInterval {
  month : Int
  day : Int
  microsecond : Int64
} derive(Show, Eq, Compare)

///|
pub fn PgInterval::of_period_duration(interval : Interval) -> PgInterval {
  PgInterval::{
    month: interval.period.months(),
    day: interval.period.days(),
    microsecond: interval.duration.to_nanoseconds() / 1000L,
  }
}

///|
pub fn PgInterval::to_period_duration(self : Self) -> Interval raise {
  let period = Period::zero().add_days(self.day).add_months(self.month)
  let duration = Duration::zero().add_nanoseconds(self.microsecond * 1000L)

  Interval::{ period, duration }
}

///|
pub impl @pgclient.ToSql for PgInterval with format(_, _) {
  @pgclient.WireFormat::Binary
}

///|
pub impl @pgclient.ToSql for PgInterval with accepts(_, type_) {
  type_.oid == INTERVAL_OID
}

///|
pub impl @pgclient.ToSql for PgInterval with moonbit_type_name(_) {
  "PgInterval"
}

///|
pub impl @pgclient.ToSql for PgInterval with to_sql(self, _, buf) {
  buf.write_int64_be(self.microsecond)
  buf.write_int_be(self.day)
  buf.write_int_be(self.month)
  No
}

///|
pub impl @pgclient.FromSql for PgInterval with accepts(type_) {
  type_.oid == INTERVAL_OID
}

///|
pub impl @pgclient.FromSql for PgInterval with moonbit_type_name() {
  "PgInterval"
}

///|
pub impl @pgclient.FromSql for PgInterval with from_sql(_, format, raw) {
  match format {
    @pgclient.WireFormat::Binary =>
      match raw {
        [i64be(micros), i32be(days), i32be(months)] => {
          let period = Period::zero().add_days(days).add_months(months)
          let duration = Duration::zero().add_nanoseconds(micros * 1000L)

          let interval = Interval::{ period, duration }
          return PgInterval::of_period_duration(interval)
        }
        _ =>
          raise UnexpectedNullorInvalid(
            "PgInterval -> Interval. Raw bytes - \{raw}",
          )
      }
  }
}
