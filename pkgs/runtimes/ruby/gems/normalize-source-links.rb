# Older RubyGems treats a bare relative link as gem-root-relative when packaging,
# then extracts it relative to its containing directory. An explicit ./ keeps
# the source link's meaning through both operations.
require "find"
require "pathname"

prepared = File.realpath(ARGV.fetch(0))
root = File.realpath(Dir.pwd)
unless root == prepared || root.start_with?(prepared + File::SEPARATOR)
  abort "TVP Ruby gem: normalize symlinks only inside the prepared source copy"
end

Find.find(".") do |path|
  Find.prune if File.basename(path) == ".git" && File.directory?(path)
  next unless File.symlink?(path)
  target = File.readlink(path)
  next if Pathname.new(target).absolute? || target.start_with?(".")
  File.unlink(path)
  File.symlink("./#{target}", path)
end
