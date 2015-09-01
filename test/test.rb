require File.expand_path('../../lib/hierarchical_config', __FILE__)
def assert( truth, message = 'is not true' )
  raise message unless truth
end

TEST_CONFIG_DIR = File.expand_path('../config', __FILE__ )

one_config = HierarchicalConfig.load_config( 'one', TEST_CONFIG_DIR, 'development' )

assert( one_config.one == 'yup' )

begin
  HierarchicalConfig.load_config( 'one', TEST_CONFIG_DIR, 'staging' )
  assert( false, 'error should be raised' )
rescue StandardError => e
  assert( e.to_s =~ /one.one is REQUIRED for staging/, 'staging should raise error stating that "one.one is REQUIRED for staging"' )
end

one_config = HierarchicalConfig.load_config( 'one', TEST_CONFIG_DIR, 'test' )
# access through methods
assert( one_config.something == 'hello' )
assert( one_config.cache_classes == false )
assert( one_config.tree1.tree3.tree4 == 'bleh' )
assert( one_config.tree1.tree2 == 'hey' )

# access through []
assert( one_config[:something] == 'hello' )
assert( one_config["cache_classes"] == false )
assert( one_config[:tree1].tree3["tree4"] == 'bleh' )
assert( one_config.tree1[:tree2] == 'hey' )

# return truthy values for ? attributes
assert( one_config.cache_classes? == false )
assert( one_config.something? == true )

begin
  one_config.something_that_isnt_there
  assert( false, 'unheard of values should raise NoMethodError' )
rescue NoMethodError => m
  # this is good
end

begin
  one_config['something_that_isnt_there']
  assert( false, 'even for hashlike access, unheard of values should raise NoMethodError' )
rescue NoMethodError => m
  # this is good
end

begin
  one_config.something = 'goodbye'
  assert( false, 'attempts to modify config after load should raise a TypeError' )
rescue TypeError, RuntimeError => t
  # this is good
end

begin
  one_config.tree1.tree2 << 'hey'
  assert( false, 'error should be raised' )
rescue StandardError => e
  assert( e.to_s =~ /can't modify frozen [sS]tring/, 'Should receive error about modifying frozen string')
end

two_config = HierarchicalConfig.load_config( 'two', TEST_CONFIG_DIR, 'test' )

assert( one_config == two_config, 'configs that are split accross main and override should be the same' )

begin
  HierarchicalConfig.load_config( 'boom', TEST_CONFIG_DIR, 'development' )
  assert( false, 'error should be raised' )
rescue StandardError => e
  assert( e.to_s =~ /Error loading config from file.*boom/, 'Should receive error about BoomConfig not being able to be read')
end

env_config = HierarchicalConfig.load_config( 'environment_variable_tests', TEST_CONFIG_DIR, 'development' )

begin
  env_config.nope
  assert( false, 'error should be raised' )
rescue StandardError => e
  assert( e.to_s =~ /undefined method `nope'/, 'Environment variables that are nil should not even make the key' )
end

ENV['HELLO']='hello'

env_config = HierarchicalConfig.load_config( 'environment_variable_tests', TEST_CONFIG_DIR, 'development' )
assert( env_config.nope == 'hello', 'environment variables should get through' )


begin
  env_config = HierarchicalConfig.load_config( 'environment_variable_tests', TEST_CONFIG_DIR, 'production' )
  assert( false, 'error should be raised' )
rescue StandardError => e
  assert( e.to_s =~ /one is REQUIRED for production/, 'the overridden name of the environment variable UNO should take precedence' )
end

ENV['UNO']='value_for_uno'
assert( HierarchicalConfig.load_config( 'environment_variable_tests', TEST_CONFIG_DIR, 'production' ).one == 'value_for_uno', 'now with it set we should see the value')

