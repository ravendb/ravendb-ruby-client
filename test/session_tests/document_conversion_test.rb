require 'date'
require 'ravendb'
require 'spec_helper'

class DocumentConversionTest < TestBase
  NOW = DateTime.now

  def setup
    super
    @_store.open_session do |session|
      session.store(make_document('TestConversions/1'))
      session.store(make_document('TestConversions/2', NOW.next_day))
      session.save_changes
    end
  end

  def test_should_convert_on_load
    id = 'TestConversions/1'

    @_store.open_session do |session|
      doc = session.load(id)
      check_doc(id, doc)
    end
  end

  def test_should_convert_on_store_then_reload
    id = 'TestConversions/1'

    @_store.open_session do |session|
      session.store(make_document(id))
      session.save_changes
    end

    @_store.open_session do |session|
      doc = session.load(id)
      check_doc(id, doc)
    end
  end

  protected
  def make_document(id = nil, date = NOW)
    TestConversion.new(
        id, date, Foo.new('Foos/1', 'Foo #1', 1), [
        Foo.new('Foos/2', 'Foo #2', 2),
        Foo.new('Foos/3', 'Foo #3', 3)
    ])
  end

  def check_foo(foo, id_of_foo = 1)
    assert(foo.is_a?(Foo))
    assert_equal(foo.id, "Foos/#{id_of_foo}")
    assert_equal(foo.name, "Foo ##{id_of_foo}")
    assert_equal(foo.order, id_of_foo)
  end

  def check_doc(id, doc)
    assert(doc.is_a?(TestConversion))
    assert_equal(doc.id, id)
    assert(doc.date.is_a?(DateTime))
    assert(doc.foos.is_a?(Array))

    check_foo(doc.foo)
    doc.foos.each_index{|index| check_foo(doc.foos[index], index + 2)}
  end
end