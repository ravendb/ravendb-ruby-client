require "ravendb"
require "spec_helper"

class DocumentAttachmentsTest < RavenDatabaseTest
  ATTACHMENT = "47494638396101000100800000000000ffffff21f90401000000002c000000000100010000020144003b"

  def test_should_put_attachment
    @_store.open_session do |session|
      product = Product.new(nil, "Test Product", 10, "a")

      session.store(product)
      session.save_changes

      refute_raises do
        @_store.operations.send(
          RavenDB::PutAttachmentOperation.new(product.id, "1x1.gif",
          [ATTACHMENT].pack("H*"), "image/gif"
          )
        )
      end
    end
  end

  def test_should_get_attachment
    @_store.open_session do |session|
      attachment_raw = [ATTACHMENT].pack("H*")
      product = Product.new(nil, "Test Product", 10, "a")

      session.store(product)
      session.save_changes

      @_store.operations.send(
        RavenDB::PutAttachmentOperation.new(product.id, "1x1.gif",
        attachment_raw, "image/gif"
        )
      )

      attachment_result = @_store.operations.send(
        RavenDB::GetAttachmentOperation.new(product.id, "1x1.gif",
        RavenDB::AttachmentType::Document
        )
      )

      assert_equal(attachment_result[:stream], attachment_raw)
      assert_equal(attachment_result[:attachment_details][:document_id], product.id)
      assert_equal(attachment_result[:attachment_details][:content_type], "image/gif")
      assert_equal(attachment_result[:attachment_details][:name], "1x1.gif")
      assert_equal(attachment_result[:attachment_details][:size], attachment_raw.size)
    end
  end

  def test_should_delete_attachment
    @_store.open_session do |session|
      product = Product.new(nil, "Test Product", 10, "a")

      session.store(product)
      session.save_changes

      @_store.operations.send(
        RavenDB::PutAttachmentOperation.new(product.id, "1x1.gif",
        [ATTACHMENT].pack("H*"), "image/gif"
        )
      )

      @_store.operations.send(
        RavenDB::DeleteAttachmentOperation.new(product.id, "1x1.gif")
      )

      assert_raises(RavenDB::DocumentDoesNotExistException) do
        @_store.operations.send(
          RavenDB::GetAttachmentOperation.new(product.id, "1x1.gif",
          RavenDB::AttachmentType::Document
          )
        )
      end
    end
  end
end