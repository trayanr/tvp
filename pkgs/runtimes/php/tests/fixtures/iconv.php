<?php
if (iconv("UTF-8", "ISO-8859-1", "\xC3\xA9") !== "\xE9") exit(1);
$error_count = 0;
function tvp_iconv_error($errno, $message) {
    global $error_count;
    $error_count++;
    fwrite(STDERR, "iconv diagnostic: " . $errno . " " . $message . "\n");
    return true;
}
set_error_handler("tvp_iconv_error");
$invalid = iconv("UTF-8", "UTF-8", "\xFF");
restore_error_handler();
echo "converted\n" . gettype($invalid) . ":";
echo is_string($invalid) ? bin2hex($invalid) : var_export($invalid, true);
echo ":" . $error_count;
