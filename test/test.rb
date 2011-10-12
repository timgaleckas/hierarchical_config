ENV['AUTOCONFIG_ROOT'] = '.'
require '../lib/autoconfig'
def assert( truth, message = 'is not true' )
  raise message unless truth
end
assert( Object.const_get('OneConfig'), 'OneConfig must exist' )
assert( OneConfig.one == 'yup' )
ENV['AUTOCONFIG_ENV']='staging'
begin
  AutoConfig.reload
rescue StandardError => e
  assert( e.to_s =~ /OneConfig.one/, 'staging should raise error stating that OneConfig.one is REQUIRED' )
end
ENV['AUTOCONFIG_ENV']='test'
AutoConfig.reload
assert( OneConfig.something == 'hello' )
assert( OneConfig.cache_classes == false )
assert( OneConfig.tree1.tree3.tree4 == 'bleh' )
assert( OneConfig.tree1.tree2 == 'hey' )
