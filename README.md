# RavenDB client for Ruby

## Installation

For global intsall run:

```bash
gem install --save ravendb
```

Or require `ravendb` gem in your project's `Gemfile`:

```
source 'https://rubygems.org'
gem 'ravendb'
```

## Getting started

1. Declare document models as classes. Attributes should be just an instance variables accessible via `attr_accessor()`

```ruby
class Product
  :attr_accessor :id, :title, :price, :currency,
                 :storage, :manufacturer, :in_stock,
                 :last_update
  
  def initialize(
    id = nil,
    title = '',
    price = 0,
    currency = 'USD',
    storage = 0,
    manufacturer = '',
    in_stock = false,
    last_update = nil
  )
    @id = id
    @title = title
    @price = price
    @currency = currency
    @storage
    @manufacturer = manufacturer
    @in_stock = in_stock
    @last_update = last_update
  end
end
```

2. Require `ravendb` gem and models classes in your application:

```ruby
require 'ravendb'
require 'models/product'
```

3. Configure document store:

```ruby
RavenDB.store.configure do |config|
  config.urls = ["database url"]
  config.database = 'database name'
end
```

3. Open a session:

```ruby
session = RavenDB.store.open_session
```

4. Do some actions with documents:

```ruby
product = session.load('Products/1-A')
product.in_stock = true
```

5. Call `save_changes` when you'll finish working with a session:

```ruby
session.save_changes
```

6. Also you can wrap all actions done with a session in a nested block:

```ruby
RavenDB.store.open_session do |session|
  product = session.load('Products/1-A')
  product.in_stock = true

  session.save_changes
end
```

## CRUD example

### Creating documents

```ruby
product = Product.new('iPhone X', 999.99, 'USD', 64, 'Apple', true, DateTime.new(2017, 10, 1, 0, 0, 0))

RavenDB.store.open_session do |session|
  product = session.store(product)
  
  puts product.id # will output Products/<some number>-<some letter (server node tag)> e.g. Products/1-A
  session.save_changes
end  
```

### Loading documents

```ruby
RavenDB.store.open_session do |session|
  product = session.load('Products/1-A')
  
  puts product.title # iPhone X
  puts product.id # Products/1-A
end
```

### Updating documents
```ruby
RavenDB.store.open_session do |session|
  product = session.load('Products/1-A')
  
  product.in_stock = false
  product.last_update = DateTime.now

  session.save_changes

  product = session.load('Products/1-A')
  
  puts product.in_stock.inspect # false
  puts product.last_update # outputs current date
end  
```

### Deleting documents

```ruby
RavenDB.store.open_session do |session|
  product = session.load('Products/1-A')
  
  session.delete(product)
  # or you can just do
  # session.delete('Products/1-A')
  session.save_changes

  product = session.load('Products/1-A')
  puts product.inspect # nil
end
```

## Querying documents

1. Create `RavenDB::DocumentQuery` instance using `query` method of session:
```ruby
query = session.query({
  :collection => 'Products', # specify which collection you'd like to query
  # optionally you may specify an index name for querying
  # :index_name => 'PopularProductsWithViewsCount'
})
```
2. Apply conditions, ordering etc. Query supports chaining calls:
```ruby
query
  .wait_for_non_stale_results
  .using_default_operator(RavenDB::QueryOperator::And)  
  .where_equals('manufacturer', 'Apple')
  .where_equals('in_stock', true)
  .where_between('last_update', DateTime.strptime('2017-10-01T00:00:00', '%Y-%m-%dT%H:%M:%S'), DateTime::now)
  .order_by('price')
```
3. Finally, you may get query results:
```
documents = query.all
```

5. If you used `select_fields` method in in query, pass document class (or class name) as `:document_type` parameter in the query options:

```ruby
products_with_names_only = session.query({
    :document_type => Product,
    :collection => 'Products'
  })
  .select_fields(['name'])
  .wait_for_non_stale_results
  .all
```

#### RavenDB::DocumentQuery methods overview
| Method | RQL / description |
| ------------- | ------------- |
|`select_fields(fields, projections = nil)`|`SELECT field1 [AS projection1], ...`|
|`distinct(): this;`|`SELECT DISTINCT`|
|`where_equals(field_name, value, exact = false)`|`WHERE fieldName = <value>`|
|`where_not_equals(field_name, value, exact = false)`|`WHERE fieldName != <value>`|
|`where_in(field_name, values, exact = false)`|`WHERE fieldName IN (<value1>, <value2>, ...)`|
|`where_starts_with(field_name, value)`|`WHERE startsWith(fieldName, '<value>')`|
|`where_ends_with(field_name, value)`|`WHERE endsWith(fieldName, '<value>')`|
|`where_between(field_name, from, to, exact = nil)`|`WHERE fieldName BETWEEN <start> AND <end>`|
|`where_greater_than(field_name, value, exact = nil)`|`WHERE fieldName > <value>`|
|`where_greater_than_or_equal(field_name, value, exact = nil)`|`WHERE fieldName >= <value>`|
|`where_less_than(field_name, value, exact = nil)`|`WHERE fieldName < <value>`|
|`where_less_than_or_equal(field_name, value, exact = nil)`|`WHERE fieldName <= <value>`|
|`where_exists(field_name)`|`WHERE exists(fieldName)`|
|`contains_any(field_name, values)`|`WHERE fieldName IN (<value1>, <value2>, ...)`|
|`contains_all(field_name, values)`|`WHERE fieldName ALL IN (<value1>, <value2>, ...)`|
|`search(field_name, search_terms, operator = RavenDB::SearchOperator::Or)`|Performs full-text search|
|`open_subclause`|Opens subclause `(`|
|`close_subclause`|Closes subclause `)`|
|`negate_next`|Adds `NOT` before next condition|
|`and_also`|Adds `AND` before next condition|
|`or_else`|Adds `OR` before next condition|
|`using_default_operator(operator)`|Sets default operator (which will be used if no `andAlso()` / `orElse` was called. Just after query instantiation, `OR` is used as default operator. Default operator can be changed only before adding any conditions|
|`order_by(field, ordering_type = nil)`|`ORDER BY field`|
|`order_by_descending(field, ordering_type = nil)`|`ORDER BY field DESC`|
|`random_ordering(seed = nil)`|`ORDER BY random()`|
|`take(count)`|`Limits the number of result entries to *count* `|
|`skip(count)`|`Skips first *count* results `|
|`first`|Returns first document from result set|
|`single`|Returns single document matching query criteria. If there are no such document or more then one - throws an Exception|
|`all`|Returns all documents from result set (considering `take` / `skip` options)|
|`count`|Returns count of all documents matching query criteria (non-considering `take` / `skip` options)|

## Working with secured server
1. Instantiate `RavenDB::StoreAuthOptions`. Pass contents of the .pem certificate and passphrase (optional) to constructor:
```ruby
certificate = <<CERTIFICATE
-----BEGIN CERTIFICATE-----
...
-----END CERTIFICATE-----
-----BEGIN RSA PRIVATE KEY-----
...
-----END RSA PRIVATE KEY-----
CERTIFICATE
auth_options = RavenDB::StoreAuthOptions.new(certificate)

#or 

auth_options = RavenDB::StoreAuthOptions.new(certificate, "my passphrase")
``` 
2. Pass `RavenDB::StoreAuthOptions` instance to `auth_options` config option when you're configuring store:

```ruby
RavenDB.store.configure do |config|
  config.urls = ["database url"]
  config.database = 'database name'
  config.auth_options = RavenDB::StoreAuthOptions.new(certificate)
end
```

#### Auth exceptions
- if no `RavenDB::StoreAuthOptions` was provided and you're trying to work with secured server, an `RavenDB::NotSupportedException` will be raised during store initialization
- if certificate is invalid or doesn't have permissions for specific operations, an `RavenDB::AuthorizationException` will be raised

## Running tests

```bash
URL=<RavenDB server url including port> [CERTIFICATE=<path to .pem certificate> [PASSPHRASE=<.pem certificate passphrase>]] rake test
```
