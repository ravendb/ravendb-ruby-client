require 'ravendb'
require 'spec_helper'
require 'utilities/json'
require 'utilities/type_utilities'

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
        "nil_prop" => nil,
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

    @document = SerializingTest.new
    RavenDB::JsonSerializer::from_json(@document, @json, {}, @nested_object_types)
  end

  def test_should_parse_scalars
    assert(@document.string_prop.is_a?(String))
    assert_equal(@document.string_prop, 'string')
    assert(@document.number_prop.is_a?(Numeric))
    assert_equal(@document.number_prop, 2)
    assert(@document.number_float_prop.is_a?(Numeric))
    assert_equal(@document.number_float_prop, 2.5)
    assert(!!@document.boolean_prop == @document.boolean_prop)
    assert_equal(@document.boolean_prop, true)
    assert(@document.nil_prop.nil?)
  end

  def test_should_parse_arrays
    assert(@document.array_prop.is_a?(Array))
    assert_equal(@document.array_prop.size, 3)
    assert_equal(@document.array_prop, [1, 2, 3])
  end

  def test_should_parse_deep_arrays
    deep = @document.deep_array_prop[2]

    assert(@document.deep_array_prop.is_a?(Array))
    assert_equal(@document.deep_array_prop.size, 3)
    assert_equal(@document.deep_array_prop, [1, 2, [3, 4]])

    assert(deep.is_a?(Array))
    assert_equal(deep.size, 2)
    assert_equal(deep, [3, 4])
  end

  def test_should_parse_hashes
    assert(@document.hash_prop.is_a?(Hash))
    assert(@document.hash_prop.key?("string_prop"))
    assert(@document.hash_prop.key?("number_prop"))
    assert(@document.hash_prop.key?("number_float_prop"))
    assert(@document.hash_prop.key?("boolean_prop"))
    assert(@document.hash_prop.key?("nil_prop"))
    assert(@document.hash_prop.key?("array_prop"))

    assert(@document.hash_prop["string_prop"].is_a?(String))
    assert_equal(@document.hash_prop["string_prop"], 'string')
    assert(@document.hash_prop["number_prop"].is_a?(Numeric))
    assert_equal(@document.hash_prop["number_prop"], 2)
    assert(@document.hash_prop["number_float_prop"].is_a?(Numeric))
    assert_equal(@document.hash_prop["number_float_prop"], 2.5)
    assert(!!@document.hash_prop["boolean_prop"] == @document.hash_prop["boolean_prop"])
    assert_equal(@document.hash_prop["boolean_prop"], true)
    assert(@document.hash_prop["nil_prop"].nil?)

    assert(@document.hash_prop["array_prop"].is_a?(Array))
    assert_equal(@document.hash_prop["array_prop"].size, 3)
    assert_equal(@document.hash_prop["array_prop"], [1, 2, 3])
  end

  def test_should_parse_deep_hashes
    deep = @document.deep_hash_prop["some_hash"]

    assert(@document.deep_hash_prop.is_a?(Hash))
    assert(@document.deep_hash_prop.key?('some_prop'))
    assert_equal(@document.deep_hash_prop['some_prop'], 'someValue')

    assert(deep.is_a?(Hash))
    assert(deep.key?('some_prop'))
    assert(deep['some_prop'], 'someValue')
  end

  def test_should_parse_mixed_deep_arrays_hashes
    deep_hash = @document.deep_array_hash_prop[2]
    deep_array_in_hash = deep_hash["some_array"]
    deep_array = @document.deep_array_hash_prop[4]
    deep_hash_in_array = deep_array[2]

    assert(deep_hash.is_a?(Hash))
    assert(deep_hash.key?('some_prop'))
    assert_equal(deep_hash['some_prop'], 'someValue')

    assert(deep_array_in_hash.is_a?(Array))
    assert_equal(deep_array_in_hash.size, 2)
    assert_equal(deep_array_in_hash, [3, 4])

    assert(deep_array.is_a?(Array))
    assert_equal(deep_array.size, 3)
    assert_equal(deep_array[0], 7)
    assert_equal(deep_array[1], 8)

    assert(deep_hash_in_array.is_a?(Hash))
    assert(deep_hash_in_array.key?('some_prop'))
    assert_equal(deep_hash_in_array['some_prop'], 'someValue')
  end

  def test_should_parse_dates
    assert(@document.date_prop.is_a?(DateTime))
    assert(RavenDB::TypeUtilities::stringify_date(@document.date_prop), @json['date_prop'])
  end

  def test_should_parse_deep_objects_and_arrays_according_to_specified_nested_objects_types
    assert(@document.deep_array_foo_prop.is_a?(Array))

    target = [@document.deep_foo_prop].concat(@document.deep_array_foo_prop)
    source = [@json["deep_foo_prop"]].concat(@json["deep_array_foo_prop"])

    target.each_index do |index|
      item = target[index]
      source_item = source[index]

      assert(item.is_a?(Foo))
      assert_equal(item.id, source_item["id"])
      assert_equal(item.name, source_item["name"])
      assert_equal(item.order, source_item["order"])
    end
  end

  def test_should_serialize_back_to_source_json
    serialized = RavenDB::JsonSerializer::to_json(@document)

    assert_equal(serialized, @json)
  end
end