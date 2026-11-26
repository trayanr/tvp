# Identity and interpreter compatibility are checked before this source step.
require "rubygems/package"
require "fileutils"

archive, destination = ARGV
package = Gem::Package.new(archive)
FileUtils.mkdir_p(destination)
package.extract_files(destination)
File.write(File.join(destination, "#{package.spec.name}.gemspec"), package.spec.to_ruby)
