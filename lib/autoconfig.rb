require 'ostruct'
require 'yaml'
require 'erb'
require 'set'

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
  REQUIRED = :REQUIRED
  YAML.add_builtin_type( 'REQUIRED' ){ REQUIRED }

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

  def self.reload
    self.wipe
    files = Dir.glob(path)
    begin
      old_verbose, $VERBOSE = $VERBOSE, nil

      files.each do |file|
        name = File.basename(file, '.yml')
        next if name.match(ignored_filenames)
        constant_name = "#{name}Config".gsub('-','_').camelize
        @ordered_stanza_labels[constant_name] = []

        yaml_config     = YAML::load(ERB.new(IO.read(file)).result)
        @ordered_stanza_labels[constant_name] = yaml_config.keys.grep(/^defaults$|^defaults\[.*#{environment}/).sort do |label1, label2|
          case
          when ! (label1 =~ /\[/)
            -1
          when ! (label2 =~ /\[/)
            1
          else
            label2.count(',') <=> label1.count(',')
          end
        end
        @ordered_stanza_labels[constant_name] << self.environment if yaml_config[environment]
        config = @ordered_stanza_labels[constant_name].map{|stanza_label|yaml_config[stanza_label]}.inject do |less_specific_stanza, more_specific_stanza|
          deep_merge(less_specific_stanza,more_specific_stanza)
        end
        config ||= {}
        ensure_requirements_met_and_ostructify( config, constant_name )

        Object::const_set(constant_name.intern, OpenStruct.new(config))
      end

      raise self.errors.to_a.join( "\n" ) unless self.errors.empty?

    ensure
      $VERBOSE = old_verbose
    end
  end

  private

  def self.wipe
    unless @ordered_stanza_labels.nil?
      @ordered_stanza_labels.keys.each{|const| Object::const_set(const.intern, nil) }
    end
    @ordered_stanza_labels = {}
    @errors = Set.new
  end

  def self.errors
    @errors
  end

  def self.deep_merge( hash1, hash2 )
    hash1 = hash1.dup
    ( hash1.keys + hash2.keys ).each do | key |
      if hash1.key?( key ) && hash2.key?( key ) &&
         hash1[key].is_a?( Hash ) && hash2[key].is_a?( Hash )
         hash1[key] = deep_merge( hash1[key], hash2[key] )
      elsif hash2.key?( key )
        hash1[key] = hash2[key]
      end
    end
    hash1
  end

  def self.ensure_requirements_met_and_ostructify( hash, path )
    hash.each do | key, value |
      case
      when value.respond_to?( :keys ) && value.respond_to?( :values )
        self.ensure_requirements_met_and_ostructify( value, path + '.' + key )
      when value == REQUIRED
        self.errors << "#{path}.#{key} is REQUIRED"
      end
      hash[key] = OpenStruct.new(value) if value.is_a?( Hash )
    end
  end

end

AutoConfig.reload
