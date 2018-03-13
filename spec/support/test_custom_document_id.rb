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
