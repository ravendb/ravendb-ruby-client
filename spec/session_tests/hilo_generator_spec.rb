RSpec.describe RavenDB::HiloIdGenerator do
  COLLECTION = "Products".freeze

  before do
    @__test = RavenDatabaseTest.new(nil)
    @__test.setup

    @generator = described_class.new(@__test.store, @__test.current_database, COLLECTION)
  end

  after do
    @generator.return_unused_range
    @__test.teardown
  end

  it "starts from 1" do
    id = @generator.generate_document_id

    expect(id).to eq("Products/1-A")
  end

  it "increments by 1" do
    id = nil
    prev_id = nil

    loop do
      id = @generator.generate_document_id

      unless prev_id.nil?
        expect(range(id) - range(prev_id)).to eq(1)
      end

      prev_id = id

      break if @generator.range.needs_new_range?
    end
  end

  it "requests new range" do
    max_id = nil

    loop do
      @generator.generate_document_id

      if max_id.nil?
        max_id = @generator.range.max_id
      end

      break if @generator.range.needs_new_range?
    end

    @generator.generate_document_id
    expect((@generator.range.min_id > max_id)).to be_truthy
  end

  protected

  def range(document_id)
    document_id.gsub("#{COLLECTION}/", "").gsub("-A", "").to_i
  end
end
