require 'ravendb'
require 'spec_helper'
require 'utilities/type_utilities'

class DocumentConventionsTest < TestBase
  def setup
    super
    @json = {
      "id" => "TestConversions/1",
      "date" => '2017-10-31T19:40:00.0000000',
      "foo" => {
        "id" => "Foos/1",
        "name" => "Foo #1",
        "order" => 1
      },
      "foos" => [{
        "id" => "Foos/2",
        "name" => "Foo #2",
        "order" => 2
      },{
        "id" => "Foos/3",
        "name" => "Foo #3",
        "order" => 3
      }],
      "@metadata" => {
        "@id" => "TestConversions/1",
        "Raven-Ruby-Type" => "TestConversion",
        "@collection" => "TestConversions",
        "@nested_object_types" => {
          "date" => "date",
          "foo" => "Foo",
          "foos" => "Foo"
        }
      }
    }
  end

  def test_should_convert_to_document
    document = @_store.conventions.convert_to_document(@json)

    assert(document.is_a?(TestConversion))
    assert_equal(document.id, "TestConversions/1")
    assert(document.date.is_a?(DateTime))
    assert_equal(document.date, TypeUtilities::parse_date("2017-10-31T19:40:00.0000000"))
    assert(document.foo.is_a?(Foo))
    assert_equal(document.foo.id, "Foos/1")
    assert_equal(document.foo.name, "Foo #1")
    assert_equal(document.foo.order, 1)
    assert(document.foos.is_a?(Array))
    assert(document.foos[0].is_a?(Foo))
    assert_equal(document.foos[0].id, "Foos/2")
    assert_equal(document.foos[0].name, "Foo #2")
    assert_equal(document.foos[0].order, 2)
    assert(document.foos[1].is_a?(Foo))
    assert_equal(document.foos[1].id, "Foos/3")
    assert_equal(document.foos[1].name, "Foo #3")
    assert_equal(document.foos[1].order, 3)
  end

  def test_should_convert_back_to_raw_entity
    document = @_store.conventions.convert_to_document(@json)
    raw_entity = @_store.conventions.convert_to_raw_entity(document)

    assert_equal(raw_entity, @json)
  end

  def test_should_build_default_metadata
    document = TestConversion.new("TestConversions/1", DateTime.now, Foo.new, [Foo.new])
    @_store.conventions.set_id_on_document(document, "TestConversions/1")

    metadata = @_store.conventions.build_default_metadata(document)
    assert_equal(metadata, @json["@metadata"])
  end
end