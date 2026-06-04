-- name: GetUser :one
SELECT * FROM test_users WHERE id = $1;

-- name: GetByDate :many
SELECT * FROM test_users WHERE date_var = $1;

-- name: GetByUuid :many
SELECT * FROM test_users WHERE uuid_var = $1;

-- name: ListUsers :many
SELECT * FROM test_users ORDER BY id;

-- name: CreateUser :execlastid
INSERT INTO test_users (name, email, uuid_var, date_var) VALUES ($1, $2, $3, $4) RETURNING id;

-- name: UpdateUser :execrows
UPDATE test_users SET name = $2, email = $3, date_var = $4 WHERE id = $1;

-- name: DeleteUser :exec
DELETE FROM test_users WHERE id = $1;
