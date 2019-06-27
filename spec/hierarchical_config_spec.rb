# typed: false
RSpec.describe HierarchicalConfig do
  it 'has a version number' do
    expect(HierarchicalConfig::VERSION).not_to be nil
  end

  let(:test_config_dir){File.expand_path('config', __dir__)}

  let(:config){HierarchicalConfig.load_config(file, test_config_dir, environment)}

  let(:environment){'development'}

  context 'with one.yml' do
    let(:file){'one'}

    context 'in development environment' do
      it 'parses and returns a simple value' do
        expect(config.one).to eq('yup')
      end
    end

    context 'in staging environment' do
      let(:environment){'staging'}

      it 'raises an error since one.one is unset for staging' do
        expect{config}.to raise_error(/one.one is REQUIRED for staging.*one.array\[0\].key1 is REQUIRED for staging/)
      end
    end

    context 'in test environment' do
      let(:environment){'test'}

      it 'supports method access' do
        expect(config.something).to eq('hello')
      end

      it 'supports hash access with strings' do
        expect(config['something']).to eq('hello')
      end

      it 'supports hash access with symbols' do
        expect(config[:something]).to eq('hello')
      end

      it 'supports deeply chained access' do
        expect(config.tree1.tree3.tree4).to eq('bleh')
        expect(config[:tree1].tree3['tree4']).to eq('bleh')
        expect(config.array_of_hashes.first.key1).to eq('value1a')
      end

      it 'suports interrogative methods for truthiness' do
        expect(config.cache_classes?).to be false
        expect(config.something?).to be true
      end

      it 'raises NoMethodError for unconfigured values' do
        expect{config.something_that_isnt_there}.to raise_error(NoMethodError)
        expect{config['something_that_isnt_there']}.to raise_error(NoMethodError)
        expect{config[:something_that_isnt_there]}.to raise_error(NoMethodError)
      end

      it 'raises Error when trying to modify config' do
        expect{config.something = 'goodbye'}.to raise_error(/cannot be modified/)
        expect{config.tree1.tree2 << 'goodbye'}.to raise_error(/can't modify/)
      end

      context 'to_hash' do
        it 'supports to_hash' do
          expect(config.to_hash).to eq(
            one: 'one',
            two: 'two',
            three: 'three',
            cache_classes: false,
            something: 'hello',
            tree1: {
              tree2: 'hey',
              tree3: {tree4: 'bleh'},
            },
            array_of_hashes: [
              {key1: 'value1a', key2: 'value2a'},
              {key1: 'value1b', key2: 'value2b'},
            ],
            array_of_strings: %w[one two three],
          )
        end
      end
    end

    context 'in production environment' do
      let(:environment){'production'}

      it 'raises an exception for required values that are unset' do
        expect{config}.to raise_error(/one is REQUIRED for production/)
      end
    end
  end

  context 'with two.yml and two-overrides.yml' do
    let(:file){'two'}

    it 'deep merges overrides on top of file and looks the same' do
      expect(config.to_hash).to eq(HierarchicalConfig.load_config('one', test_config_dir, environment).to_hash)
    end
  end

  context 'with boom.yml' do
    let(:file){'boom'}

    it 'supports ERB and exposes an error' do
      expect{config}.to raise_error(/Error loading config from file.*boom/)
    end
  end

  context 'with environment_variable_tests.yml' do
    let(:file){'environment_variable_tests'}

    context 'with HELLO set' do
      it 'supports reading values from environemnt varialbles and inserting them into the config' do
        stub_const('ENV', 'HELLO' => "I'm here")
        expect(config.nope).to eq("I'm here")
      end
    end

    context 'with HELLO unset' do
      it "doesn't set values that are unset in the ENV" do
        stub_const('ENV', {})
        expect{config.nope}.to raise_error(NoMethodError)
      end
    end
  end
end
