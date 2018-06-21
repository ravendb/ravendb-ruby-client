class Bar
  attr_accessor :id, :name, :foo_id, :foo_ids

  def initialize(
    id = nil,
    name = "",
    foo_id = nil,
    foo_ids = []
  )
    @id = id
    @name = name
    @foo_id = foo_id
    @foo_ids = foo_ids
  end
end
