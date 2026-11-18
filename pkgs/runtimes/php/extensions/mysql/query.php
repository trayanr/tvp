<?php

$socket = getenv('TVP_MYSQL_SOCKET');
$database = $user = 'tvp_smoke';
$password = 'tvp-local-fixture';
$marker = 'mysql-smoke-roundtrip';
$create = 'CREATE TEMPORARY TABLE smoke (id INT PRIMARY KEY, payload VARCHAR(64) NOT NULL)';
$insert = 'INSERT INTO smoke (id, payload) VALUES (1, ?)';
$select = 'SELECT payload FROM smoke WHERE id = 1';

switch ($argv[1]) {
    case 'mysqli':
        mysqli_report(MYSQLI_REPORT_ERROR | MYSQLI_REPORT_STRICT);
        $db = new mysqli('localhost', $user, $password, $database, 0, $socket);
        $db->query($create);
        $stmt = $db->prepare($insert);
        $stmt->bind_param('s', $marker);
        $stmt->execute();
        $stmt->close();
        $actual = $db->query($select)->fetch_row()[0];
        break;

    case 'pdo_mysql':
        $db = new PDO("mysql:unix_socket=$socket;dbname=$database", $user, $password, [
            PDO::ATTR_ERRMODE => PDO::ERRMODE_EXCEPTION,
            PDO::ATTR_EMULATE_PREPARES => false,
        ]);
        $db->exec($create);
        $db->prepare($insert)->execute([$marker]);
        $actual = $db->query($select)->fetchColumn();
        break;

    default:
        throw new RuntimeException('Unknown MySQL driver');
}

if ($actual !== $marker) {
    throw new RuntimeException('Value read back from MariaDB did not match the inserted value');
}
echo $actual;
