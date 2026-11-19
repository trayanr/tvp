<?php
$image = imagecreatetruecolor(16, 16);
$rgb = [48, 96, 144];
imagefill($image, 0, 0, imagecolorallocate($image, ...$rgb));

foreach ([
    "png" => [imagepng(...), imagecreatefrompng(...), 0],
    "jpeg" => [imagejpeg(...), imagecreatefromjpeg(...), 3],
    "webp" => [imagewebp(...), imagecreatefromwebp(...), 5],
] as $format => [$encode, $decode, $tolerance]) {
    $path = "fixture." . $format;
    if (!$encode($image, $path)) {
        throw new RuntimeException("Could not encode " . $format);
    }
    $decoded = $decode($path);
    if ($decoded === false || imagesx($decoded) !== 16 || imagesy($decoded) !== 16) {
        throw new RuntimeException("Wrong dimensions after decoding " . $format);
    }
    $pixel = imagecolorat($decoded, 8, 8);
    foreach ([16, 8, 0] as $channel => $shift) {
        if (abs((($pixel >> $shift) & 255) - $rgb[$channel]) > $tolerance) {
            throw new RuntimeException("Wrong pixel after decoding " . $format);
        }
    }
}

echo "png jpeg webp";
