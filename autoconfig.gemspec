require 'rake'

Gem::Specification.new do |s|
  s.name = %q{autoconfig}
  s.version = '1.1.0'

  s.required_rubygems_version = Gem::Requirement.new('>= 0') if s.respond_to? :required_rubygems_version=
  s.authors = ['tjbladez', 'timgaleckas']
  s.date = %q{2011-10-12}
  s.description = %q{Automated way to create flexible configuration structures representing your YAML configuration}
  s.email = %q{nick@tjbladez.com, tim@galeckas.com}
  s.files = FileList['lib/**/*', 'README.markdown'].to_a
  s.has_rdoc = false
  s.homepage = %q{http://github.com/tjbladez/autoconfig}
  s.summary = %q{Automagically creates Config structures from your config/*.yml files}
  s.post_install_message = %q{Forget about loading your yaml configuration}
end