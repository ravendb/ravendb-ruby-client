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
