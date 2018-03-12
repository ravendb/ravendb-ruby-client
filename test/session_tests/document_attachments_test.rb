require "ravendb"
require "spec_helper"

describe RavenDB::AttachmentOperation do
  ATTACHMENT = "47494638396101000100800000000000ffffff21f90401000000002c000000000100010000020144003b".freeze

  def setup
    @__test = RavenDatabaseTest.new(nil)
    @__test.setup
  end

  def teardown
    @__test.teardown
  end

  def store
    @__test.store
  end

  def test_should_put_attachment
    store.open_session do |session|
      product = Product.new(nil, "Test Product", 10, "a")

      session.store(product)
      session.save_changes

      refute_raises do
        store.operations.send(
          RavenDB::PutAttachmentOperation.new(product.id, "1x1.gif", [ATTACHMENT].pack("H*"), "image/gif"))
      end
    end
  end

  def test_should_get_attachment
    store.open_session do |session|
      attachment_raw = [ATTACHMENT].pack("H*")
      product = Product.new(nil, "Test Product", 10, "a")

      session.store(product)
      session.save_changes

      store.operations.send(
        RavenDB::PutAttachmentOperation.new(product.id, "1x1.gif", attachment_raw, "image/gif"))

      attachment_result = store.operations.send(
        RavenDB::GetAttachmentOperation.new(product.id, "1x1.gif", RavenDB::AttachmentType::Document))

      assert_equal(attachment_raw, attachment_result[:stream])
      assert_equal(product.id, attachment_result[:attachment_details][:document_id])
      assert_equal("image/gif", attachment_result[:attachment_details][:content_type])
      assert_equal("1x1.gif", attachment_result[:attachment_details][:name])
      assert_equal(attachment_raw.size, attachment_result[:attachment_details][:size])
    end
  end

  def test_should_delete_attachment
    store.open_session do |session|
      product = Product.new(nil, "Test Product", 10, "a")

      session.store(product)
      session.save_changes

      store.operations.send(
        RavenDB::PutAttachmentOperation.new(product.id, "1x1.gif", [ATTACHMENT].pack("H*"), "image/gif"))

      store.operations.send(
        RavenDB::DeleteAttachmentOperation.new(product.id, "1x1.gif"))

      assert_raises(RavenDB::DocumentDoesNotExistException) do
        store.operations.send(
          RavenDB::GetAttachmentOperation.new(product.id, "1x1.gif", RavenDB::AttachmentType::Document))
      end
    end
  end
end
