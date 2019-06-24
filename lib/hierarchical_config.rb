require 'ostruct'
require 'yaml'
require 'erb'
require 'set'

require "hierarchical_config/version"

module HierarchicalConfig
  REQUIRED = :REQUIRED
  #this is the incantation that works for ruby 1.8.7 (syck)
  YAML.add_builtin_type( 'REQUIRED' ){ REQUIRED }
  #and this works for 1.9.3 (Psych)
  YAML.add_domain_type( nil, 'REQUIRED' ){ REQUIRED }

  class OpenStruct < ::OpenStruct
    def method_missing( mid, *args ) # :nodoc:
      mname = mid.id2name
      len = args.length
      if mname.chomp!('=')
        if len != 1
          raise ArgumentError, "wrong number of arguments (#{len} for 1)", caller(1)
        end
        modifiable[new_ostruct_member(mname)] = args[0]
      elsif mname =~ /\?$/
        !!send(mname.gsub("?",""))
      elsif len == 0 && @table.key?( mid )
        @table[mid]
      else
        raise NoMethodError, "undefined method `#{mname}' for #{self}", caller(1)
      end
    end

    def [](attribute)
      send(attribute)
    end

    alias :each :each_pair

    def to_hash
      @table.inject({}) do |hash, key_value|
        key, value = *key_value
        hash[key] = item_to_hash(value)
        hash
      end
    end

    private

    def item_to_hash(value)
      case value
      when Array
        value.map{|item| item_to_hash(item)}
      when OpenStruct
        value.to_hash
      else
        value
      end
    end
  end

  class << self
    def load_config( name, dir, environment, preprocess_with=:erb )
      primary_config_file   = "#{dir}/#{name}.yml"
      overrides_config_file = "#{dir}/#{name}-overrides.yml"

      config_hash = load_hash_for_env( primary_config_file, environment, preprocess_with )

      if File.exists?( overrides_config_file )
        overrides_config_hash = load_hash_for_env( overrides_config_file, environment, preprocess_with )
        config_hash = deep_merge( config_hash, overrides_config_hash )
      end

      config, errors = lock_down_and_ostructify!( config_hash, name, environment )

      raise errors.inspect unless errors.empty?

      config
    end

    def load_hash_for_env( file, environment, preprocess_with )
      file_contents = IO.read(file)
      yaml_contents = case preprocess_with
                      when :erb
                        ERB.new(file_contents).result
                      when nil
                        file_contents
                      else
                        raise "Unknown preprocessor <#{preprocess_with}>"
                      end
      yaml_config   = YAML::load(yaml_contents)

      ordered_stanza_labels = []
      ordered_stanza_labels << 'defaults' if yaml_config.key? 'defaults'
      ordered_stanza_labels += yaml_config.keys.grep(/^defaults\[.*#{environment}/).sort_by{ |a| a.count(',') }
      ordered_stanza_labels << environment if yaml_config.key? environment

      config = deep_merge_hashes_in_keys(ordered_stanza_labels, yaml_config)

      env_config_labels = []
      env_config_labels << 'env_vars' if yaml_config.key? 'env_vars'
      env_config_labels += yaml_config.keys.grep(/^env_vars\[.*#{environment}/).sort_by{ |a| a.count(',') }

      env_config = deep_merge_hashes_in_keys(env_config_labels, yaml_config)
      env_config = fill_in_env_vars(env_config)

      deep_merge(config, env_config)

    rescue StandardError => e
      raise <<-ERROR
        Error loading config from file #{file}.
        #{$!.inspect}
        #{$@}
      ERROR
    end

    def from_hash_for_testing(hash, name='app', environment='test')
      config, errors = lock_down_and_ostructify!( hash, name, environment )

      raise errors.inspect unless errors.empty?

      config
    end

    private

    def deep_merge_hashes_in_keys(keys, root_hash)
      keys.inject({}) do |acc, label|
        deep_merge( acc, root_hash[label] )
      end
    end

    def fill_in_env_vars(hash)
      r = {}
      hash.each do |key,value|
        if value.is_a? Hash
          leaf_hash = fill_in_env_vars(value)
          r[key]=leaf_hash unless leaf_hash.keys.empty?
        elsif !value.nil? && ENV.key?(value)
          r[key]=ENV[value]
        end
      end
      r
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

    # Mutator method that does three things:
    # * checks if any of the keys were required and not set. Upon finding
    # it adds key to the error set
    # * recursively sets open structs for deep hashes
    # * recursively freezes config objects
    def lock_down_and_ostructify!( _hash, path, environment)
      hash = Hash[_hash.map{|k,v|[k.to_s, v]}] #stringify keys
      errors = []
      hash.each do | key, value |
        hash[key], child_errors = lock_down_and_ostructify_item!(value, path + '.' + key, environment)
        errors += child_errors
      end
      return OpenStruct.new(hash).freeze, errors
    end

    def lock_down_and_ostructify_item!(value, path, environment)
      errors = []
      return_value = case value
      when Hash
        child_hash, child_errors = lock_down_and_ostructify!( value, path, environment )
        errors += child_errors
        child_hash
      when Array
        value.each_with_index.map do |item, index|
          child_item, child_errors = lock_down_and_ostructify_item!( item, "#{path}[#{index}]", environment )
          errors += child_errors
          child_item
        end.freeze
      when REQUIRED
        errors << "#{path} is REQUIRED for #{environment}"
        nil
      else
        value.freeze
      end

      return return_value, errors
    end
  end
end
