set message "tvp preserves what other software is built on"
set packed [zlib compress $message]
puts [zlib decompress $packed]
