ENV['AUTOCONFIG_ROOT'] = File.dirname(File.expand_path(__FILE__))
require File.expand_path('../../lib/autoconfig', __FILE__)
def assert( truth, message = 'is not true' )
  raise message unless truth
end
AutoConfig::Base.autoload
assert( Object.const_get('OneConfig'), 'OneConfig must exist' )
assert( OneConfig.one == 'yup' )
ENV['AUTOCONFIG_ENV']='staging'
begin
  AutoConfig::Base.load('one')
  assert( false, 'error should be raised' )
rescue StandardError => e
  assert( e.to_s =~ /one.*REQUIRED/, 'staging should raise error stating that OneConfig.one is REQUIRED' )
end
ENV['AUTOCONFIG_ENV']='test'
AutoConfig::Base.reload
assert( OneConfig.something == 'hello' )
assert( OneConfig.cache_classes == false )
assert( OneConfig.tree1.tree3.tree4 == 'bleh' )
assert( OneConfig.tree1.tree2 == 'hey' )
begin
  OneConfig.something_that_isnt_there
  assert( false, 'unheard of values should raise NoMethodError' )
rescue NoMethodError => m
  # this is good
end
begin
  ENV['BOOM']='true'
  AutoConfig::Base.reload
  assert( false, 'error should be raised' )
rescue StandardError => e
  assert( e.to_s =~ /BoomConfig/, 'Should receive error about BoomConfig not being able to be read')
  ENV['BOOM']=nil
end
AutoConfig::Base.reload
