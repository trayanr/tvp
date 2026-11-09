require 'openssl'
require 'zlib'
require 'yaml'
require 'fiddle'
require 'json'
require 'socket'
require 'rubygems'
require 'bundler'
abort unless OpenSSL::Digest::SHA256.hexdigest('tvp').start_with?('f6f6ead0bd85c312')
abort unless Zlib::Inflate.inflate(Zlib::Deflate.deflate('tvp' * 100)) == 'tvp' * 100
abort unless YAML.safe_load(YAML.dump({'tvp' => [1,2]})) == {'tvp' => [1,2]}
abort unless Fiddle::Function.new(Fiddle::Handle::DEFAULT['strlen'], [Fiddle::TYPE_VOIDP], Fiddle::TYPE_SIZE_T).call('tvp') == 3
abort unless JSON.parse(JSON.generate({'tvp' => 42}))['tvp'] == 42
abort unless Gem.default_dir == File.join(RbConfig::CONFIG['prefix'], 'lib/ruby/gems/3.4.0')
abort unless Encoding.default_external == Encoding::UTF_8
# A local TLS exchange exercises SSL objects and sockets, without network or CA dependencies.
key = OpenSSL::PKey::RSA.new(2048)
cert = OpenSSL::X509::Certificate.new
cert.version = 2
cert.serial = 1
cert.subject = cert.issuer = OpenSSL::X509::Name.parse('/CN=localhost')
cert.public_key = key.public_key
cert.not_before = Time.at(0)
cert.not_after = Time.at(2**31)
cert.sign(key, OpenSSL::Digest.new('SHA256'))
context = OpenSSL::SSL::SSLContext.new
context.cert = cert
context.key = key
listener = TCPServer.new('127.0.0.1', 0)
server = OpenSSL::SSL::SSLServer.new(listener, context)
thread = Thread.new { server.accept.tap { |s| s.write(s.read(3).upcase); s.close } }
client_context = OpenSSL::SSL::SSLContext.new
client_context.verify_mode = OpenSSL::SSL::VERIFY_NONE
client = OpenSSL::SSL::SSLSocket.new(TCPSocket.new('127.0.0.1', listener.addr[1]), client_context)
client.connect
client.write('tvp')
abort unless client.read(3) == 'TVP'
client.close
thread.value
listener.close
puts 'owned-runtime-ok'
begin
  YAML.safe_load("a: [bad")
  abort "invalid YAML accepted"
rescue Psych::SyntaxError
end
begin
  Zlib::Inflate.inflate("not-deflate")
  abort "invalid deflate accepted"
rescue Zlib::DataError
end
