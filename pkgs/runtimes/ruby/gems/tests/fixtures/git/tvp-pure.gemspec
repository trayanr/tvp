Gem::Specification.new do |spec|
  spec.name = 'tvp-pure'
  spec.version = '1.0.0'
  spec.summary = 'Synthetic exported Git source fixture'
  spec.authors = ['TVP']
  spec.license = 'MIT'
  spec.files = IO.popen(['git', 'ls-files', '-z'], &:read).split("\0") + ['/dist/widget.js']
end
