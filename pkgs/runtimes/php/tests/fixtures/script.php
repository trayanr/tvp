<?php
$seen = [];
foreach (["tvp", "nix", "tvp", "preserves", "nix"] as $w) {
    $seen[$w] = true;
}
echo implode(" ", array_keys($seen));
