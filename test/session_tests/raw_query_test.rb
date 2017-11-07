require 'date'
require 'ravendb'
require 'spec_helper'

class RawQueryTest < TestBase
  def setup
    super

    LastFmAnalyzed.new(@_store).execute
    ProductsTestingSort.new(@_store).execute

    @_store.open_session do |session|
      session.store(LastFm.new("LastFms/1", "Tania Maria", "TRALPJJ128F9311763", "Come With Me"))
      session.store(LastFm.new("LastFms/2", "Meghan Trainor", "TRBCNGI128F42597B4", "Me Too"))
      session.store(LastFm.new("LastFms/3", "Willie Bobo", "TRAACNS128F14A2DF5", "Spanish Grease"))
      session.store(Product.new('Products/101', 'test101', 2, 'a'))
      session.store(Product.new('Products/10', 'test10', 3, 'b'))
      session.store(Product.new('Products/106', 'test106', 4, 'c'))
      session.store(Product.new('Products/107', 'test107', 5))
      session.store(Product.new('Products/103', 'test107', 6))
      session.store(Product.new('Products/108', 'new_testing', 90, 'd'))
      session.store(Product.new('Products/110', 'paginate_testing', 95))
      session.store(Order.new('Orders/105', 'testing_order', 92, 'Products/108'))
      session.store(Company.new('Companies/1', 'withNesting', Product.new(nil, 'testing_order', 4)))

      session.save_changes
    end
  end

  def test_should_search_by_single_keyword
    @_store.open_session do |session|
      results = session.advanced.raw_query(
        "FROM INDEX '#{LastFmAnalyzed.name}' "\
        "WHERE search(query, $query)", {
        :query => 'Me'
      })
      .wait_for_non_stale_results
      .all

      assert_equal(results.size, 2)
      results.each{|last_fm| check_fulltext_search_result(last_fm, ['Me'])}
    end
  end

  def test_should_search_by_two_keywords
    @_store.open_session do |session|
      results = session.advanced.raw_query(
        "FROM INDEX '#{LastFmAnalyzed.name}' "\
        "WHERE search(query, $query)", {
        :query => 'Me Bobo'
      })
      .wait_for_non_stale_results
      .all

      assert_equal(results.size, 3)

      results.each do |last_fm|
        check_fulltext_search_result(last_fm, ['Me', 'Bobo'])
      end
    end
  end

  def test_should_search_full_text_with_boost
    @_store.open_session do |session|
      results = session.advanced.raw_query(
        "FROM INDEX '#{LastFmAnalyzed.name}' "\
        "WHERE boost(search(query, $me), 10) "\
        "OR boost(search(query, $bobo), 2)", {
        :me => 'Me',
        :bobo => 'Bobo'
      })
      .wait_for_non_stale_results
      .all

      assert_equal(results.size, 3)
      assert_equal(results.last.title, 'Spanish Grease')

      results.each do |last_fm|
        check_fulltext_search_result(last_fm, ['Me', 'Bobo'])
      end
    end
  end

  protected
  def check_fulltext_search_result(last_fm, query)
    search_in = []
    fields = ["artist", "title"]

    fields.each {|field| query.each {|keyword|
      search_in.push({
        :keyword => keyword,
        :sample => last_fm.instance_variable_get("@#{field}")
      })
    }}

    assert(search_in.any? {|comparsion|
      comparsion[:sample].include?(comparsion[:keyword])
    })
  end
end