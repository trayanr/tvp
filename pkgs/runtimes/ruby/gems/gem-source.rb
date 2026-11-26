require "rubygems/package"
require "fileutils"
require "find"

operation, location, name, version, platform = ARGV

def check_identity(spec, name, version, platform)
  unless spec && spec.name == name && spec.version.to_s == version
    abort "TVP Ruby gem: expected #{name} #{version}, found #{spec && spec.full_name}"
  end
  abort "TVP Ruby gem: expected platform #{platform}, found #{spec.platform}" unless spec.platform.to_s == platform
  abort "TVP Ruby gem: platform #{platform} is incompatible with this Ruby" unless Gem::Platform.match(spec.platform)
  unless spec.required_ruby_version.satisfied_by?(Gem.ruby_version)
    abort "TVP Ruby gem: requires Ruby #{spec.required_ruby_version}, selected #{Gem.ruby_version}"
  end
  unless spec.required_rubygems_version.satisfied_by?(Gem::Version.new(Gem::VERSION))
    abort "TVP Ruby gem: requires RubyGems #{spec.required_rubygems_version}, selected #{Gem::VERSION}"
  end
end

case operation
when "verify"
  check_identity(Gem::Package.new(location).spec, name, version, platform)
when "build", "build-git"
  gemspecs = Dir.glob("*.gemspec")
  selected = File.file?("#{name}.gemspec") ? "#{name}.gemspec" : gemspecs.first
  abort "TVP Ruby gem: select a source containing #{name}.gemspec" unless selected && (gemspecs.length == 1 || selected == "#{name}.gemspec")
  spec = Gem::Specification.load(selected)
  check_identity(spec, name, version, platform)
  if operation == "build-git"
    # Bundler Git dependencies use the checked-out tree. Their gemspec's release
    # file list may contain generated or absolute paths which cannot form a gem.
    files = IO.popen(["git", "ls-files", "-z", "--cached", "--", "."], &:read).split("\0")
    abort "TVP Ruby gem: could not enumerate the Git source snapshot" unless $?.success?
    missing = files.reject { |file| File.file?(file) || File.symlink?(file) }
    abort "TVP Ruby gem: Git source snapshot has missing files: #{missing.join(', ')}" unless missing.empty?
    spec.files = files
  end
  archive = Gem::Package.build(spec)
  FileUtils.cp(archive, location)
when "installed"
  candidates = Dir.glob(File.join(location, "specifications", "*.gemspec"))
  abort "TVP Ruby gem: expected exactly one installed gem" unless candidates.length == 1
  check_identity(Gem::Specification.load(candidates.first), name, version, platform)
when "cleanup"
  root = File.join(location, name)
  artifact = version
  FileUtils.rm_rf(File.join(root, "cache"))
  specs = Dir.glob(File.join(root, "specifications", "*.gemspec"))
  specs.each do |path|
    spec = Gem::Specification.load(path)
    spec.extensions.each do |extension|
      directory = File.join(root, "gems", spec.full_name, File.dirname(extension))
      %w[Makefile mkmf.log gem_make.out].each do |file|
        FileUtils.rm_f(File.join(directory, file))
      end
      Dir.glob(File.join(directory, "*.o")).each { |file| FileUtils.rm_f(file) }
    end
  end
  Find.find(root) do |path|
    if File.symlink?(path)
      target = File.readlink(path)
      if target.include?(artifact)
        File.unlink(path)
        File.symlink(target.gsub(artifact, location), path)
      end
    elsif File.file?(path)
      if %w[mkmf.log gem_make.out].include?(File.basename(path))
        File.unlink(path)
      else
        contents = File.binread(path)
        if !contents.include?("\0") && contents.include?(artifact)
          File.binwrite(path, contents.gsub(artifact, location))
        end
      end
    end
  end
else
  abort "TVP Ruby gem: unknown source operation #{operation.inspect}"
end
