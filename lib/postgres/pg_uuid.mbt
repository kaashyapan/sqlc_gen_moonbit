///|
struct PgUUID {
  uuid : UUID
} derive(Show)

///|
pub fn PgUUID::of_uuid(uuid : UUID) -> PgUUID {
  PgUUID::{ uuid, }
}

///|
pub fn PgUUID::to_uuid(self : Self) -> UUID {
  self.uuid
}

///|
pub fn PgUUID::to_string(self : Self) -> Unit {
  println("PgUUID - uuid:\{self.uuid}")
}

///|
pub impl @pgclient.ToSql for PgUUID with format(_, _) {
  @pgclient.WireFormat::Binary
}

///|
pub impl @pgclient.ToSql for PgUUID with accepts(_, type_) {
  type_.oid == @pgclient.Type::uuid().oid
}

///|
pub impl @pgclient.ToSql for PgUUID with moonbit_type_name(_) {
  "PgUUID"
}

///|
pub impl @pgclient.ToSql for PgUUID with to_sql(self, _, buf) {
  buf.write_bytes(self.uuid.to_bytes())
  No
}

///|
pub impl @pgclient.FromSql for PgUUID with accepts(type_) {
  type_.oid == @pgclient.Type::uuid().oid
}

///|
pub impl @pgclient.FromSql for PgUUID with moonbit_type_name() {
  "PgUUID"
}

///|
pub impl @pgclient.FromSql for PgUUID with from_sql(_, format, raw) {
  match format {
    @pgclient.WireFormat::Binary => {
      let uuid = @uuid.from_bytes(raw.to_owned())
      return PgUUID::of_uuid(uuid)
    }
    _ =>
      raise UnexpectedNullorInvalid("PgUUID -> @uuid.UUID. Raw bytes - \{raw}")
  }
}
