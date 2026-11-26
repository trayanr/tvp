Gem::Specification.new do |spec|
  spec.name = 'tvp-transitive'
  spec.version = '1.0.0'
  spec.summary = 'Synthetic native gem with a transitive build dependency'
  spec.authors = ['TVP']
  spec.license = 'MIT'
  spec.files = ['ext/tvp_transitive/extconf.rb', 'ext/tvp_transitive/tvp_transitive.c']
  spec.extensions = ['ext/tvp_transitive/extconf.rb']
  spec.add_dependency 'tvp-support', '= 1.0.0'
end
