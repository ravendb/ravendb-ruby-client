require 'ravendb'
require 'date'
require 'securerandom'
require 'minitest/autorun'
require 'requests/request_executor'
require 'requests/request_helpers'
require 'documents/document_query'
require "documents/indexes"
require 'database/operations'
require 'database/commands'
require 'documents/conventions'

module MiniTest
  module Assertions
    def refute_raises *exp
      msg = exp.last.is_a?(String) ? exp.pop : "unexpected exception raised"

      begin
        yield
      rescue MiniTest::Skip => e
        return e if exp.include? MiniTest::Skip
        raise e
      rescue Exception => e
        exp = exp.first if exp.size == 1
        flunk "#{msg}: #{e}"
      end

    end
  end
  module Expectations
    infect_an_assertion :refute_raises, :wont_raise
  end
end

class TestBase < Minitest::Test  
  DEFAULT_URL = ENV["URL"] || "http://localhost:8080"
  DEFAULT_DATABASE = ENV["DATABASE"] || "NorthWindTest"

  def setup
    @_current_database = "#{DEFAULT_DATABASE}__#{SecureRandom.uuid}"
    @_store = RavenDB::DocumentStore.new([DEFAULT_URL], @_current_database)
    @_store.configure

    db_doc = RavenDB::DatabaseDocument.new(@_current_database, {:'Raven/DataDir' => "test"})
    @_store.admin.server.send(RavenDB::CreateDatabaseOperation.new(db_doc))
  
    @_index_map = 
      "from doc in docs "\
      "select new{"\
      "Tag = doc[\"@metadata\"][\"@collection\"],"\
      "LastModified = (DateTime)doc[\"@metadata\"][\"Last-Modified\"],"\
      "LastModifiedTicks = ((DateTime)doc[\"@metadata\"][\"Last-Modified\"]).Ticks}"    
  
    @_index = RavenDB::IndexDefinition.new("Testing", @_index_map)
    @_store.operations.send(RavenDB::PutIndexesOperation.new(@_index))
    @_request_executor = @_store.get_request_executor    
  end  

  def teardown
    @_store.admin.server.send(RavenDB::DeleteDatabaseOperation.new(@_current_database, true))
    @_store.dispose
    
    @_index_map = nil
    @_index = nil
    @_request_executor = nil
    @_store = nil
    @_current_database = nil    
  end  
end

class SerializingTest
  attr_accessor :string_prop, :number_prop, :number_float_prop,
                :boolean_prop, :nil_prop, :hash_prop, :array_prop,
                :deep_hash_prop, :deep_array_prop, :deep_array_hash_prop,
                :date_prop, :deep_foo_prop, :deep_array_foo_prop

end

class Foo
  attr_accessor :id, :name, :order

  def initialize(
    id = nil,
    name = "",
    order = 0
  )
    @id = id
    @name = name
    @order = order
  end
end

class TestConversion
  attr_accessor :id, :date, :foo, :foos

  def initialize(
    id = nil,
    date = DateTime.now,
    foo = nil,
    foos = []
  )
    @id = id
    @date = date
    @foo = foo
    @foos = foos
  end
end

class Product
  attr_accessor :id, :name, :uid, :ordering

  def initialize(
    id = nil,
    name = "",
    uid = nil,
    ordering = nil
  )
    @id = id
    @name = name
    @uid = uid
    @ordering = ordering
  end
end