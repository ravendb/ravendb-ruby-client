require 'ravendb'
require 'spec_helper'
require 'utilities/json'

class DocumentSerializingTest < TestBase
  def setup
    super

    @json = {
      "@metadata" => {},
      "string_prop" => "string",
      "number_prop" => 2,
      "number_float_prop" => 2.5,
      "boolean_prop" => true,
      "nil_prop" => nil,
      "hash_prop" => {
        "string_prop" => "string",
        "number_prop" => 2,
        "number_float_prop" => 2.5,
        "boolean_prop" => true,
        "nul_prop" => nil,
        "array_prop" => [1, 2, 3]
      },
      "array_prop" => [1, 2, 3],
      "deep_hash_prop" => {
        "some_prop" => "someValue",
        "some_hash" => {
          "some_prop" => "someValue"
        }
      },
      "deep_array_prop" => [
        1, 2, [3, 4]
      ],
      "deep_array_hash_prop" => [
        1, 2, {
        "some_prop" => "someValue",
        "some_array" => [3, 4]
      }, [5, 6], [7, 8, {
        "some_prop" => "someValue",
      }]],
      "date_prop" => '2017-06-04T18:39:05.1230000',
      "deep_foo_prop" => {
        "@metadata" => {},
        "id" => 'foo1',
        "name" => 'Foo #1',
        "order" => 1
      },
      "deep_array_foo_prop" => [{
         "@metadata" => {},
         "id" => 'foo2',
         "name" => 'Foo #2',
         "order" => 2
      },{
        "@metadata" => {},
         "id" => 'foo3',
         "name" => 'Foo #3',
         "order" => 3
      }]
    }

    @nested_object_types = {
      "date_prop" => "date",
      "deep_foo_prop" => Foo.name,
      "deep_array_foo_prop" => Foo.name
    }
  end

  def test_should_parse_scalars
    document = SerializingTest.new
    RavenDB::JsonSerializer::from_json(document, @json, {}, @nested_object_types)

    assert(document.string_prop.is_a?(String))
    assert_equal(document.string_prop, 'string')
    assert(document.number_prop.is_a?(Numeric))
    assert_equal(document.number_prop, 2)
    assert(document.number_float_prop.is_a?(Numeric))
    assert_equal(document.number_float_prop, 2.5)
    assert_equal(document.boolean_prop, true)
    assert(document.nil_prop.nil?)
  end
end