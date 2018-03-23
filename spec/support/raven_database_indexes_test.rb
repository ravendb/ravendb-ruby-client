module RavenDatabaseIndexesTest
  def self.setup(context)
    context.instance_eval do
      @_index = RavenDB::IndexDefinition.new(name: "Testing", index_map: index_map)
      store.operations.send(RavenDB::PutIndexesOperation.new(@_index))
    end
  end

  def self.teardown(context)
    context.instance_eval do
      @_index = nil
    end
  end
end
