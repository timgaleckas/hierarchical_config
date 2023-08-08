# typed: false

RSpec.describe HierarchicalConfig do
  let(:test_config_dir){File.expand_path('config', __dir__)}

  let(:config){described_class.load_config(file, test_config_dir, environment)}

  let(:environment){'development'}

  it 'has a version number' do
    expect(described_class::VERSION).not_to be_nil
  end

  context 'with one.yml' do
    let(:file){'one'}

    context 'when in development environment' do
      it 'parses and returns a simple value' do
        expect(config.one).to eq('yup')
      end
    end

    context 'when in staging environment' do
      let(:environment){'staging'}

      it 'raises an error since one.one is unset for staging' do
        expect{config}.to raise_error(/one.one is REQUIRED for staging.*one.array\[0\].key1 is REQUIRED for staging/)
      end
    end

    context 'when in test environment' do
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

      it 'supports deeply chained access' do # rubocop:disable RSpec/MultipleExpectations
        expect(config.tree1.tree3.tree4).to eq('bleh')
        expect(config[:tree1].tree3['tree4']).to eq('bleh')
        expect(config.array_of_hashes.first.key1).to eq('value1a')
      end

      it 'suports interrogative methods for truthiness' do # rubocop:disable RSpec/MultipleExpectations
        expect(config.cache_classes?).to be false
        expect(config.something?).to be true
      end

      it 'raises NoMethodError for unconfigured values' do # rubocop:disable RSpec/MultipleExpectations
        expect{config.something_that_isnt_there}.to raise_error(NoMethodError)
        expect{config['something_that_isnt_there']}.to raise_error(NoMethodError)
        expect{config[:something_that_isnt_there]}.to raise_error(NoMethodError)
      end

      it 'raises Error when trying to modify config' do # rubocop:disable RSpec/MultipleExpectations
        expect{config.something = 'goodbye'}.to raise_error(/undefined method `something=/)
        expect{config.tree1.tree2 << 'goodbye'}.to raise_error(/can't modify/)
      end

      context 'with to_hash' do # rubocop:disable RSpec/NestedGroups
        it 'supports to_hash' do # rubocop:disable RSpec/ExampleLength
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
            strangekey_hash_of_arrays: {
              ALLCAPSZERO: [
                {arr0: true, arr1: 'one'},
              ],
              ALLCAPSONE: [
                {arr0: false, arr2: 'two'},
              ],
              ALL_CAPS_TWO: [
                {arr0: true, arr3: 'three'},
              ],
              CamelCase: [
                {arr0: false, arr4: 'four'},
              ],
              dromedaryCase: [
                {arr0: true, arr5: 'five'},
              ],
              snake_case: [
                {arr0: false, arr6: 'six'},
              ],
              Camel_Snake: [
                {arr0: true, arr7: 'seven'},
              ],
              dromedary_Snake: [
                {arr0: false, arr8: 'eight'},
              ],
            },
          )
        end
      end

      context 'with to_h' do # rubocop:disable RSpec/NestedGroups
        it 'supports to_h without block' do # rubocop:disable RSpec/ExampleLength, RSpec/MultipleExpectations
          expect(config.to_h[:one]).to eq('one')
          expect(config.to_h[:two]).to eq('two')
          expect(config.to_h[:three]).to eq('three')
          expect(config.to_h[:cache_classes]).to be(false)
          expect(config.to_h[:something]).to eq('hello')
          expect(config.to_h[:tree1][:tree2]).to eq('hey')
          expect(config.to_h[:tree1][:tree3][:tree4]).to eq('bleh')
          expect(config.to_h[:array_of_hashes][0][:key1]).to eq('value1a')
          expect(config.to_h[:array_of_hashes][0][:key2]).to eq('value2a')
          expect(config.to_h[:array_of_hashes][1][:key1]).to eq('value1b')
          expect(config.to_h[:array_of_hashes][1][:key2]).to eq('value2b')
          expect(config.to_h[:array_of_strings]).to eq(%w[one two three])
          expect(config.to_h[:strangekey_hash_of_arrays][:ALLCAPSZERO][0][:arr0]).to be(true)
          expect(config.to_h[:strangekey_hash_of_arrays][:ALLCAPSZERO][0][:arr1]).to eq('one')
          expect(config.to_h[:strangekey_hash_of_arrays][:ALLCAPSONE][0][:arr0]).to be(false)
          expect(config.to_h[:strangekey_hash_of_arrays][:ALLCAPSONE][0][:arr2]).to eq('two')
          expect(config.to_h[:strangekey_hash_of_arrays][:ALL_CAPS_TWO][0][:arr0]).to be(true)
          expect(config.to_h[:strangekey_hash_of_arrays][:ALL_CAPS_TWO][0][:arr3]).to eq('three')
          expect(config.to_h[:strangekey_hash_of_arrays][:CamelCase][0][:arr0]).to be(false)
          expect(config.to_h[:strangekey_hash_of_arrays][:CamelCase][0][:arr4]).to eq('four')
          expect(config.to_h[:strangekey_hash_of_arrays][:dromedaryCase][0][:arr0]).to be(true)
          expect(config.to_h[:strangekey_hash_of_arrays][:dromedaryCase][0][:arr5]).to eq('five')
          expect(config.to_h[:strangekey_hash_of_arrays][:snake_case][0][:arr0]).to be(false)
          expect(config.to_h[:strangekey_hash_of_arrays][:snake_case][0][:arr6]).to eq('six')
          expect(config.to_h[:strangekey_hash_of_arrays][:Camel_Snake][0][:arr0]).to be(true)
          expect(config.to_h[:strangekey_hash_of_arrays][:Camel_Snake][0][:arr7]).to eq('seven')
          expect(config.to_h[:strangekey_hash_of_arrays][:dromedary_Snake][0][:arr0]).to be(false)
          expect(config.to_h[:strangekey_hash_of_arrays][:dromedary_Snake][0][:arr8]).to eq('eight')
        end

        it 'supports to_h with block' do # rubocop:disable RSpec/MultipleExpectations
          result = config.to_h{|n, v| [n.to_s, v]}
          expect(result['one']).to eq('one')
          expect(result['strangekey_hash_of_arrays'][:ALLCAPSZERO][0][:arr0]).to be(true)
        end

        it 'converts values to ConfigStruct supporting both hash/key and method access' do # rubocop:disable RSpec/MultipleExpectations
          expect(config.to_h[:tree1][:tree2]).to eq('hey')
          expect(config.to_h[:tree1].tree2).to eq('hey')
        end
      end
    end

    context 'when in production environment' do
      let(:environment){'production'}

      it 'raises an exception for required values that are unset' do
        expect{config}.to raise_error(/one is REQUIRED for production/)
      end
    end
  end

  context 'with two.yml and two-overrides.yml' do
    let(:file){'two'}

    it 'deep merges overrides on top of file and looks the same' do
      expect(config.to_hash).to eq(described_class.load_config('one', test_config_dir, environment).to_hash)
    end
  end

  context 'with boom.yml' do
    let(:file){'boom'}

    it 'supports ERB and exposes an error' do
      expect{config}.to raise_error(/Error loading config from file.*boom/)
    end
  end

  context 'with prop_ending_with_question_mark.yml' do
    let(:file){'prop_ending_with_question_mark'}

    it 'raises the invalid property error from sorbet' do
      expect{config}.to raise_error(ArgumentError, /Invalid prop name in HierarchicalConfig/)
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
