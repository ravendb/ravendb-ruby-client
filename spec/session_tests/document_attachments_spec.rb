require "ravendb"
require "spec_helper"

describe RavenDB::AttachmentOperation do
  ATTACHMENT = "47494638396101000100800000000000ffffff21f90401000000002c000000000100010000020144003b".freeze

  before do
    @__test = RavenDatabaseTest.new(nil)
    @__test.setup
  end

  after do
    @__test.teardown
  end

  let(:store) do
    @__test.store
  end

  it "puts attachment" do
    store.open_session do |session|
      product = Product.new(nil, "Test Product", 10, "a")

      session.store(product)
      session.save_changes

      expect do
        store.operations.send(
          RavenDB::PutAttachmentOperation.new(product.id, "1x1.gif", [ATTACHMENT].pack("H*"), "image/gif"))
      end.not_to(raise_error)
    end
  end

  it "gets attachment" do
    store.open_session do |session|
      attachment_raw = [ATTACHMENT].pack("H*")
      product = Product.new(nil, "Test Product", 10, "a")

      session.store(product)
      session.save_changes

      store.operations.send(
        RavenDB::PutAttachmentOperation.new(product.id, "1x1.gif", attachment_raw, "image/gif"))

      attachment_result = store.operations.send(
        RavenDB::GetAttachmentOperation.new(product.id, "1x1.gif", RavenDB::AttachmentType::Document))

      expect(attachment_result[:stream]).to(eq(attachment_raw))
      expect(attachment_result[:attachment_details][:document_id]).to(eq(product.id))
      expect(attachment_result[:attachment_details][:content_type]).to(eq("image/gif"))
      expect(attachment_result[:attachment_details][:name]).to(eq("1x1.gif"))
      expect(attachment_result[:attachment_details][:size]).to(eq(attachment_raw.size))
    end
  end

  it "deletes attachment" do
    store.open_session do |session|
      product = Product.new(nil, "Test Product", 10, "a")

      session.store(product)
      session.save_changes

      store.operations.send(
        RavenDB::PutAttachmentOperation.new(product.id, "1x1.gif", [ATTACHMENT].pack("H*"), "image/gif"))

      store.operations.send(
        RavenDB::DeleteAttachmentOperation.new(product.id, "1x1.gif"))

      expect do
        store.operations.send(
          RavenDB::GetAttachmentOperation.new(product.id, "1x1.gif", RavenDB::AttachmentType::Document))
      end.to(raise_error(RavenDB::DocumentDoesNotExistException))
    end
  end
end