<?php
$socket = getenv('TVP_POSTGRES_SOCKET');
$connection = new PDO("pgsql:host=$socket;dbname=postgres", 'tvp_smoke');
$statement = $connection->prepare('SELECT CAST(? AS integer) + 1');
$statement->execute([41]);
if ((int) $statement->fetchColumn() !== 42) {
    throw new RuntimeException('PDO PostgreSQL did not return the bound value');
}
echo 'pdo-pgsql-roundtrip';
