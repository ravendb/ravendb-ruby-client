module RavenDatabaseIndexesTest
  def self.setup(context)
    context.instance_eval do
      @_index = RavenDB::IndexDefinition.new("Testing", index_map)
      store.operations.send(RavenDB::PutIndexesOperation.new(@_index))
    end
  end

  def self.teardown(context)
    context.instance_eval do
      @_index = nil
    end
  end
end
