class TestCustomSerializer < TestCustomDocumentId
  attr_accessor :item_options

  def initialize(
    item_id = nil,
    item_title = nil,
    item_options = []
  )
    super(item_id, item_title)
    @item_options = item_options
  end
end
