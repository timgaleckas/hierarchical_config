require 'ostruct'
require 'yaml'

module StringCamelize
  # Taken straight from active support inflector.rb, line 161
  def camelize(first_letter_in_uppercase = true)
    if first_letter_in_uppercase
      self.to_s.gsub(/\/(.?)/) { "::#{$1.upcase}" }.gsub(/(?:^|_)(.)/) { $1.upcase }
    else
      self.first + camelize(self)[1..-1]
    end
  end
end
String.send(:include, StringCamelize) unless String.instance_methods.include?("camelize")

module AutoConfig
  def self.root
    rails_root = (rails? && (Rails.root || File.expand_path('../', ENV['BUNDLE_GEMFILE'])))
    ENV['AUTOCONFIG_ROOT'] || ENV['APP_ROOT'] || rails_root || base_dir
  end

  def self.pattern
    ENV['AUTOCONFIG_PATTERN'] || 'config/*.yml'
  end

  def self.path
    ENV['AUTOCONFIG_PATH'] || File.expand_path(pattern, root)
  end

  def self.environment
    ENV['AUTOCONFIG_ENV'] || ENV['APP_ENV'] || (rails? && Rails.env) || 'development'
  end

  def self.rails?
    Object::const_defined? "Rails"
  end

  def self.base_dir
    File.dirname(File.expand_path(__FILE__))
  end

  def self.ignored_filenames
    names = ENV['AUTOCONFIG_IGNORE'] ? "database|" + ENV['AUTOCONFIG_IGNORE'].gsub(/\s/,'|') : 'database'
    Regexp.new(names)
  end

  files = Dir.glob(path)

  begin
    old_verbose, $VERBOSE = $VERBOSE, nil

    files.each do |file|
      name = File.basename(file, '.yml')
      next if name.match(ignored_filenames)

      config     = YAML.load_file(file)
      app_config = config['common'] || {}
      app_config.update(config['defaults'] || {})
      app_config.update(config[environment] || {})

      Object::const_set("#{name}Config".gsub('-','_').camelize.intern, OpenStruct.new(app_config))
    end
  ensure
    $VERBOSE = old_verbose
  end
end
