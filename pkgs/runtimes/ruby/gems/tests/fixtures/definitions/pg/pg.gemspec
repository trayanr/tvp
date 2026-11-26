Gem::Specification.new do |spec|
  spec.name = 'pg'
  spec.version = '1.0.0'
  spec.summary = 'Synthetic named native dependency fixture'
  spec.authors = ['TVP']
  spec.license = 'MIT'
  spec.files = Dir['lib/**/*.rb', 'ext/**/*']
  spec.extensions = ['ext/pg_fixture/extconf.rb']
end
