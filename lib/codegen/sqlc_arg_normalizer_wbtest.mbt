///|
fn issue18_column(name : String, type_name : String) -> @plugin.Column {
  @plugin.Column::{
    name,
    not_null: true,
    is_array: false,
    comment: "",
    length: -1,
    is_named_param: false,
    is_func_call: false,
    scope: "",
    table: @plugin.Identifier::{ catalog: "", schema: "", name: "t" },
    table_alias: "",
    type_: @plugin.Identifier::{ catalog: "", schema: "", name: type_name },
    is_sqlc_slice: false,
    embed_table: @plugin.Identifier::default(),
    original_name: "",
    unsigned: false,
    array_dims: 0,
  }
}

///|
fn issue18_param(number : Int, col : @plugin.Column) -> @plugin.Parameter {
  @plugin.Parameter::{ number, column: col }
}

///|
fn issue18_request() -> @plugin.GenerateRequest {
  let id_col = issue18_column("id", "INTEGER")
  let value_col = issue18_column("value", "TEXT")
  let slug_col = issue18_column("slug", "TEXT")
  let table = @plugin.Table::{
    rel: @plugin.Identifier::{ catalog: "", schema: "", name: "t" },
    columns: [id_col, value_col, slug_col],
    comment: "",
  }
  let schema = @plugin.Schema::{
    comment: "",
    name: "main",
    tables: [table],
    enums: [],
    composite_types: [],
  }
  let sql =
    #|INSERT INTO t (id, value, slug)
    #|VALUES (?, ?, ?)
    #|ON CONFLICT(id) DO UPDATE SET
    #|  value = excluded.value,
    #|  slug = CASE WHEN sqlc.arg('new_slug') <> '' THEN sqlc.arg('new_slug') ELSE slug END
  let query = @plugin.Query::{
    text: sql,
    name: "UpsertWithSqlcArg",
    cmd: ":exec",
    columns: [],
    params: [
      issue18_param(1, id_col),
      issue18_param(2, value_col),
      issue18_param(3, slug_col),
    ],
    comments: [],
    filename: "query.sql",
    insert_into_table: @plugin.Identifier::{ catalog: "", schema: "", name: "t" },
  }
  let request = @plugin.GenerateRequest::default()
  request.catalog = @plugin.Catalog::{
    comment: "",
    default_schema: "main",
    name: "",
    schemas: [schema],
  }
  request.queries = [query]
  request.sqlc_version = "test"
  request
}

///|
test "normalize sqlc.arg left in ON CONFLICT DO UPDATE" {
  let request = issue18_request()
  normalize_sqlc_args_in_request(request, D1)
  let query = request.queries[0]
  assert_eq(query.params.length(), 4)
  assert_eq(query.params[3].number, 4)
  assert_eq(query.params[3].column.name, "new_slug")
  assert_eq(query.params[3].column.type_.name, "TEXT")
  assert_true(query.params[3].column.is_named_param)
  assert_true(query.text.contains("?4 <> '' THEN ?4"))
  assert_false(query.text.contains("sqlc.arg"))
}

///|
test "normalized sqlc.arg is emitted in types and D1 bind sequence" {
  let request = issue18_request()
  normalize_sqlc_args_in_request(request, D1)
  let options = Options::{ backend: D1, validators: false, json_schema: false, overrides: [] }
  let types = generate_types(request, options)
  assert_true(types.contains("new_slug : String"))
  assert_true(
    types.contains(
      "pub fn UpsertWithSqlcArgParams::new(id : Int64, value : String, slug : String, new_slug : String)",
    ),
  )
  let queries = generate_queries_d1(request, [])
  assert_true(queries.contains(".bind([d1_bind_int64(params.id), @core.any(params.value), @core.any(params.slug), @core.any(params.new_slug)])"))
  assert_false(queries.contains("sqlc.arg"))
}
