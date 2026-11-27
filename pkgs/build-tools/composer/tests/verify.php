<?php

$lock = json_decode(file_get_contents('composer.lock'), true, 512, JSON_THROW_ON_ERROR);
$versions = array_column($lock['packages'], 'version', 'name');
if ($versions !== ['tvp-fixture/message' => '1.2.0']) {
    throw new RuntimeException('Unexpected locked versions: ' . json_encode($versions));
}

require './vendor/autoload.php';
echo TvpFixture\Message::TEXT;
