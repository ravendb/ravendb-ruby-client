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
    @ordering = ordering unless ordering.nil?
  end
end
