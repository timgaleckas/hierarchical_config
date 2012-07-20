require 'rake'

Gem::Specification.new do |s|
  s.name = %q{hierarchical_config}
  s.version = '0.4'

  s.required_rubygems_version = Gem::Requirement.new('>= 0') if s.respond_to? :required_rubygems_version=
  s.authors = ['timgaleckas', 'tjbladez', 'jdfrens']
  s.date = %q{2012-07-19}
  s.description = %q{Robust strategy for defining the configuration accross environements, machines, clusters}
  s.email = %q{tim@galeckas.com, nick@tjbladez.com}
  s.files = FileList['lib/**/*', 'README.markdown'].to_a
  s.has_rdoc = false
  s.homepage = %q{http://github.com/timgaleckas/hierarchical_config}
  s.summary = %q{Robust strategy for defining the configuration accross environements, machines, clusters}
end
