Gem::Specification.new do |spec|
  spec.name = 'tvp-support'
  spec.version = '1.0.0'
  spec.summary = 'Synthetic transitive Ruby build dependency'
  spec.authors = ['TVP']
  spec.license = 'MIT'
  spec.files = ['lib/tvp_support.rb']
  spec.add_dependency 'tvp-pure', '= 1.0.0'
end
