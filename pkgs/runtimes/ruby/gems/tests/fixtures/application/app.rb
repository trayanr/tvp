require "bundler/setup"
require "tvp_pure"
require "tvp_native"
require "json"

if ARGV.first == "exit"
  exit Integer(ARGV.fetch(1))
end
abort "Application directory is writable" if File.writable?(__dir__)
abort "Command did not enter application directory" unless Dir.pwd == __dir__
puts JSON.generate(
  "arguments" => ARGV,
  "ruby" => RUBY_VERSION,
  "bundler" => Bundler::VERSION,
  "answer" => [TvpPure::ANSWER, TvpNative.answer],
  "asset" => File.read("public/message.txt"),
  "mode" => ENV.fetch("TVP_APP_MODE"),
  "literal" => ENV.fetch("TVP_APP_LITERAL")
)
