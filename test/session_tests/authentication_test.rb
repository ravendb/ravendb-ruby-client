require 'ravendb'
require 'spec_helper'

class AuthenticationTest < TestBase
  def test_should_raise_not_supported_exception_when_trying_to_connect_to_secured_server_without_auth_options
    assert_raises(RavenDB::NotSupportedException) do
      store = RavenDB::DocumentStore.new(
          'https://secured.db.somedomain.com', 'SomeDatabase'
      )

      store.configure
    end
  end
end