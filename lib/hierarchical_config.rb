# typed: true

require 'yaml'
require 'erb'
require 'set'
require 'sorbet-runtime'
require 'active_support'
require 'active_support/core_ext/hash/keys'

require 'hierarchical_config/version'

module HierarchicalConfig
  REQUIRED = :REQUIRED
  YAML.add_domain_type(nil, 'REQUIRED'){REQUIRED}

  module ConfigStruct
    include Kernel

    def to_hash
      Hash[self.class.props.keys.map{|key| [key, item_to_hash(send(key))]}]
    end

    def [](key)
      send(key)
    end

    private

    def item_to_hash(item)
      case item
      when ConfigStruct
        item.to_hash
      when Array
        item.map{|i| item_to_hash(i)}
      else
        item
      end
    end
  end

  class << self
    extend T::Sig

    sig{params(value: T.untyped, path: String).returns(T::Array[String])}
    def detect_errors(value, path)
      errors = []
      case value
      when Hash
        value.each do |key, item|
          errors += detect_errors(item, "#{path}.#{key}")
        end
      when Array
        value.each_with_index do |item, index|
          errors += detect_errors(item, "#{path}[#{index}]")
        end
      when REQUIRED
        errors << "#{path} is REQUIRED"
      end
      errors
    end

    def build_types(current_item, name, parent_class)
      case current_item
      when Hash
        new_type_name = ActiveSupport::Inflector.camelize(name)

        new_type =
          if parent_class.const_defined?(new_type_name)
            parent_class.const_get(new_type_name)
          else
            parent_class.const_set(new_type_name, Class.new(T::Struct).tap{|c| c.include ConfigStruct})
          end

        current_item.each do |key, value|
          next if new_type.props.key?(key.to_sym)

          new_type.const key, build_types(value, key, new_type)
          new_type.define_method "#{key}?" do
            !!send(key) # rubocop:disable Style/DoubleNegation
          end
        end

        new_type
      when Array
        types = current_item.each_with_index.map do |item, index|
          build_types(item, name + '_' + index.to_s, parent_class)
        end
        T::Array[T.unsafe(T).any(*types)]
      else
        current_item.class
      end
    end

    def build_config(current_item, name, parent_class)
      case current_item
      when Hash
        current_type = parent_class.const_get(ActiveSupport::Inflector.camelize(name))
        current_type.new(Hash[current_item.map{|key, value| [key.to_sym, build_config(value, key, current_type)]}])
      when Array
        current_item.each_with_index.map do |item, index|
          build_config(item, name + '_' + index.to_s, parent_class)
        end.freeze
      else
        current_item.freeze
      end
    end

    def build_new_root
      @root_index ||= 0
      @root_index += 1
      const_set("ConfigRoot#{@root_index}", Class.new)
    end

    sig do
      params(
        name: String,
        dir: String,
        environment: String,
        preprocess_with: Symbol,
        root_class: T.any(Class, Module),
      ).returns(T::Struct)
    end
    def load_config(name, dir, environment, preprocess_with = :erb, root_class = build_new_root)
      primary_config_file   = "#{dir}/#{name}.yml"
      overrides_config_file = "#{dir}/#{name}-overrides.yml"

      config_hash = load_hash_for_env(primary_config_file, environment, preprocess_with)

      if File.exist?(overrides_config_file)
        overrides_config_hash = load_hash_for_env(overrides_config_file, environment, preprocess_with)
        config_hash = deep_merge(config_hash, overrides_config_hash)
      end

      errors = detect_errors(config_hash, name)
      raise errors.map{|error| error + ' for ' + environment}.inspect unless errors.empty?

      build_types(config_hash, name, root_class)

      build_config(config_hash, name, root_class)
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
  end
end
