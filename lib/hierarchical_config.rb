# typed: true

require 'ostruct'
require 'yaml'
require 'erb'
require 'set'
require 'sorbet-runtime'

require 'hierarchical_config/version'

module HierarchicalConfig
  REQUIRED = :REQUIRED
  YAML.add_domain_type(nil, 'REQUIRED'){REQUIRED}

  class OpenStruct < ::OpenStruct
    extend T::Sig

    sig{params(method_name_sym: Symbol, args: T.untyped).returns(T.untyped)}
    def method_missing(method_name_sym, *args) # rubocop:disable Style/MethodMissingSuper
      method_name = method_name_sym.id2name
      if args.length == 1 && method_name =~ /=$/
        modifiable[new_ostruct_member(method_name[0...-1])] = args.first
      elsif method_name =~ /\?$/
        !!send(T.cast(method_name[0...-1], String)) # rubocop:disable Style/DoubleNegation
      elsif args.length.zero? && @table.key?(method_name_sym)
        @table[method_name_sym]
      else
        raise NoMethodError, "undefined method `#{method_name}' for #{self}", caller(1) || []
      end
    end

    sig{params(method_name_sym: Symbol, include_private: T::Boolean).returns(T::Boolean)}
    def respond_to_missing?(method_name_sym, include_private = false)
      method_name = method_name_sym.id2name
      case method_name
      when /=$/, /\?$/
        @table.key?(method_name[0..-1]) || super
      else
        @table.key?(method_name) || super
      end
    end

    sig{params(attribute: T.any(String, Symbol)).returns(T.untyped)}
    def [](attribute)
      send(attribute)
    end

    sig{returns(T::Hash[Symbol, T.untyped])}
    def to_hash
      @table.each_with_object({}) do |key_value, hash|
        key, value = *key_value
        hash[key] = item_to_hash(value)
      end
    end

    private

    sig{params(value: BasicObject).returns(BasicObject)}
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
    extend T::Sig

    sig{params(name: String, dir: String, environment: String, preprocess_with: Symbol).returns(OpenStruct)}
    def load_config(name, dir, environment, preprocess_with = :erb)
      primary_config_file   = "#{dir}/#{name}.yml"
      overrides_config_file = "#{dir}/#{name}-overrides.yml"

      config_hash = load_hash_for_env(primary_config_file, environment, preprocess_with)

      if File.exist?(overrides_config_file)
        overrides_config_hash = load_hash_for_env(overrides_config_file, environment, preprocess_with)
        config_hash = deep_merge(config_hash, overrides_config_hash)
      end

      config, errors = lock_down_and_ostructify!(config_hash, name, environment)

      raise errors.inspect unless errors.empty?

      config
    end

    sig{params(file: String, environment: String, preprocess_with: Symbol).returns(T::Hash[String, BasicObject])}
    def load_hash_for_env(file, environment, preprocess_with)
      file_contents = IO.read(file)
      yaml_contents = case preprocess_with
                      when :erb
                        ERB.new(file_contents).result
                      when nil
                        file_contents
                      else
                        raise "Unknown preprocessor <#{preprocess_with}>"
                      end
      yaml_config   = YAML.safe_load(yaml_contents)

      ordered_stanza_labels = []
      ordered_stanza_labels << 'defaults' if yaml_config.key? 'defaults'
      ordered_stanza_labels += yaml_config.keys.grep(/^defaults\[.*#{environment}/).sort_by{|a| a.count(',')}
      ordered_stanza_labels << environment if yaml_config.key? environment

      config = deep_merge_hashes_in_keys(ordered_stanza_labels, yaml_config)

      env_config_labels = []
      env_config_labels << 'env_vars' if yaml_config.key? 'env_vars'
      env_config_labels += yaml_config.keys.grep(/^env_vars\[.*#{environment}/).sort_by{|a| a.count(',')}

      env_config = deep_merge_hashes_in_keys(env_config_labels, yaml_config)
      env_config = fill_in_env_vars(env_config)

      deep_merge(config, env_config)
    rescue StandardError => e
      raise <<-ERROR
        Error loading config from file #{file}.
        #{$ERROR_INFO.inspect}
        #{$ERROR_POSITION}
        #{e}
      ERROR
    end

    sig{params(hash: Hash, name: String, environment: String).returns(OpenStruct)}
    def from_hash_for_testing(hash, name = 'app', environment = 'test')
      config, errors = lock_down_and_ostructify!(hash, name, environment)

      raise errors.inspect unless errors.empty?

      config
    end

    private

    sig{params(keys: T::Array[String], root_hash: T::Hash[String, T::Hash[String, T.untyped]]).returns(Hash)}
    def deep_merge_hashes_in_keys(keys, root_hash)
      keys.inject({}) do |acc, label|
        deep_merge(acc, T.must(root_hash[label]))
      end
    end

    sig{params(hash: Hash).returns(T::Hash[T.untyped, T.untyped])}
    def fill_in_env_vars(hash)
      r = {}
      hash.each do |key, value|
        if value.is_a? Hash
          leaf_hash = fill_in_env_vars(value)
          r[key] = leaf_hash unless leaf_hash.keys.empty?
        elsif !value.nil? && ENV.key?(value)
          r[key] = ENV[value]
        end
      end
      r
    end

    # merges two hashes with nested hashes if present
    sig{params(hash1: Hash, hash2: Hash).returns(Hash)}
    def deep_merge(hash1, hash2)
      hash1 = hash1.dup
      (hash1.keys + hash2.keys).each do |key|
        if hash1.key?(key) && hash2.key?(key) &&
           hash1[key].is_a?(Hash) && hash2[key].is_a?(Hash)
          hash1[key] = deep_merge(hash1[key], hash2[key])
        elsif hash2.key?(key)
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
    sig do
      params(
        original_hash: T.untyped,
        path: T.untyped,
        environment: T.untyped,
      ).returns([T.untyped, T::Array[String]])
    end
    def lock_down_and_ostructify!(original_hash, path, environment)
      hash = Hash[original_hash.map{|k, v| [k.to_s, v]}] # stringify keys
      errors = []
      hash.each do |key, value|
        hash[key], child_errors = lock_down_and_ostructify_item!(value, path + '.' + key, environment)
        errors += child_errors
      end
      [OpenStruct.new(hash).freeze, errors]
    end

    sig{params(value: T.untyped, path: T.untyped, environment: T.untyped).returns([T.untyped, T::Array[String]])}
    def lock_down_and_ostructify_item!(value, path, environment)
      errors = []
      return_value =
        case value
        when Hash
          child_hash, child_hash_errors = lock_down_and_ostructify!(value, path, environment)
          errors += child_hash_errors
          child_hash
        when Array
          value.each_with_index.map do |item, index|
            child_item, child_item_errors = lock_down_and_ostructify_item!(item, "#{path}[#{index}]", environment)
            errors += child_item_errors
            child_item
          end.freeze
        when REQUIRED
          errors << "#{path} is REQUIRED for #{environment}"
          nil
        else
          value.freeze
        end

      [return_value, errors]
    end
  end
end
