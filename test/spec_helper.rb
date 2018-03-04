require "ravendb"
require "date"
require "securerandom"
require "minitest/autorun"
require "active_support/inflector"

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

class RavenTest < Minitest::Test
  DEFAULT_URL = ENV["URL"] || "http://localhost:8080"
  DEFAULT_DATABASE = ENV["DATABASE"] || "NorthWindTest"
  CERT_FILE = ENV["CERTIFICATE"] || nil
  CERT_PASSPHRASE = ENV["PASSPHRASE"] || nil

  def setup
    @_current_database = "#{DEFAULT_DATABASE}__#{SecureRandom.uuid}"
    @_store = RavenDB::DocumentStore.new([DEFAULT_URL], @_current_database)
    @_store.configure do |config|
      unless CERT_FILE.nil?
        config.auth_options = RavenDB::StoreAuthOptions.new(File.read(CERT_FILE), CERT_PASSPHRASE)
      end
    end

    @_store.conventions.disable_topology_updates = true
  end

  def teardown
    @_store.dispose
    @_store = nil
    @_current_database = nil
  end
end

class RavenDatabaseTest < RavenTest
  def setup
    super
    @_store.conventions.disable_topology_updates = false
    @_index_map =
      "from doc in docs "\
      "select new{"\
      "Tag = doc[\"@metadata\"][\"@collection\"],"\
      "LastModified = (DateTime)doc[\"@metadata\"][\"Last-Modified\"],"\
      "LastModifiedTicks = ((DateTime)doc[\"@metadata\"][\"Last-Modified\"]).Ticks}"

    db_doc = RavenDB::DatabaseDocument.new(@_current_database, {:'Raven/DataDir' => "test"})
    @_store.maintenance.server.send(RavenDB::CreateDatabaseOperation.new(db_doc))
    @_request_executor = @_store.get_request_executor
  end

  def teardown
    @_store.maintenance.server.send(RavenDB::DeleteDatabaseOperation.new(@_current_database, true))
    @_request_executor = nil
    @_index_map = nil
    super
  end
end

class RavenDatabaseIndexesTest < RavenDatabaseTest
  def setup
    super

    @_index = RavenDB::IndexDefinition.new("Testing", @_index_map)
    @_store.operations.send(RavenDB::PutIndexesOperation.new(@_index))
  end

  def teardown
    super
    @_index = nil
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

    unless uid.nil?
      @uid = uid
    end

    unless ordering.nil?
      @ordering = ordering
    end
  end
end

class Company
  attr_accessor :id, :name, :product, :uid

  def initialize(
    id = nil,
    name = "",
    product = nil,
    uid = nil
  )
    @id = id
    @name = name
    @product = product
    @uid = uid
  end
end

class Order
  attr_accessor :id, :name, :uid, :product_id

  def initialize(
    id = nil,
    name = "",
    uid = nil,
    product_id = nil
  )
    @id = id
    @name = name
    @uid = uid
    @product_id = product_id
  end
end

class LastFm
  attr_accessor :id, :artist, :track_id,
                :title, :datetime_time, :tags

  def initialize(
    id = nil,
    artist = "",
    track_id = "",
    title = "",
    datetime_time = DateTime.now,
    tags = []
  )
    @id = id
    @artist = artist
    @track_id = track_id
    @title = title
    @datetime_time = datetime_time
    @tags = tags
  end
end

class TestCustomDocumentId
  attr_accessor :item_id, :item_title

  def initialize(
    item_id = nil,
    item_title = nil
  )
    @item_id = item_id
    @item_title = item_title
  end
end

class TestCustomSerializer < TestCustomDocumentId
  attr_accessor :item_options

  def initialize(
    item_id = nil,
    item_title = nil,
    item_options = []
  )
    super(item_id, item_title)
    @item_options = item_options
  end
end

class LastFmAnalyzed
  def initialize(store, test)
    index_map =  "from song in docs.LastFms "\
      "select new {"\
      "query = new object[] {"\
      "song.artist,"\
      "((object)song.datetime_time),"\
      "song.tags,"\
      "song.title,"\
      "song.track_id}}"

    @test = test
    @store = store
    @index_definition = RavenDB::IndexDefinition.new(
      self.class.name, index_map, nil, {
      :fields => {
        "query" => RavenDB::IndexFieldOptions.new(RavenDB::FieldIndexingOption::Search)
      }
    })
  end

  def execute
    @store.operations.send(RavenDB::PutIndexesOperation.new(@index_definition))

    self
  end

  def check_fulltext_search_result(last_fm, query)
    search_in = []
    fields = ["artist", "title"]

    fields.each {|field| query.each {|keyword|
      search_in.push({
        :keyword => keyword,
        :sample => last_fm.instance_variable_get("@#{field}")
      })
    }}

    @test.assert(search_in.any? {|comparsion|
      comparsion[:sample].include?(comparsion[:keyword])
    })
  end
end

class ProductsTestingSort
  def initialize(store)
    index_map =  "from doc in docs "\
      "select new {"\
      "name = doc.name,"\
      "uid = doc.uid,"\
      'doc_id = doc.uid+"_"+doc.name}'

    @store = store
    @index_definition = RavenDB::IndexDefinition.new(
      "Testing_Sort", index_map, nil, {
      :fields => {
        "doc_id" => RavenDB::IndexFieldOptions.new(nil, true)
      }
    })
  end

  def execute
    @store.operations.send(RavenDB::PutIndexesOperation.new(@index_definition))
  end
end

class CustomAttributeSerializer < RavenDB::AttributeSerializer
  def on_serialized(serialized)
    metadata = serialized[:metadata]

    if metadata["Raven-Ruby-Type"] == TestCustomSerializer.name
      serialized[:serialized_attribute] = serialized[:original_attribute].camelize(:lower)

      if serialized[:original_attribute] == "item_options"
        serialized[:serialized_value] = serialized[:original_value].join(",")
      end
    end
  end

  def on_unserialized(serialized)
    metadata = serialized[:metadata]

    if metadata["Raven-Ruby-Type"] == TestCustomSerializer.name
      serialized[:serialized_attribute] = serialized[:original_attribute].underscore

      if serialized[:original_attribute] == "itemOptions"
        serialized[:serialized_value] = serialized[:original_value].split(",").map { |option| option.to_i }
      end
    end
  end
end