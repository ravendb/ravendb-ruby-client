# RavenDB client for Ruby

## Installation

For global install run:

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
<table>
    <tr>
        <th>Method</th>
        <th>RQL / description</th>
    </tr>
    <tr>
        <td><pre lang="ruby">select_fields(fields, projections = nil)</pre></td>
        <td><pre lang="sql">SELECT field1 [AS projection1], ...</pre></td>
    </tr>
    <tr>
        <td><pre lang="ruby">distinct</pre></td>
        <td><pre lang="sql">SELECT DISTINCT</pre></td>
    </tr>
    <tr>
        <td><pre lang="ruby">where_equals(field_name, value, 
exact = false)</pre></td>
        <td><pre lang="sql">WHERE fieldName = &lt;value&gt;</pre></td>
    </tr>
    <tr>
        <td><pre lang="ruby">where_not_equals(field_name, value, 
exact = false)</pre></td>
        <td><pre lang="sql">WHERE fieldName != &lt;value&gt;</pre></td>
    </tr>
    <tr>
        <td><pre lang="ruby">where_in(field_name, values, exact = false)</pre></td>
        <td><pre lang="sql">WHERE fieldName IN (&lt;value1&gt;, &lt;value2&gt;, ...)</pre></td>
    </tr>
    <tr>
        <td><pre lang="ruby">where_starts_with(field_name, value)</pre></td>
        <td><pre lang="sql">WHERE startsWith(fieldName, '&lt;value&gt;')</pre></td>
    </tr>
    <tr>
        <td><pre lang="ruby">where_ends_with(field_name, value)</pre></td>
        <td><pre lang="sql">WHERE endsWith(fieldName, '&lt;value&gt;')</pre></td>
    </tr>
    <tr>
        <td><pre lang="ruby">where_between(field_name, from, to, 
exact = nil)</pre></td>
        <td><pre lang="sql">WHERE fieldName BETWEEN &lt;start&gt; AND &lt;end&gt;</pre></td>
    </tr>
    <tr>
        <td><pre lang="ruby">where_greater_than(field_name, value, 
exact = nil)</pre></td>
        <td><pre lang="sql">WHERE fieldName > &lt;value&gt;</pre></td>
    </tr>
    <tr>
        <td><pre lang="ruby">where_greater_than_or_equal(field_name, 
value, exact = nil)</pre></td>
        <td><pre lang="sql">WHERE fieldName >= &lt;value&gt;</pre></td>
    </tr>
    <tr>
        <td><pre lang="ruby">where_less_than(field_name, value, 
exact = nil)</pre></td>
        <td><pre lang="sql">WHERE fieldName < &lt;value&gt;</pre></td>
    </tr>
    <tr>
        <td><pre lang="ruby">where_less_than_or_equal(field_name, 
value, exact = nil)</pre></td>
        <td><pre lang="sql">WHERE fieldName <= &lt;value&gt;</pre></td>
    </tr>
    <tr>
        <td><pre lang="ruby">where_exists(field_name)</pre></td>
        <td><pre lang="sql">WHERE exists(fieldName)</pre></td>
    </tr>
    <tr>
        <td><pre lang="ruby">contains_any(field_name, values)</pre></td>
        <td><pre lang="sql">WHERE fieldName IN (&lt;value1&gt;, &lt;value2&gt;, ...)</pre></td>
    </tr>
    <tr>
        <td><pre lang="ruby">contains_all(field_name, values)</pre></td>
        <td><pre lang="sql">WHERE fieldName ALL IN (&lt;value1&gt;, &lt;value2&gt;, ...)</pre></td>
    </tr>
    <tr>
        <td><pre lang="ruby">search(field_name, search_terms, 
operator = RavenDB::SearchOperator::Or)</pre></td>
        <td>Performs full-text search</td>
    </tr>
    <tr>
        <td><pre lang="ruby">open_subclause</pre></td>
        <td>Opens subclause <code>(</code></pre>
        </td>
    </tr>
    <tr>
        <td><pre lang="ruby">close_subclause</pre></td>
        <td>Closes subclause <code>)</code></td>
    </tr>
    <tr>
        <td><pre lang="ruby">negate_next</pre></td>
        <td>Adds <code>NOT</code> before next condition</td>
    </tr>
    <tr>
        <td><pre lang="ruby">and_also</pre></td>
        <td>Adds <code>AND</code> before next condition</td>
    </tr>
    <tr>
        <td><pre lang="ruby">or_else</pre></td>
        <td>Adds <code>OR</code> before next condition</td>
    </tr>
    <tr>
        <td><pre lang="ruby">using_default_operator(operator)</pre></td>
        <td>Sets default operator (which will be used if no <code>and_also</code> / <code>or_else</code> was called. Just after query instantiation, <code>OR</code> is used as default operator. Default operator can be changed only before adding any conditions</td>
    </tr>
    <tr>
        <td><pre lang="ruby">order_by(field, ordering_type = nil)</pre></td>
        <td><pre lang="sql">ORDER BY field</pre></td>
    </tr>
    <tr>
        <td><pre lang="ruby">order_by_descending(field, 
ordering_type = nil)</pre></td>
        <td><pre lang="sql">ORDER BY field DESC</pre></td>
    </tr>
    <tr>
        <td><pre lang="ruby">random_ordering(seed = nil)</pre></td>
        <td><pre lang="sql">ORDER BY random()</pre></td>
    </tr>
    <tr>
        <td><pre lang="ruby">take(count)</pre></td>
        <td>Limits the number of result entries to <code>count</code></td>
    </tr>
    <tr>
        <td><pre lang="ruby">skip(count)</pre></td>
        <td>Skips first <code>count</code> results</td>
    </tr>
    <tr>
        <td><pre lang="ruby">first</pre></td>
        <td>Returns first document from result set</td>
    </tr>
    <tr>
        <td><pre lang="ruby">single</pre></td>
        <td>Returns single document matching query criteria. If there are no such document or more then one - throws an Exception</td>
    </tr>
    <tr>
        <td><pre lang="ruby">all</pre></td>
        <td>Returns all documents from result set (considering <code>take</code> / <code>skip</code> options)</td>
    </tr>
    <tr>
        <td><pre lang="ruby">count</pre></td>
        <td>Returns count of all documents matching query criteria (non-considering <code>take</code> / <code>skip</code> options)</td>
    </tr>
</table>


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

## Advanced features

#### Attachments support

You can attach binary files to documents. 

1. For attach a file, use `RavenDB::PutAttachmentOperation`. Pass document id, attachment name (it can be just a file name), content type and file contents:

```ruby
require 'ravendb'

# ...
file_name = './iphone-x.png'

store.operations.send(
  RavenDB::PutAttachmentOperation.new(
    'Products/1-A', 
    File.basename(fileName), 
    File.read(fileName), 
    'image/png' 
  )
)   
```

2. For read an attachment, use `RavenDB::GetAttachmentOperation`. Pass document id and attachment name. File contents will be stored as `:stream` key of response:

```ruby
require 'ravendb'

# ...
file_name = 'iphone-x.png'

attachment_result = store.operations.send(
  RavenDB::GetAttachmentOperation.new(
    'Products/1-A', 
    file_name, 
    RavenDB::AttachmentType::Document
  )
)

file = File.new(`./${fileName}`, "wb")
file.write(attachment_result[:stream])
file.close
```

3. For delete an attachment, use `RavenDB::DeleteAttachmentOperation`. Pass document id and attachment name.

```ruby
require 'ravendb'

# ...
file_name = 'iphone-x.png'

store.operations.send(
  RavenDB::DeleteAttachmentOperation(
    'Products/1-A', 
    file_name
  )
)
```

#### Custom document id property

By default document id is stored onto `id` property of document. But you can define which name of id property should be for specific document types. 

1. Call `store.conventions.add_id_property_resolver` and pass an callback block. It accepts document info hash and should return id property name:

```ruby
# models/item.rb
class Item
  attr_accessor :item_id, :item_title, :item_options

  def initialize(item_id = nil, item_title = "", item_options = [])
    @item_id = item_id
    @item_title = item_title   
    @item_options = item_options 
  end  
end

# main.rb
require 'ravendb'
    
# ...
store.conventions.add_id_property_resolver do |document_info|
  case document_info[:document_type]
  when Item.name
    'item_id'
  else
    'id'  
  end
end
```

2. Now client will read/fill `item_id` property with document id while doing CRUD operations:

```ruby
session = store.open_session

session.store(Item.new(nil, 'First Item', [1, 2, 3]))
session.save_changes()

puts item.item_id # Items/1-A

session = store.open_session
item = session.load('Items/1-A')

puts item.item_id # Items/1-A
puts item.item_title # First Item
puts item.item_options.inspect # [1, 2, 3]
```

#### Custom attributes serializer

You can define custom serializers if you need to implement your own logic for convert attributes names/values for specific document types.

1. Define your serializer as an class derived from `RavenDB::AttributeSerializer`.  Override `on_serialized` / `on_unserialized` methods:

```ruby
class CustomAttributeSerializer < RavenDB::AttributeSerializer
  def on_serialized(serialized)
  end

  def on_unserialized(serialized)
  end
end
```

Where `serialized` attribute is a hash wuth the following structure:

```ruby
{
  :source => <source json hash / document model>,
  :target => <target json hash / document model>,
  :original_attribute => <original attribute name>,
  :serialized_attribute => <target attribute name>,
  :original_value => <original attribute value>,
  :serialized_value => <target attribute value>,
  :metadata => <document metadata hash>
}
```

2. Store target attribute name/value into the `serialized_attribute`/`serialized_value` properties of `serialized` parameter:

```ruby
# serializers/custom.rb

class CustomAttributeSerializer < RavenDB::AttributeSerializer
  def on_serialized(serialized)
    metadata = serialized[:metadata]

    case metadata['Raven-Ruby-Type']
    when TestCustomSerializer.name
      serialized[:serialized_attribute] = serialized[:original_attribute].camelize(:lower)

      if serialized[:original_attribute] == 'item_options'
        serialized[:serialized_value] = serialized[:original_value].join(",")
      end
    else
      nil  
    end
  end

  def on_unserialized(serialized)
    metadata = serialized[:metadata]

    case metadata['Raven-Ruby-Type']
    when TestCustomSerializer.name
      serialized[:serialized_attribute] = serialized[:original_attribute].underscore

      if serialized[:original_attribute] == 'itemOptions'
        serialized[:serialized_value] = serialized[:original_value].split(",").map { |option| option.to_i }
      end
    else
      nil  
    end
  end
end
```

3. Pass your serializer object to `conventions.add_attribute_serializer`:

```ruby
require 'ravendb'
require './serializers/custom'

store.conventions.add_attribute_serializer(serializer)

sesssion = store.open_session()

session.store(Item.new(nil, 'First Item', [1, 2, 3]))
session.save_changes

session = store.open_session
item = session.load('Items/1-A')

puts item.item_id # Items/1-A
puts item.item_title # First Item
puts item.item_options.inspect # [1, 2, 3]

response = store.get_request_executor.execute(RavenDB::GetDocumentCommand.new('Items/1-A'))
raw_document = response['Results'].first

puts raw_document['@metadata']['@id'] # Items/1-A
puts raw_document['itemTitle'] # First Item
puts raw_document['itemOptions'] # "1,2,3"
```

## Running tests

```bash
URL=<RavenDB server url including port> [CERTIFICATE=<path to .pem certificate> [PASSPHRASE=<.pem certificate passphrase>]] rake test
```
