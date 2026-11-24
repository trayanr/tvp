# Assemble already installed gems. Dependency fetching and compilation happen upstream.
require "json"
require "fileutils"
require "pathname"
require "shellwords"
require "bundler"

manifest_path, out = ARGV
manifest = JSON.parse(File.read(manifest_path))
home = File.join(out, manifest.fetch("rubyGemPath"))
project = File.join(out, "project")
FileUtils.mkdir_p([home, File.join(out, "bin")])

def link(source, target)
  FileUtils.mkdir_p(File.dirname(target))
  if File.exist?(target) || File.symlink?(target)
    raise "Conflicting gem files at #{target}" unless File.realpath(target) == File.realpath(source)
  else
    File.symlink(source, target)
  end
end

# A supplied project can already contain the local gem's source files. Overlay
# the installed result while retaining project files absent from the gem.
def overlay(source, target, protected_paths)
  return if protected_paths.include?(target)
  if File.directory?(source) && !File.symlink?(source) && File.directory?(target) && !File.symlink?(target)
    Dir.children(source).each do |entry|
      overlay(File.join(source, entry), File.join(target, entry), protected_paths)
    end
  else
    FileUtils.rm_rf(target) if File.exist?(target) || File.symlink?(target)
    link(source, target)
  end
end

packages = manifest.fetch("packages").each_with_object({}) do |package, result|
  result[package.fetch("name")] = package
  %w[gems specifications cache build_info].each do |directory|
    Dir.glob(File.join(package.fetch("home"), directory, "*")).each do |path|
      link(path, File.join(home, directory, File.basename(path)))
    end
  end
  Dir.glob(File.join(package.fetch("home"), "extensions", "*", "*", "*")).each do |path|
    suffix = Pathname.new(path).relative_path_from(Pathname.new(package.fetch("home")))
    link(path, File.join(home, suffix.to_s))
  end
end

# Preserve the lockfile's source identities while supplying the installed layout
# Bundler expects for Git and path dependencies. RubyGems produced native extensions
# in the individual gem derivation before this composition step.
ENV["BUNDLE_GEMFILE"] = File.join(project, "Gemfile")
ENV["BUNDLE_IGNORE_CONFIG"] = "true"
ENV["GEM_HOME"] = home
ENV["GEM_PATH"] = [home, File.join(manifest.fetch("ruby"), manifest.fetch("rubyGemPath")),
                   File.join(manifest.fetch("bundler"), manifest.fetch("rubyGemPath"))].join(File::PATH_SEPARATOR)
Gem.paths = ENV
Bundler.reset!
lock = Bundler::LockfileParser.new(File.read(File.join(project, "Gemfile.lock")))
if lock.bundler_version && lock.bundler_version.to_s != manifest.fetch("bundlerVersion")
  raise "Selected Bundler does not match the lockfile's BUNDLED WITH version"
end
lock.specs.each do |locked|
  package = packages[locked.name]
  next unless package
  raise "Gemset version differs from lockfile for #{locked.name}" unless package.fetch("version") == locked.version.to_s
  source = locked.source
  next unless source.is_a?(Bundler::Source::Path)
  git_source = source.is_a?(Bundler::Source::Git)
  target = if git_source
    glob = source.options["glob"]
    if glob && glob != Bundler::Source::Path::DEFAULT_GLOB
      raise "Git dependency #{locked.name} uses an unsupported gemspec glob #{glob.inspect}"
    end
    File.join(source.install_path.to_s, locked.name)
  else
    File.expand_path(source.options.fetch("path"), project)
  end
  root = git_source ? out : project
  unless target == root || target.start_with?(root + "/")
    raise "Path dependency #{locked.name} must resolve inside the project source"
  end
  ancestor = target
  ancestor = File.dirname(ancestor) until File.exist?(ancestor) || File.symlink?(ancestor)
  resolved = File.realpath(ancestor)
  unless resolved == root || resolved.start_with?(root + "/")
    raise "Dependency #{locked.name} resolves through a symlink outside its output source"
  end
  FileUtils.mkdir_p(target)
  protected_paths = %w[Gemfile Gemfile.lock].map { |entry| File.join(project, entry) }
  Dir.children(package.fetch("directory")).each do |entry|
    next if entry.end_with?(".gemspec")
    overlay(File.join(package.fetch("directory"), entry), File.join(target, entry), protected_paths)
  end
  spec = Gem::Specification.load(package.fetch("specification"))
  spec_path = File.join(target, "#{spec.name}.gemspec")
  FileUtils.rm_f(spec_path)
  File.write(spec_path, spec.to_ruby)
end

settings = {
  "GEM_HOME" => home,
  "GEM_PATH" => ENV.fetch("GEM_PATH"),
  "BUNDLE_GEMFILE" => File.join(project, "Gemfile"),
  "BUNDLE_FROZEN" => "true",
  "BUNDLE_IGNORE_CONFIG" => "true",
  "BUNDLE_WITHOUT" => manifest.fetch("excludedGroups").join(":"),
  "RUBYLIB" => File.join(manifest.fetch("bundler"), manifest.fetch("rubyGemPath"),
                         "gems", "bundler-#{manifest.fetch("bundlerVersion")}", "lib"),
}

def write_wrapper(path, shell, settings, command)
  exports = settings.map { |key, value| "export #{key}=#{Shellwords.escape(value)}" }.join("\n")
  own_path = Shellwords.escape(File.dirname(path))
  File.write(path, "#!#{shell}\nunset BUNDLE_PATH\n#{exports}\nexport PATH=#{own_path}:\"$PATH\"\nexec #{command} \"$@\"\n")
  FileUtils.chmod(0755, path)
end

Dir.glob(File.join(manifest.fetch("ruby"), "bin", "*")).each do |executable|
  write_wrapper(File.join(out, "bin", File.basename(executable)), manifest.fetch("shell"), settings,
                Shellwords.escape(executable))
end
packages.each_value do |package|
  spec = Gem::Specification.load(package.fetch("specification"))
  spec.executables.each do |executable|
    script = File.join(package.fetch("directory"), spec.bindir, executable)
    command = [File.join(manifest.fetch("ruby"), "bin", "ruby"), "-rbundler/setup", script].map { |part| Shellwords.escape(part) }.join(" ")
    write_wrapper(File.join(out, "bin", executable), manifest.fetch("shell"), settings, command)
  end
end
%w[bundle bundler].each do |executable|
  write_wrapper(File.join(out, "bin", executable), manifest.fetch("shell"), settings,
                Shellwords.escape(File.join(manifest.fetch("bundler"), "bin", executable)))
end
