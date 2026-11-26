require "json"
require "fileutils"
require "shellwords"

manifest_path, out = ARGV
manifest = JSON.parse(File.read(manifest_path))
application = File.join(out, "share", manifest.fetch("name"))
bin = File.join(out, "bin")
FileUtils.mkdir_p(bin)

defaults = manifest.fetch("environment").map do |name, value|
  "if test \"${#{name}+x}\" != x; then\n  export #{name}=#{Shellwords.escape(value)}\nfi"
end.join("\n")
manifest.fetch("commands").each do |name, argv|
  executable = File.join(manifest.fetch("bundle"), "bin", argv.first)
  abort "TVP Ruby application: bundle has no executable #{argv.first}" unless File.file?(executable) && File.executable?(executable)
  command = [executable, *argv.drop(1)].map { |part| Shellwords.escape(part) }.join(" ")
  wrapper = ["#!#{manifest.fetch('shell')}", "set -e", defaults,
             "cd -- #{Shellwords.escape(application)}", "exec #{command} \"$@\"", ""].join("\n")
  path = File.join(bin, name)
  File.write(path, wrapper)
  FileUtils.chmod(0755, path)
end
