require "bundler/setup"
require "tvp_pure"
require "fileutils"

abort "Wrong build Ruby" unless RUBY_VERSION == ENV.fetch("TVP_EXPECTED_RUBY")
abort "Wrong build Bundler" unless Bundler::VERSION == ENV.fetch("TVP_EXPECTED_BUNDLER")
abort "Missing build environment" unless ENV.fetch("TVP_APP_MODE") == "build and runtime default"
FileUtils.mkdir_p("public")
File.write("public/message.txt", File.read("assets/message.txt").upcase + "gem answer: #{TvpPure::ANSWER}\n")
