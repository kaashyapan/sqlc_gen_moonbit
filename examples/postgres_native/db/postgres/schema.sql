--DROP TABLE test_users ;

CREATE TABLE IF NOT EXISTS test_users (
    id SERIAL PRIMARY KEY,
    name VARCHAR(255) NOT NULL,
    email VARCHAR(255) NOT NULL,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    "uuid_var" uuid,
    "date_var" date NOT NULL
);

-- INSERT INTO "public"."test_users" ("id", "name", "email", "created_at", "uuid_var", "date_var") VALUES (1, 'Elon', 'elon@tesla.com', '2026-06-01 01:49:43.664991', '019dc341-9b48-77e4-806a-7a303d5395f5', '2026-06-01');
