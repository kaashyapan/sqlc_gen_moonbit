/// Plugin-side fixup for sqlc.arg() expressions that sqlc leaves inside
/// INSERT ... ON CONFLICT DO UPDATE bodies. sqlc usually rewrites named args
/// to numbered placeholders and includes them in Query.params, but this path
/// can arrive with raw sqlc.arg('name') text and no matching param.

priv struct SqlcArgOccurrence {
  name : String
  start : Int
  end : Int
}

///|
fn normalize_sqlc_args_in_request(
  request : @plugin.GenerateRequest,
  backend : Backend,
) -> Unit {
  for i = 0; i < request.queries.length(); i = i + 1 {
    let query = request.queries[i]
    normalize_sqlc_args_in_query(request.catalog, query, backend)
    request.queries[i] = query
  }
}

///|
fn normalize_sqlc_args_in_query(
  catalog : @plugin.Catalog,
  query : @plugin.Query,
  backend : Backend,
) -> Unit {
  let occurrences = find_sqlc_arg_occurrences(query.text)
  if occurrences.length() == 0 {
    return
  }
  if backend is MysqlJs {
    abort(
      "unsupported: sqlc.arg() was left in query " +
      query.name +
      " for mysql_js. Use positional ? parameters or split the query.",
    )
  }

  let mut max_number = 0
  for param in query.params {
    if param.number > max_number {
      max_number = param.number
    }
  }

  for occurrence in occurrences {
    match find_param_number_by_name(query, occurrence.name) {
      Some(_) => ()
      None => {
        let target_col_name = match infer_assignment_column_name(
          query.text,
          occurrence.start,
        ) {
          Some(name) => name
          None =>
            abort(
              "unsupported: could not infer type for sqlc.arg('" +
              occurrence.name +
              "') in query " +
              query.name +
              ". Use a positional ? parameter or add an explicit CAST.",
            )
        }
        let source_col = match find_catalog_column(
          catalog,
          query.insert_into_table.name,
          target_col_name,
        ) {
          Some(col) => col
          None =>
            abort(
              "unsupported: could not find target column '" +
              target_col_name +
              "' for sqlc.arg('" +
              occurrence.name +
              "') in query " +
              query.name +
              ". Use a positional ? parameter or split the query.",
            )
        }
        max_number = max_number + 1
        query.params.push(
          @plugin.Parameter::{
            number: max_number,
            column: synthetic_named_param_column(occurrence.name, source_col),
          },
        )
      }
    }
  }
  query.text = rewrite_sqlc_arg_occurrences(query.text, occurrences, query, backend)
}

///|
fn find_sqlc_arg_occurrences(text : String) -> Array[SqlcArgOccurrence] {
  let occurrences : Array[SqlcArgOccurrence] = []
  let needle = "sqlc.arg("
  let mut i = 0
  while i + needle.length() <= text.length() {
    if string_matches_at(text, i, needle) {
      match parse_sqlc_arg_at(text, i) {
        Some(occurrence) => {
          occurrences.push(occurrence)
          i = occurrence.end
        }
        None => i = i + 1
      }
    } else {
      i = i + 1
    }
  }
  occurrences
}

///|
fn parse_sqlc_arg_at(text : String, start : Int) -> SqlcArgOccurrence? {
  let mut i = start + "sqlc.arg(".length()
  while i < text.length() && is_ascii_space(text[i].to_int().unsafe_to_char()) {
    i = i + 1
  }
  if i >= text.length() {
    return None
  }
  let quote = text[i]
  if quote != '\'' && quote != '"' {
    return None
  }
  i = i + 1
  let name_start = i
  while i < text.length() && text[i] != quote {
    i = i + 1
  }
  if i >= text.length() {
    return None
  }
  let name = substring(text, name_start, i)
  i = i + 1
  while i < text.length() && is_ascii_space(text[i].to_int().unsafe_to_char()) {
    i = i + 1
  }
  if i >= text.length() || text[i] != ')' {
    return None
  }
  Some(SqlcArgOccurrence::{ name, start, end: i + 1 })
}

///|
fn rewrite_sqlc_arg_occurrences(
  text : String,
  occurrences : Array[SqlcArgOccurrence],
  query : @plugin.Query,
  backend : Backend,
) -> String {
  let buf = StringBuilder::new()
  let mut last = 0
  for occurrence in occurrences {
    for i = last; i < occurrence.start; i = i + 1 {
      buf.write_char(text[i].to_int().unsafe_to_char())
    }
    let number = match find_param_number_by_name(query, occurrence.name) {
      Some(n) => n
      None =>
        abort(
          "internal error: missing synthetic sqlc.arg param '" +
          occurrence.name +
          "' in query " +
          query.name,
        )
    }
    buf.write_string(sqlc_arg_placeholder(backend, number))
    last = occurrence.end
  }
  for i = last; i < text.length(); i = i + 1 {
    buf.write_char(text[i].to_int().unsafe_to_char())
  }
  buf.to_string()
}

///|
fn sqlc_arg_placeholder(backend : Backend, number : Int) -> String {
  match backend {
    Sqlite | SqliteJs | D1 => "?" + number.to_string()
    Postgres | PostgresJs => "$" + number.to_string()
    MysqlJs =>
      abort("internal error: mysql_js sqlc.arg placeholder is unsupported")
  }
}

///|
fn find_param_number_by_name(query : @plugin.Query, name : String) -> Int? {
  for param in query.params {
    if param.column.name == name {
      return Some(param.number)
    }
  }
  None
}

///|
fn infer_assignment_column_name(text : String, arg_start : Int) -> String? {
  let mut eq = arg_start - 1
  while eq >= 0 && text[eq] != '=' {
    eq = eq - 1
  }
  if eq < 0 {
    return None
  }
  let mut end = eq - 1
  while end >= 0 && is_ascii_space(text[end].to_int().unsafe_to_char()) {
    end = end - 1
  }
  if end < 0 {
    return None
  }
  let mut start = end
  while start >= 0 &&
        is_sql_identifier_char(text[start].to_int().unsafe_to_char()) {
    start = start - 1
  }
  let raw = substring(text, start + 1, end + 1)
  let name = unqualify_identifier(raw)
  if name.length() == 0 {
    None
  } else {
    Some(name)
  }
}

///|
fn unqualify_identifier(raw : String) -> String {
  let mut dot = -1
  for i = 0; i < raw.length(); i = i + 1 {
    if raw[i] == '.' {
      dot = i
    }
  }
  let base = substring(raw, dot + 1, raw.length())
  if base.length() >= 2 && base[0] == '"' && base[base.length() - 1] == '"' {
    substring(base, 1, base.length() - 1)
  } else {
    base
  }
}

///|
fn find_catalog_column(
  catalog : @plugin.Catalog,
  table_name : String,
  column_name : String,
) -> @plugin.Column? {
  for schema in catalog.schemas {
    for table in schema.tables {
      if table_name.length() == 0 || table.rel.name == table_name {
        for col in table.columns {
          if col.name == column_name || col.original_name == column_name {
            return Some(col)
          }
        }
      }
    }
  }
  None
}

///|
fn synthetic_named_param_column(
  name : String,
  source : @plugin.Column,
) -> @plugin.Column {
  @plugin.Column::{
    name,
    not_null: source.not_null,
    is_array: false,
    comment: "",
    length: source.length,
    is_named_param: true,
    is_func_call: false,
    scope: "",
    table: source.table,
    table_alias: "",
    type_: source.type_,
    is_sqlc_slice: false,
    embed_table: @plugin.Identifier::default(),
    original_name: source.name,
    unsigned: source.unsigned,
    array_dims: 0,
  }
}

///|
fn string_matches_at(text : String, start : Int, needle : String) -> Bool {
  if start < 0 || start + needle.length() > text.length() {
    return false
  }
  for i = 0; i < needle.length(); i = i + 1 {
    if text[start + i] != needle[i] {
      return false
    }
  }
  true
}

///|
fn is_ascii_space(c : Char) -> Bool {
  c == ' ' || c == '\t' || c == '\n' || c == '\r'
}

///|
fn is_ascii_alpha(c : Char) -> Bool {
  (c >= 'a' && c <= 'z') || (c >= 'A' && c <= 'Z')
}

///|
fn is_ascii_digit(c : Char) -> Bool {
  c >= '0' && c <= '9'
}

///|
fn is_sql_identifier_char(c : Char) -> Bool {
  is_ascii_alpha(c) || is_ascii_digit(c) || c == '_' || c == '.' || c == '"'
}
