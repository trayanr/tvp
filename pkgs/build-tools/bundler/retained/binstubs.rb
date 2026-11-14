require "rubygems"
require "fileutils"

ruby, out, gem_home, ruby_gem_home = ARGV

spec = Gem::Specification.load(Dir.glob(File.join(gem_home, "specifications", "*.gemspec")).first)
install_path = Dir.glob(File.join(gem_home, "gems", "*")).first

FileUtils.mkdir_p(File.join(out, "nix-support"))
File.open(File.join(out, "nix-support", "setup-hook"), "a") do |f|
  f.puts("addToSearchPath GEM_PATH #{gem_home}")
  spec.require_paths.each { |dir| f.puts("addToSearchPath RUBYLIB #{install_path}/#{dir}") }
end

# The search path is written out rather than read from the environment: the
# build sandbox has GEM_PATH set and a user running `nix shell` does not.
FileUtils.mkdir_p(File.join(out, "bin"))
spec.executables.each do |exe|
  path = File.join(out, "bin", exe)
  File.write(path, <<~STUB)
    #!#{ruby}
    require "rubygems"

    Gem.paths = {
      "GEM_PATH" => (
        ENV["GEM_PATH"].to_s.split(File::PATH_SEPARATOR) +
        #{[gem_home, ruby_gem_home].inspect}
      ).join(File::PATH_SEPARATOR)
    }

    # Pinned by version: Ruby ships bundler as a default gem, and resolving by
    # name alone yields whichever copy is newest on GEM_PATH.
    load Gem.activate_bin_path(#{spec.name.inspect}, #{exe.inspect}, #{spec.version.to_s.inspect})
  STUB
  FileUtils.chmod("+x", path)
end
