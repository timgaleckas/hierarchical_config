require 'hierarchical_config'

module AutoConfig
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

  class Base
    class << self
      def root
        rails_root = (rails? && (Rails.root || File.expand_path('../', ENV['BUNDLE_GEMFILE'])))
        ENV['AUTOCONFIG_ROOT'] || ENV['APP_ROOT'] || rails_root || Dir.pwd
      end

      def pattern
        ENV['AUTOCONFIG_PATTERN'] || '*.yml'
      end

      def path
        ENV['AUTOCONFIG_PATH'] || File.expand_path('config',root)
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

      def load(name)
        HierarchicalConfig.load_config( name, path, environment )
      end


      def autoload
        wipe
        files = Dir.glob(File.join(path,pattern))
        begin
          old_verbose, $VERBOSE = $VERBOSE, nil

          files.each do |file|
            name = File.basename(file, pattern.gsub('*',''))
            next if name.match(ignored_filenames) || name.match(/-overrides/)

            constant_name = "#{name}Config".gsub('-','_').camelize.intern
            begin
              Object::const_set(constant_name, load(name))
              @autoset_constants ||= Set.new
              @autoset_constants << constant_name
            rescue StandardError => e
              @errors << <<-ERROR
                Error reading file #{file} into #{constant_name}.
                #{$!.inspect}
                #{$@}
                You can skip it by adding it to AUTOCONFIG_IGNORE.
              ERROR
            end
          end

          raise @errors.to_a.join( "\n" ) unless @errors.empty?

        ensure
          $VERBOSE = old_verbose
        end
      end

      alias :reload :autoload

      private

      # unsets created constants
      def wipe
        unless @autoset_constants.nil?
          @autoset_constants.each{|const| Object::const_set(const, nil) }
        end
        @errors = Set.new
      end

    end
  end
end
