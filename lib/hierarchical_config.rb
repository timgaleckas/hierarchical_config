require 'ostruct'
require 'yaml'
require 'erb'
require 'set'

module HierarchicalConfig
  REQUIRED = :REQUIRED
  YAML.add_builtin_type( 'REQUIRED' ){ REQUIRED }

  class OpenStruct < ::OpenStruct
    def method_missing( mid, *args ) # :nodoc:
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

    def [](attribute)
      send(attribute)
    end

    def to_hash
      @table.inject({}) do |hash, key_value|
        key, value = *key_value
        hash[key] = value.respond_to?( :to_hash ) ? value.to_hash : value
        hash
      end
    end
  end

  class << self
    def load_config( name, dir, environment )
      primary_config_file   = "#{dir}/#{name}.yml"
      overrides_config_file = "#{dir}/#{name}-overrides.yml"

      config_hash = load_hash_for_env( primary_config_file, environment )

      if File.exists?( overrides_config_file )
        overrides_config_hash = load_hash_for_env( overrides_config_file, environment )
        config_hash = deep_merge( config_hash, overrides_config_hash )
      end

      config_hash, errors = lock_down_and_ostructify!( config_hash, name, environment )

      raise errors.inspect unless errors.empty?

      OpenStruct.new(config_hash).freeze
    end

    def load_hash_for_env( file, environment )
      yaml_config   = YAML::load(ERB.new(IO.read(file)).result)

      ordered_stanza_labels = []
      ordered_stanza_labels << 'defaults' if yaml_config.key? 'defaults'
      ordered_stanza_labels += yaml_config.keys.grep(/^defaults\[.*#{environment}/).sort_by{ |a| a.count(',') }
      ordered_stanza_labels << environment if yaml_config.key? environment

      config = ordered_stanza_labels.inject({}) do |acc, label|
        deep_merge( acc, yaml_config[label] )
      end

    rescue StandardError => e
      raise <<-ERROR
        Error loading config from file #{file}.
        #{$!.inspect}
        #{$@}
      ERROR
    end

    private

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

    # Mutator method that does three things:
    # * checks if any of the keys were required and not set. Upon finding
    # it adds key to the error set
    # * recursively sets open structs for deep hashes
    # * recursively freezes config objects
    def lock_down_and_ostructify!( hash, path, environment)
      errors = []
      hash.each do | key, value |
        case
        when value.respond_to?( :keys ) && value.respond_to?( :values )
          child_hash, child_errors = lock_down_and_ostructify!( value, path + '.' + key, environment )
          errors += child_errors
          hash[key] = OpenStruct.new(child_hash).freeze
        when value == REQUIRED
          errors << "#{path}.#{key} is REQUIRED for #{environment}"
        end
      end
      return hash, errors
    end
  end
end
