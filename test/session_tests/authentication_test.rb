require 'ravendb'
require 'spec_helper'
require 'database/exceptions'

class AuthenticationTest < TestBase
  def test_should_raise_not_supported_exception_when_trying_to_connect_to_secured_server
    assert_raises(RavenDB::NotSupportedException) do
      store = RavenDB::DocumentStore.new(
          'https://secured.db.somedomain.com', 'SomeDatabase'
      )

      store.configure
    end
  end
end