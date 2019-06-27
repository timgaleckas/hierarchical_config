lib = File.expand_path('lib', __dir__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)
require 'hierarchical_config/version'

Gem::Specification.new do |spec|
  spec.name          = 'hierarchical_config'
  spec.version       = HierarchicalConfig::VERSION
  spec.authors       = %w[timgaleckas tjbladez jdfrens]
  spec.email         = 'tim@galeckas.com, nick@tjbladez.com'
  spec.summary       = 'Robust strategy for defining the configuration accross environments, machines, clusters'
  spec.description   = 'Robust strategy for defining the configuration accross environments, machines, clusters'
  spec.homepage      = 'http://github.com/timgaleckas/hierarchical_config'
  spec.license       = 'MIT'

  # Specify which files should be added to the gem when it is released.
  # The `git ls-files -z` loads the files in the RubyGem that have been added into git.
  spec.files         = Dir.chdir(File.expand_path(__dir__)) do
    `git ls-files -z`.split("\x0").reject{|f| f.match(%r{^(test|spec|features)/})}
  end
  spec.bindir        = 'exe'
  spec.executables   = spec.files.grep(%r{^exe/}){|f| File.basename(f)}
  spec.require_paths = ['lib']

  spec.add_dependency 'activesupport'
  spec.add_dependency 'sorbet-runtime'

  spec.add_development_dependency 'bundler'
  spec.add_development_dependency 'pry'
  spec.add_development_dependency 'pry-rescue'
  spec.add_development_dependency 'pry-stack_explorer'
  spec.add_development_dependency 'rake'
  spec.add_development_dependency 'rspec'
  spec.add_development_dependency 'rubocop'
  spec.add_development_dependency 'rubocop-performance'
  spec.add_development_dependency 'sorbet'
end
