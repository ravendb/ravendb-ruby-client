module RavenDB
  class MultiLoaderWithInclude
    def initialize(session)
      @session = session
      @includes = []
    end

    def include(path)
      @includes << path
      self
    end

    def load(klass, ids)
      @session.load_internal(klass: klass, ids: ids, includes: @includes)
    end
  end
end
