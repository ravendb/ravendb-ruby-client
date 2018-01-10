require 'ravendb'
require 'spec_helper'

class AuthenticationTest < RavenDatabaseTest
  def setup
    super

    @_invalid_cert = <<CERTIFICATE
-----BEGIN CERTIFICATE-----
MIIC8DCCAdigAwIBAgIICkVNN5rIPb8wDQYJKoZIhvcNAQENBQAwKjEVMBMGA1UE
AwwMUkFWRU5TRUNVUkVEMREwDwYDVQQKDAhyYXZlbmRiLjAeFw0xNzEyMDgwMDAw
MDBaFw0yMjEyMDgwMDAwMDBaMCoxKDAmBgNVBAMMH3JhdmVuc2VjdXJlZC5jbGll
bnQuY2VydGlmaWNhdGUwggEiMA0GCSqGSIb3DQEBAQUAA4IBDwAwggEKAoIBAQCC
e2Xra/pH8xEszBBn/SwzoyyFbSg32bwLM8aW/D4RNMigUy/5tvWbDQvlVv9Lgwzl
MakhXZFW0LEHYhRoce/5cN2TOTMDnm7TsaxsEGQ3ZwepxE7cDRfYyW5DV4zDSU9J
aWryvgTiM4g290fdEXqe6wRyxWvLI/RD0ImZ0j1eiEgbyaQglpONUaLg6dngd0ob
/6CPnks/Jr6iyfMpIyhR3f3AhSN7fLzNW4J9Zs1CsURR9kb54t8ufJ35yw8sq4+v
0/ZNIGXUyTqgwZs+kHvjVW/0id27jdwRvyDwSipB3tiwgOX1trYQUEz5PXoSZ6bF
V5MJB109iOtIOdDxwCBFAgMBAAGjGjAYMBYGA1UdJQEB/wQMMAoGCCsGAQUFBwMC
MA0GCSqGSIb3DQEBDQUAA4IBAQBu23lg/pRTUsYcesXMRrmRGe0AhktLoZshn6b+
bx0Bok3kROPnMHq/B9NX5CJWcRtbJ1ZWy8kthxNc5qf/bsuMUzXAIzKBdGNqtJFq
ct8Kt0iiXHmwBcIDRSW2bhlL1XVanz3D2yLQlhWvbTNm5ulnABqeFtmvitBwy6lb
yTmm+4fAcMt7uB02qXxcdZ+OC9IqrqMF8YEinoGfnfHJvKzYTjP9UAQxhihjv7eR
gV7VmHwtb2on3Ed7n4+tBTNjrnBKhORGaDrGHILCWpKWEVzAwyrEwN2MlPX6NzT/
t0QGHTkrMtApFhSIiiOh8Bvdz477yGNTULoGktpke4f2zGmn
-----END CERTIFICATE-----
-----BEGIN RSA PRIVATE KEY-----
MIIEogIBAAKCAQEAgntl62v6R/MRLMwQZ/0sM6MshW0oN9m8CzPGlvw+ETTIoFMv
+bb1mw0L5Vb/S4MM5TGpIV2RVtCxB2IUaHHv+XDdkzkzA55u07GsbBBkN2cHqcRO
3A0X2MluQ1eMw0lPSWlq8r4E4jOINvdH3RF6nusEcsVryyP0Q9CJmdI9XohIG8mk
IJaTjVGi4OnZ4HdKG/+gj55LPya+osnzKSMoUd39wIUje3y8zVuCfWbNQrFEUfZG
+eLfLnyd+csPLKuPr9P2TSBl1Mk6oMGbPpB741Vv9Indu43cEb8g8EoqQd7YsIDl
9ba2EFBM+T16EmemxVeTCQddPYjrSDnQ8cAgRQIDAQABAoIBABdBR2enMa7flQzL
HNRvxJA6cX2hOAUGNxO3CVqQ/73gzq32TYtfrpPRBjD8aZkrdOGnUWmrK7NRk++J
LTJ1Ngwar77kt6EaPE3Z8W08GaRfJjg9TsG8yqZ+NfrmEGYgu3MNyPwU3jlzbkA/
n6z4h8Zpg/wxj9XfZVItyUxjMkFV3oZA238lyIy/ha0FVA63sefN7eWuOHEPWkMP
kl+4OFh8j/6gOmTWUm1qmUSkEpSQkqWFMWCVmn8JjktwEnKbxel47MqSvWDEDMoN
b8c2rQ7zSOywMD3a3Stkc8OCogpAgf6vB3Hsm/xpVJE8BnLUCcp2QP7lTRybg1xt
cbx2BpkCgYEAzkPcjiSN6N7cQ+2Oh/tL1ekixaMJoU+UiRAkhDpxx07LOnVS7PeC
tQkzq0P4I00qm4AgDohggzeMBbcR8r2ucjMolMFQzQ19A+laQNWdgIW9nEPdUTeC
atKe5i1PH5JFekkIHVaZGo7uOerO0HmpjvdZl6pq0kSMbxmsWbhS6X0CgYEAofGr
rdaz1jmdld0SedVDX70l940fZdwijMA+UE1QPs+aOTA+b9mQjB6sdV/mlGwbPlDY
h48U5C2DSowgjtUmzS/7+IYVl0QeWFMM3DTlfyx4AttZnuXkcJ8uc1H17azlkIDG
XN2wP1N7NACP4pn0KnptAU+2T9/fKnV4bU2mjGkCgYACA6eju7enDoYYI7nAmjOj
YyNzyqPNb3mD3SR+JhP2Xk6dw4eLyN795Zkbkw5ZSeegnR+zBKHsph438BG8zR1n
ABjlWv3vArK11xGKkIt5NdUkMYV3xZMAeA4VMVwUctk62Hu7zZyxJbQt3J0obAe7
3a6CTKe+Zez5KMcGGUa2AQKBgEjkme0OljYYCvmY36cdOk1Ou1c5G2fi9V47bhEB
K9yJ35ZcQ85etLSNXf0bJJOsMXsUMtKZscKfRdh5SHJiOSvkrFsKJ4/F5o7FGyXH
XYGnx4EpsKZYPkH/NI5N1w+bYl1vyVmlo55teihHFHzf5Up1frk3Yw2C7FWVOJai
fBP5AoGARUJ/SFpqkZRqbkYZe8ogtvsAkeqNCS6FaT0Gck6Gy8YUITdH5ekymXen
HDq91ZHJhEQ7Hj3kUdpAymgN+OShcelJbmRlw3PUxNPmAYvDxJD9lL35YhwkCKqO
j32qw8tKsUBMO5zmCC6+IapqdBUr0F+BxJazO+mlQu2o9Ipas88=
-----END RSA PRIVATE KEY-----
CERTIFICATE
  end

  def test_should_raise_not_supported_exception_when_trying_to_connect_to_secured_server_without_auth_options
    assert_raises(RavenDB::NotSupportedException) do
      store = RavenDB::DocumentStore.new(
          ['https://secured.db.somedomain.com'], 'SomeDatabase'
      )

      store.configure
    end
  end

  def test_should_raise_unauthorized_exception_when_trying_to_connect_to_secured_server_with_invalid_certificate
    unless DEFAULT_URL.downcase.include?('https://')
      return
    end

    assert_raises(RavenDB::AuthorizationException) do
      store = RavenDB::DocumentStore.new(
          [DEFAULT_URL], @_current_database,
          RavenDB::StoreAuthOptions.new(@_invalid_cert)
      )

      store.configure
      store.open_session do |session|
        session.load('DocumentWillNotLoad/1')
      end
    end
  end
end