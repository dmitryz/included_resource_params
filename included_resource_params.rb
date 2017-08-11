class Hash
  def merge_sum(other)
    merge(other) { |key,v1,v2| v1+v2 }
  end
end

class Array
  def params_multi_level
    collect { |a| [a].flatten.count > 1 ? { a[0] => [a[1..-1]].params_multi_level} : a.first }
  end

  def reduce_merge_sum_hash
    h = select { |v| v.kind_of?(Hash) }.reduce({}, :merge_sum).collect { |k,v| {k => v.reduce_merge_sum_hash} }
    s = select { |v| v.kind_of?(Symbol) }
    h + s.reject { |v| h.any? { |vv| vv.keys.first == v } }
  end
end

class IncludedResourceParams
  def initialize(include_param)
    @include_param = include_param
  end

  def has_included_resource?
    split_param.count > 0
  end

  def included_resources
    split_param
  end

  def model_includes
    raw = split_param.collect { |d| d.split('.').map(&:to_sym) }.params_multi_level
    raw.reduce_merge_sum_hash
  end

  private

  def split_param
    return [] unless @include_param
    @include_param.split(',').reject { |v| v.include?('*')}
  end
end

require 'test/unit'

class TestIncludedResourceParams < Test::Unit::TestCase
  def test_has_included_resources_is_false_when_nil
    i = IncludedResourceParams.new(nil)
    assert i.has_included_resource? == false
  end

  def test_has_included_resources_is_false_when_only_wildcards
    i = IncludedResourceParams.new('foo.**')
    assert i.has_included_resource? == false
  end

  def test_has_included_resources_is_true_with_non_wildcard_params
    i = IncludedResourceParams.new('foo')
    assert i.has_included_resource? == true
  end

  def test_has_included_resources_is_true_with_both_wildcard_and_non_params
    i = IncludedResourceParams.new('foo,bar.**')
    assert i.has_included_resource? == true
  end

  def test_included_resources_always_returns_array
    i = IncludedResourceParams.new(nil)
    assert i.included_resources == []
  end

  def test_included_resources_returns_only_non_wildcards
    i = IncludedResourceParams.new('foo,foo.bar,baz.*,bat.**')
    assert i.included_resources == ['foo', 'foo.bar']
  end

  def test_model_includes_when_params_nil
    i = IncludedResourceParams.new(nil)
    assert i.model_includes == []
  end

  def test_model_includes_one_single_level_resource
    i = IncludedResourceParams.new('foo')
    assert i.model_includes == [:foo]
  end

  def test_model_includes_multiple_single_level_resources
    i = IncludedResourceParams.new('foo,bar')
    assert i.model_includes == [:foo, :bar]
  end

  def test_model_includes_single_two_level_resource
    i = IncludedResourceParams.new('foo.bar')
    assert i.model_includes == [{:foo => [:bar]}]
  end

  def test_model_includes_multiple_two_level_resources
    i = IncludedResourceParams.new('foo.bar,foo.bat')
    assert i.model_includes == [{:foo => [:bar, :bat]}]
    i = IncludedResourceParams.new('foo.bar,baz.bat')
    assert i.model_includes == [{:foo => [:bar]}, {:baz => [:bat]}]
  end

  def test_model_includes_three_level_resources
    i = IncludedResourceParams.new('foo.bar.baz')
    assert i.model_includes == [{:foo => [{:bar => [:baz]}]}]
  end

  def test_model_includes_multiple_three_level_resources
    i = IncludedResourceParams.new('foo.bar.baz,foo,foo.bar.bat,bar')
    assert i.model_includes == [{:foo => [{:bar => [:baz, :bat]}]}, :bar]
  end
end
