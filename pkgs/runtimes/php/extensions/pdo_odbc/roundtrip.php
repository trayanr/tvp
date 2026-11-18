<?php
$connection = new PDO('odbc:tvp_fixture');
$connection->exec('CREATE TABLE fixture (id INTEGER PRIMARY KEY, value TEXT NOT NULL)');
$insert = $connection->prepare('INSERT INTO fixture VALUES (?, ?)');
$value = "it's from PDO over ODBC";
$insert->execute([42, $value]);
$query = $connection->prepare('SELECT value FROM fixture WHERE id = ?');
$query->execute([42]);
if ($query->fetchColumn() !== $value) {
    throw new RuntimeException('PDO ODBC parameter roundtrip failed');
}
echo 'pdo-odbc-roundtrip';
