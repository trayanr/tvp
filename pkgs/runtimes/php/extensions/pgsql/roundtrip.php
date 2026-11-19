<?php
$socket = getenv('TVP_POSTGRES_SOCKET');
$connection = pg_connect("host='$socket' dbname=postgres user=tvp_smoke");
if ($connection === false) {
    throw new RuntimeException('PostgreSQL socket connection failed');
}
$result = pg_query_params($connection, 'SELECT $1::integer + 1, $2::text', [41, "it's UTF-8: é"]);
if ($result === false || pg_fetch_row($result) !== ['42', "it's UTF-8: é"]) {
    throw new RuntimeException('PostgreSQL parameter roundtrip failed');
}
echo 'pgsql-roundtrip';
