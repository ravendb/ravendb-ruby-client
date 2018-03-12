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
