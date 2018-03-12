describe RavenDB::JsonSerializer do
  before do
    @__test = RavenTest.new(nil)
    @__test.setup

    @json = {
      "@metadata" => {},
      "string_prop" => "string",
      "number_prop" => 2,
      "number_float_prop" => 2.5,
      "boolean_prop" => true,
      "nil_prop" => nil,
      "hash_prop" => {
        "string_prop" => "string",
        "number_prop" => 2,
        "number_float_prop" => 2.5,
        "boolean_prop" => true,
        "nil_prop" => nil,
        "array_prop" => [1, 2, 3]
      },
      "array_prop" => [1, 2, 3],
      "deep_hash_prop" => {
        "some_prop" => "someValue",
        "some_hash" => {
          "some_prop" => "someValue"
        }
      },
      "deep_array_prop" => [
        1, 2, [3, 4]
      ],
      "deep_array_hash_prop" => [
        1, 2, {
          "some_prop" => "someValue",
          "some_array" => [3, 4]
        }, [5, 6], [7, 8, {
          "some_prop" => "someValue"
        }]
      ],
      "date_prop" => "2017-06-04T18:39:05.1230000",
      "deep_foo_prop" => {
        "@metadata" => {},
        "id" => "foo1",
        "name" => "Foo #1",
        "order" => 1
      },
      "deep_array_foo_prop" => [{
        "@metadata" => {},
        "id" => "foo2",
        "name" => "Foo #2",
        "order" => 2
      }, {
        "@metadata" => {},
        "id" => "foo3",
        "name" => "Foo #3",
        "order" => 3
      }]
    }

    @nested_object_types = {
      "date_prop" => "date",
      "deep_foo_prop" => Foo.name,
      "deep_array_foo_prop" => Foo.name
    }

    @document = SerializingTest.new
    described_class.from_json(@document, @json, {}, @nested_object_types, store.conventions)
  end

  after do
    @__test.teardown
  end

  let(:store) do
    @__test.store
  end

  it "parses scalars" do
    expect(@document.string_prop.is_a?(String)).to eq(true)
    expect(@document.string_prop).to eq("string")
    expect(@document.number_prop.is_a?(Numeric)).to eq(true)
    expect(@document.number_prop).to eq(2)
    expect(@document.number_float_prop.is_a?(Numeric)).to eq(true)
    expect(@document.number_float_prop).to eq(2.5)
    expect(((!(!@document.boolean_prop)) == @document.boolean_prop)).to be_truthy
    expect(@document.boolean_prop).to eq(true)
    expect(@document.nil_prop.nil?).to eq(true)
  end

  it "parses arrays" do
    expect(@document.array_prop.is_a?(Array)).to eq(true)
    expect(@document.array_prop.size).to eq(3)
    expect(@document.array_prop).to eq([1, 2, 3])
  end

  it "parses deep arrays" do
    deep = @document.deep_array_prop[2]

    expect(@document.deep_array_prop.is_a?(Array)).to eq(true)
    expect(@document.deep_array_prop.size).to eq(3)
    expect(@document.deep_array_prop).to eq([1, 2, [3, 4]])

    expect(deep.is_a?(Array)).to eq(true)
    expect(deep.size).to eq(2)
    expect(deep).to eq([3, 4])
  end

  it "parses hashes" do
    expect(@document.hash_prop.is_a?(Hash)).to eq(true)
    expect(@document.hash_prop.key?("string_prop")).to eq(true)
    expect(@document.hash_prop.key?("number_prop")).to eq(true)
    expect(@document.hash_prop.key?("number_float_prop")).to eq(true)
    expect(@document.hash_prop.key?("boolean_prop")).to eq(true)
    expect(@document.hash_prop.key?("nil_prop")).to eq(true)
    expect(@document.hash_prop.key?("array_prop")).to eq(true)

    expect(@document.hash_prop["string_prop"].is_a?(String)).to eq(true)
    expect(@document.hash_prop["string_prop"]).to eq("string")
    expect(@document.hash_prop["number_prop"].is_a?(Numeric)).to eq(true)
    expect(@document.hash_prop["number_prop"]).to eq(2)
    expect(@document.hash_prop["number_float_prop"].is_a?(Numeric)).to eq(true)
    expect(@document.hash_prop["number_float_prop"]).to eq(2.5)
    expect(((!(!@document.hash_prop["boolean_prop"])) == @document.hash_prop["boolean_prop"])).to be_truthy
    expect(@document.hash_prop["boolean_prop"]).to eq(true)
    expect(@document.hash_prop["nil_prop"].nil?).to eq(true)

    expect(@document.hash_prop["array_prop"].is_a?(Array)).to eq(true)
    expect(@document.hash_prop["array_prop"].size).to eq(3)
    expect(@document.hash_prop["array_prop"]).to eq([1, 2, 3])
  end

  it "parses deep hashes" do
    deep = @document.deep_hash_prop["some_hash"]

    expect(@document.deep_hash_prop.is_a?(Hash)).to eq(true)
    expect(@document.deep_hash_prop.key?("some_prop")).to eq(true)
    expect(@document.deep_hash_prop["some_prop"]).to eq("someValue")

    expect(deep.is_a?(Hash)).to eq(true)
    expect(deep.key?("some_prop")).to eq(true)
    expect(deep["some_prop"]).to be_truthy
  end

  it "parses mixed deep arrays hashes" do
    deep_hash = @document.deep_array_hash_prop[2]
    deep_array_in_hash = deep_hash["some_array"]
    deep_array = @document.deep_array_hash_prop[4]
    deep_hash_in_array = deep_array[2]

    expect(deep_hash.is_a?(Hash)).to eq(true)
    expect(deep_hash.key?("some_prop")).to eq(true)
    expect(deep_hash["some_prop"]).to eq("someValue")

    expect(deep_array_in_hash.is_a?(Array)).to eq(true)
    expect(deep_array_in_hash.size).to eq(2)
    expect(deep_array_in_hash).to eq([3, 4])

    expect(deep_array.is_a?(Array)).to eq(true)
    expect(deep_array.size).to eq(3)
    expect(deep_array[0]).to eq(7)
    expect(deep_array[1]).to eq(8)

    expect(deep_hash_in_array.is_a?(Hash)).to eq(true)
    expect(deep_hash_in_array.key?("some_prop")).to eq(true)
    expect(deep_hash_in_array["some_prop"]).to eq("someValue")
  end

  it "parses dates" do
    expect(@document.date_prop.is_a?(DateTime)).to eq(true)
    expect(RavenDB::TypeUtilities.stringify_date(@document.date_prop)).to be_truthy
  end

  it "parses deep objects and arrays according to specified nested objects types" do
    expect(@document.deep_array_foo_prop.is_a?(Array)).to eq(true)

    target = [@document.deep_foo_prop].concat(@document.deep_array_foo_prop)
    source = [@json["deep_foo_prop"]].concat(@json["deep_array_foo_prop"])

    target.each_index do |index|
      item = target[index]
      source_item = source[index]

      expect(item.is_a?(Foo)).to eq(true)
      expect(source_item["id"]).to eq(item.id)
      expect(source_item["name"]).to eq(item.name)
      expect(source_item["order"]).to eq(item.order)
    end
  end

  it "serializes back to source json" do
    serialized = described_class.to_json(@document, store.conventions)

    expect(@json).to eq(serialized)
  end
end
