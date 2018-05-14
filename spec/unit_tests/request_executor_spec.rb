RSpec.describe RavenDB::RequestExecutor do
  describe "::validate_urls", rdbc_167: true do
    [
      "invalid",
      "http:/",
      "http://",
      "  http://example.com"
    ].each do |url|
      it "raises error on invalid URL #{url}" do
        expect do
          RavenDB::RequestExecutor.validate_urls(urls: [url])
        end.to raise_error(RuntimeError, "The url '#{url}' is not valid.")
      end
    end

    [
      "http://test",
      "http://user:password@example.com:1234",
      "https://foo.bar"
    ].each do |url|
      it "accepts valid URL #{url}" do
        expect(RavenDB::RequestExecutor.validate_urls(urls: [url])).to eq([url])
      end
    end

    {
      "http://www.example.com"         => "http://www.example.com",
      "http://www.example.com/"        => "http://www.example.com",
      "http://www.example.com//"       => "http://www.example.com",
      "https://www.example.com:1010//" => "https://www.example.com:1010"
    }.each do |base_url, clean_url|
      it "cleans URL #{base_url} as #{clean_url}" do
        expect(RavenDB::RequestExecutor.validate_urls(urls: [base_url])).to eq([clean_url])
      end
    end

    it "does not allow mixing HTTP and HTTPS urls" do
      urls = [
        "http://example.com",
        "https://example.com"
      ]

      expect do
        RavenDB::RequestExecutor.validate_urls(urls: urls)
      end.to raise_error(RuntimeError, "The url 'http://example.com' is using HTTP, but other urls are using HTTPS, and mixing of HTTP and HTTPS is not allowed.")
    end

    it "does not allow using HTTP if certificate is provided" do
      expect do
        RavenDB::RequestExecutor.validate_urls(urls: ["http://example.com"], certificate: true)
      end.to raise_error(RuntimeError, "The url 'http://example.com' is using HTTP, but a certificate is specified, which require us to use HTTPS.")
    end
  end
end
