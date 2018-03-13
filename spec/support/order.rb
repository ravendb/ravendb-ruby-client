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
