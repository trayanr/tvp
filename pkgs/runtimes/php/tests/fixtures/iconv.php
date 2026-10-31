<?php
if (iconv("UTF-8", "ISO-8859-1", "\xC3\xA9") !== "\xE9") exit(1);
if (@iconv("UTF-8", "UTF-8", "\xFF") !== false) exit(2);
echo "converted";
