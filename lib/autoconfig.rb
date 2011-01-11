require 'ostruct'
require 'yaml'

module AutoConfig
  def self.root
    ENV['AUTOCONFIG_ROOT'] || ENV['APP_ROOT'] || Rails.root
  end

  def self.pattern
    ENV['AUTOCONFIG_PATTERN'] || 'config/*.yml'
  end

  def self.path
    ENV['AUTOCONFIG_PATH'] || File.expand_path(pattern, root)
  end

  def self.environment
    ENV['AUTOCONFIG_ENV'] || ENV['APP_ENV'] || Rails.env
  end

  files = Dir.glob(path)

  begin
    old_verbose, $VERBOSE = $VERBOSE, nil

    files.each do |file|
      name = File.basename(file, '.yml')
      next if name.match(/database/)

      config     = YAML.load_file(file)
      app_config = config['common'] || {}
      app_config.update(config['defaults'] || {})
      app_config.update(config[environment] || {})

      Object::const_set("#{name}Config".camelize.intern, OpenStruct.new(app_config))
    end
  ensure
    $VERBOSE = old_verbose
  end
end