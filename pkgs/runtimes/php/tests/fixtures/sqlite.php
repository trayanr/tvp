<?php
$db = new PDO("sqlite::memory:");
$db->exec("create table t (w text)");
$db->exec("insert into t values ('tvp')");
$direct = new SQLite3(":memory:");
echo $db->query("select w from t")->fetchColumn(), " ", $direct->querySingle("select 'preserved'");
