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
  config.default_database = 'default database name'
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

session.store(product)
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

  session.store(product)
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

  session.store(product)
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

At this moment only `RawDocumentQuery` is supported, query builder is under development.

1. Create `RawDocumentQuery` instance using `session.advanced.raw_query` method:

```ruby
query = session.advanced.raw_query("FROM Products")
```
2. You can pass params to query. In query you should use `$` symbol before parameter name, for pass values to query, pass to second `raw_query` method parameter an hash where keys are symbols corresponding to parameter names:

```ruby
query = session.advanced.raw_query(
  "FROM Products WHERE manufacturer = $manufacturer", 
  {:manufacturer => "Apple"}
)
```

3. For pass dates as parameter value, use `RavenDB::TypeUtilities::stringify_date`:

```ruby
session.advanced.raw_query(
  "FROM Products WHERE last_update >= $begin_of_week", {
  :begin_of_week => RavenDB::TypeUtilities::stringify_date(DateTime.new(2017, 11, 6, 0, 0, 0))
})
```

4. Apply pagination, set wait for non-stale results flag etc:

```ruby
query
  .wait_for_non_stale_results
  .skip(10)
  .take(10)
```

5. Finally, you may get query results:

```
products = query.all
```

6. You can wrap all actions done with query in a block:

```ruby
session.advanced.raw_query("FROM Products") |query|
  products = query
    .wait_for_non_stale_results
    .skip(10)
    .take(10)
    .all 
end
```

7. If you're using SELECT clause in query, pass document class (or class name) as `:document_type` parameter in the query options:

```ruby
products_with_names_only = session.advanced.raw_query(
  "FROM Products SELECT name", 
  {}, {:document_type => Product}
)
.wait_for_non_stale_results
.all
```

#### RawDocumentQuery methods overview
| Method | RQL / description |
| ------------- | ------------- |
|`take(count)`|`Limits the number of result entries to *count* `|
|`skip(count)`|`Skips first *count* results `|
|`first`|Returns first document from result set|
|`single`|Returns single document matching query criteria. If there are no such document or more then one - throws an Exception|
|`all`|Returns all documents from result set (considering `take` / `skip` options)|
|`count`|Returns count of all documents matching query criteria (non-considering `take` / `skip` options)|


## Running tests

```bash
URL=<RavenDB server url including port> rake test
```