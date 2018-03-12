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
