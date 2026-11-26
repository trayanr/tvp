File.binwrite('payload/foreign-elf32', [File.read('payload/foreign-elf32.hex').strip].pack('H*'))

Gem::Specification.new do |spec|
  spec.name = 'tvp-native'
  spec.version = '1.0.0'
  spec.summary = 'Synthetic native Ruby package fixture'
  spec.authors = ['TVP']
  spec.license = 'MIT'
  spec.files = ['ext/tvp_native/extconf.rb', 'ext/tvp_native/tvp_native.c',
                'payload/foreign-elf32', 'payload/native-helper.c']
  spec.extensions = ['ext/tvp_native/extconf.rb']
end
