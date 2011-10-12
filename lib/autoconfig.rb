require 'ostruct'
require 'yaml'
require 'erb'
require 'set'


module AutoConfig
  REQUIRED = :REQUIRED
  YAML.add_builtin_type( 'REQUIRED' ){ REQUIRED }

  module StringCamelize
    # Taken straight from active support inflector.rb, line 161
    def camelize(first_letter_in_uppercase = true)
      if first_letter_in_uppercase
        to_s.gsub(/\/(.?)/) { "::#{$1.upcase}" }.gsub(/(?:^|_)(.)/) { $1.upcase }
      else
        first + camelize(self)[1..-1]
      end
    end
  end
  String.send(:include, StringCamelize) unless String.instance_methods.include?("camelize")

  class OpenStruct < ::OpenStruct
    def method_missing(mid, *args) # :nodoc:
      mname = mid.id2name
      len = args.length
      if mname.chomp!('=')
        if len != 1
          raise ArgumentError, "wrong number of arguments (#{len} for 1)", caller(1)
        end
        modifiable[new_ostruct_member(mname)] = args[0]
      elsif len == 0 && @table.key?( mid )
        @table[mid]
      else
        raise NoMethodError, "undefined method `#{mname}' for #{self}", caller(1)
      end
    end
  end

  class Base
    class << self
      def root
        rails_root = (rails? && (Rails.root || File.expand_path('../', ENV['BUNDLE_GEMFILE'])))
        ENV['AUTOCONFIG_ROOT'] || ENV['APP_ROOT'] || rails_root || Dir.pwd
      end
  
      def pattern
        ENV['AUTOCONFIG_PATTERN'] || 'config/*.yml'
      end
  
      def path
        ENV['AUTOCONFIG_PATH'] || File.expand_path(pattern, root)
      end
  
      def environment
        ENV['AUTOCONFIG_ENV'] || ENV['APP_ENV'] || (rails? && Rails.env) || 'development'
      end
  
      def rails?
        Object::const_defined? "Rails"
      end
  
      def ignored_filenames
        names = ENV['AUTOCONFIG_IGNORE'] ? "database|" + ENV['AUTOCONFIG_IGNORE'].gsub(/\s/,'|') : 'database'
        Regexp.new(names)
      end
  
      def reload
        wipe
        files = Dir.glob(path)
        begin
          old_verbose, $VERBOSE = $VERBOSE, nil
  
          files.each do |file|
            name = File.basename(file, '.yml')
            next if name.match(ignored_filenames)
  
            constant_name = "#{name}Config".gsub('-','_').camelize
            yaml_config   = YAML::load(ERB.new(IO.read(file)).result)
  
            @ordered_stanza_labels[constant_name] = []
            @ordered_stanza_labels[constant_name] << 'defaults' if yaml_config.key? 'defaults'
            @ordered_stanza_labels[constant_name] += yaml_config.keys.grep(/^defaults\[.*#{environment}/).sort_by{ |a| a.count(',') }
            @ordered_stanza_labels[constant_name] << environment if yaml_config.key? environment
  
            config = @ordered_stanza_labels[constant_name].inject({}) do |acc, label|
              deep_merge(acc,yaml_config[label])
            end
  
            ensure_requirements_met_and_ostructify!(config, constant_name )
  
            Object::const_set(constant_name.intern, OpenStruct.new(config))
          end
  
          raise @errors.to_a.join( "\n" ) unless @errors.empty?
  
        ensure
          $VERBOSE = old_verbose
        end
      end
  
      private
      # unsets created constants
      def wipe
        unless @ordered_stanza_labels.nil?
          @ordered_stanza_labels.keys.each{|const| Object::const_set(const.intern, nil) }
        end
        @ordered_stanza_labels = {}
        @errors = Set.new
      end
  
      # merges two hashes with nested hashes if present
      def deep_merge( hash1, hash2 )
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
      # Mutator method that does two things:
      # * checks if any of the keys were required and not set. Upon finding
      # it adds key to the error set
      # * recursively sets open structs for deep hashes
      def ensure_requirements_met_and_ostructify!( hash, path )
        hash.each do | key, value |
          case
          when value.respond_to?( :keys ) && value.respond_to?( :values )
            ensure_requirements_met_and_ostructify!( value, path + '.' + key )
          when value == REQUIRED
            @errors << "#{path}.#{key} is REQUIRED"
          end
          hash[key] = OpenStruct.new(value) if value.is_a?( Hash )
        end
      end
    end
  end
end

AutoConfig::Base.reload
