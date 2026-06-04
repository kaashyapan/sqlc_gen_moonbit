///|
async fn create_user(client : @client.Client) -> Int {
  let name = "Elon Musk"
  let email = "elon@tesla.com"
  let uuid_var = @uuid.from_hex("019e092f-c489-7475-bbec-b615291e14b7") |> Some
  let timestampz_var = @time.ZonedDateTime::of(
      2017,
      11,
      8,
      hour=16,
      minute=20,
      second=14,
      nanosecond=0,
      zone=@time.utc_zone,
    )
    |> Some
  let timestamp_var = @time.PlainDateTime::of(
    2017,
    11,
    8,
    hour=16,
    minute=20,
    second=14,
  )
  let date_var = @time.PlainDate::of(2020, 5, 6)
  let time_var = @time.PlainTime::of(20, 15, 6, 0)
  let interval_var = (
    @time.Period::of(months=3, days=20),
    @time.Duration::of(hours=5, minutes=20, seconds=0),
  )
  let timetz_var = (
    @time.PlainTime::of(20, 15, 6, 0),
    @time.ZoneOffset::of(hours=5, minutes=30),
  )
  println(date_var)
  @sql.create_user(client, name~, email~, date_var~)
}

///|
async fn update_user(client : @client.Client, id : Int) -> Int {
  let name = "Jeff Bezos"
  let email = "elon@tesla.com"
  let uuid_var = @uuid.from_hex("019e092f-c489-7475-bbec-b615291e14b7")
  let timestampz_var = @time.ZonedDateTime::of(
    2017,
    11,
    8,
    hour=16,
    minute=20,
    second=14,
  )
  let timestamp_var = @time.PlainDateTime::of(
    2017,
    11,
    8,
    hour=16,
    minute=20,
    second=14,
  )
  let date_var = @time.PlainDate::of(2020, 5, 6)
  let time_var = @time.PlainTime::of(20, 15, 6, 0)
  let interval_var = (
    @time.Period::of(months=3, days=20),
    @time.Duration::of(hours=5, minutes=20, seconds=0),
  )
  let timetz_var = (
    @time.PlainTime::of(20, 15, 6, 0),
    @time.ZoneOffset::of(hours=5, minutes=30),
  )
  @sql.update_user(client, name~, email~, id~, date_var~)
}

///|
async fn main {
  println("PostgreSQL example with sqlc-gen-moonbit")
  println("Generated types and queries are in db/gen/")

  let config = @client.Config::new(
    "postgres",
    user="xxxxx",
    database="xxxxx",
    password="xxxxxx",
    port=5432,
    ssl_mode=@client.SslMode::Disable,
    application_name="my-service",
  )

  @async.with_task_group(group => {
    let (client, connection) = @client.connect(config)

    group.spawn_bg(() => connection.run())

    let current_user : String = client
      .query_one("select current_user::text as current_user")
      .get_name("current_user")
    println("Current_user : " + current_user)

    let serial = create_user(client)
    println("Inserted \{serial} serial")

    let rows = update_user(client, 1) catch {
      err => {
        println(err)
        0
      }
    }
    println("Updated \{rows} rows")

    let row = @sql.get_user(client, id=1)
    println(
      "Select row \{row.id} - \{row.name} - \{row.email} - \{row.created_at} - \{row.date_var}",
    )

    let rows = @sql.get_by_date(
      client,
      date_var=@time.PlainDate::of(2020, 5, 6),
    ) catch {
      err => {
        println("Get by Date failed - " + err.to_string())
        []
      }
    }
    for row in rows {
      println(
        "Select by date row \{row.id} - \{row.name} - \{row.email} - \{row.created_at} - \{row.date_var}",
      )
    }

    let rows = @sql.get_by_uuid(
      client,
      uuid_var=Some(@uuid.from_hex("019dc341-9b48-77e4-806a-7a303d5395f5")),
    ) catch {
      err => {
        println("Get by UUID failed - " + err.to_string())
        []
      }
    }
    for row in rows {
      println(
        "Select by uuid row \{row.id} - \{row.name} - \{row.email} - \{row.created_at} - \{row.date_var}",
      )
    }
    //let rows = @sql.delete_user(client, id=10)
    //println("Deleted \{rows} rows")

    let rows = @sql.list_users(client)
    println("Total \{rows.length()} rows")

    client.close()
  })
}
