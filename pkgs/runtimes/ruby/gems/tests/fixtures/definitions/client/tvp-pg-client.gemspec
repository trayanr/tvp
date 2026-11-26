Gem::Specification.new do |spec|
  spec.name = 'tvp-pg-client'
  spec.version = '1.0.0'
  spec.summary = 'Synthetic consumer of a gem with a named native dependency'
  spec.authors = ['TVP']
  spec.license = 'MIT'
  spec.files = ['lib/tvp_pg_client.rb']
  spec.add_dependency 'pg', '= 1.0.0'
end
