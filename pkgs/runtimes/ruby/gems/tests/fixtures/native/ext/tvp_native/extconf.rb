require 'mkmf'
abort 'Ruby development libraries did not link' unless have_func('rb_str_new_cstr', 'ruby.h')

# Mimic a bundled host executable carrying an upstream system interpreter.
payload = File.expand_path('../../payload', __dir__)
helper = File.join(payload, 'native-helper')
abort 'Host executable fixture did not compile' unless system(RbConfig::CONFIG.fetch('CC'),
  File.join(payload, 'native-helper.c'), '-o', helper)
image = File.binread(helper)
phoff = image.byteslice(32, 8).unpack1('Q<')
phsize, phnum = image.byteslice(54, 4).unpack('S<S<')
interpreter = (0...phnum).map { |index| phoff + index * phsize }.find do |position|
  image.byteslice(position, 4).unpack1('L<') == 3
end
abort 'Host executable fixture lacks PT_INTERP' unless interpreter
offset = image.byteslice(interpreter + 8, 8).unpack1('Q<')
length = image.byteslice(interpreter + 32, 8).unpack1('Q<')
system_loader = "/lib64/ld-linux-x86-64.so.2\0"
abort 'Interpreter fixture segment is too small' unless system_loader.bytesize <= length
image[offset, length] = system_loader.ljust(length, "\0")
File.binwrite(helper, image)

create_makefile('tvp_native')
