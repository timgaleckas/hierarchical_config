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
assert( one_config.something == 'hello' )
assert( one_config.cache_classes == false )
assert( one_config.tree1.tree3.tree4 == 'bleh' )
assert( one_config.tree1.tree2 == 'hey' )

begin
  one_config.something_that_isnt_there
  assert( false, 'unheard of values should raise NoMethodError' )
rescue NoMethodError => m
  # this is good
end

begin
  one_config.something = 'goodbye'
  assert( false, 'attempts to modify config after load should raise a TypeError' )
rescue TypeError => t
  # this is good
end

two_config = HierarchicalConfig.load_config( 'two', TEST_CONFIG_DIR, 'test' )

assert( one_config == two_config, 'configs that are split accross main and override should be the same' )

begin
  HierarchicalConfig.load_config( 'boom', TEST_CONFIG_DIR, 'development' )
  assert( false, 'error should be raised' )
rescue StandardError => e
  assert( e.to_s =~ /Error loading config from file.*boom/, 'Should receive error about BoomConfig not being able to be read')
end


