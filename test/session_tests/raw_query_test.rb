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

  def test_should_query_by_single_condition
    @_store.open_session do |session|
      results = session.advanced.raw_query(
        "FROM Products "\
        "WHERE name = $name", {
        :name => 'test101'
      })
      .wait_for_non_stale_results
      .all

      assert_equal(results.size, 1)
      assert_equal(results.first.name, 'test101')
    end
  end

  def test_should_query_by_few_conditions_joined_by_or
    @_store.open_session do |session|
      results = session.advanced.raw_query(
        "FROM Products "\
        "WHERE name = $name "\
        "OR uid = $uid", {
        :name => 'test101',
        :uid => 4
      })
      .wait_for_non_stale_results
      .all

      assert_equal(results.size, 2)
      assert(results.first.name.include?('test101') || results.last.name.include?('test101'))
      assert(results.first.uid == 2 || results.last.uid == 2)
    end
  end

  def test_should_query_by_few_conditions_joined_by_and
    @_store.open_session do |session|
      results = session.advanced.raw_query(
        "FROM Products "\
        "WHERE name = $name "\
        "AND uid = $uid", {
        :name => 'test107',
        :uid => 5
      })
      .wait_for_non_stale_results
      .all

      assert_equal(results.size, 1)
      assert_equal(results.first.name, 'test107')
      assert_equal(results.first.uid, 5)
    end
  end

  def test_should_query_by_where_in
    names = ['test101', 'test107', 'test106']

    @_store.open_session do |session|
      results = session.advanced.raw_query(
        "FROM Products "\
        "WHERE name IN ($names)", {
        :names => names
      })
      .wait_for_non_stale_results
      .all

      assert_equal(results.size, 4)

      results.each do |result|
        assert(names.any? {|name| result.name == name})
      end
    end
  end

  def test_should_query_by_starts_with
    @_store.open_session do |session|
      results = session.advanced.raw_query(
        "FROM Products "\
        "WHERE startsWith(name, $name)", {
        :name => 'n'
      })
      .wait_for_non_stale_results
      .all

      assert_equal(results.size, 1)
      assert_equal(results.first.name, 'new_testing')
    end
  end

  def test_should_query_by_ends_with
    @_store.open_session do |session|
      results = session.advanced.raw_query(
        "FROM Products "\
        "WHERE endsWith(name, $name)", {
        :name => '7'
      })
      .wait_for_non_stale_results
      .all

      assert_equal(results.size, 2)
      assert(results.all? {|result| result.name = 'test107'})
    end
  end

  def test_should_query_by_between
    @_store.open_session do |session|
      results = session.advanced.raw_query(
        "FROM Products "\
        "WHERE uid BETWEEN $from AND $to", {
        :from => 2,
        :to => 4
      })
      .wait_for_non_stale_results
      .all

      assert_equal(results.size, 3)
      assert(results.all? {|result| (2..4).to_a.include?(result.uid) })
    end
  end

  def test_should_query_by_exists
    @_store.open_session do |session|
      results = session.advanced.raw_query(
        "FROM @all_docs "\
        "WHERE exists(ordering)"
      )
      .wait_for_non_stale_results
      .all

      assert(results.all? {|result| result.instance_variable_defined?('@ordering') })
    end
  end

  def test_should_fail_query_by_unexisting_index
    @_store.open_session do |session|
      assert_raises(RavenDB::IndexDoesNotExistException) do
        session.advanced
          .raw_query("FROM INDEX 's'")
          .wait_for_non_stale_results
          .all
      end
    end
  end

  def test_should_fail_query_with_invalid_rql
    @_store.open_session do |session|
      assert_raises(RavenDB::ParseException) do
        session.advanced
            .raw_query("FROM Products WHERE")
            .wait_for_non_stale_results
            .all
      end
    end
  end

  def test_should_query_by_index
    uids = [4, 6, 90]

    @_store.open_session do |session|
      results = session.advanced.raw_query(
        "FROM INDEX 'Testing_Sort' "\
        "WHERE uid IN ($uids)", {
        :uids => uids
      })
      .wait_for_non_stale_results
      .all

      assert_equal(results.size, 3)

      results.each do |result|
        assert(uids.any? {|uid| result.uid == uid})
      end
    end
  end

  def test_should_query_with_ordering
    @_store.open_session do |session|
      results = session.advanced.raw_query(
        "FROM @all_docs "\
        "WHERE exists(ordering) "\
        "ORDER BY ordering"
      )
      .wait_for_non_stale_results
      .all

      assert_equal(results.first.ordering, 'a')
    end
  end

  def test_should_query_with_descending_ordering
    @_store.open_session do |session|
      results = session.advanced.raw_query(
        "FROM @all_docs "\
        "WHERE exists(ordering) "\
        "ORDER BY ordering DESC"
      )
      .wait_for_non_stale_results
      .all

      assert_equal(results.first.ordering, 'd')
    end
  end

  def test_should_query_with_includes
    @_store.open_session do |session|
      session.advanced.raw_query(
        "FROM Orders "\
        "WHERE uid = $uid "\
        "INCLUDE product_id", {
        :uid => 92
      })
      .wait_for_non_stale_results
      .all

      session.load('Products/108')

      assert_equal(session.number_of_requests_in_session, 1)
    end
  end

  def test_should_query_with_nested_objects
    @_store.open_session do |session|
      results = session.advanced.raw_query(
        "FROM Companies "\
        "WHERE name = $name ", {
        :name => 'withNesting'
      })
      .wait_for_non_stale_results
      .all

      assert(results.first.product.is_a?(Product))
      assert(results.first.is_a?(Company))
    end
  end

  def test_should_paginate
    expected_uids = [[2,3],[4,5],[6,90],[95]]
    page_size = 2
    total_pages = nil

    @_store.open_session do |session|
      total_count = session.advanced.raw_query("FROM Products WHERE exists(uid)")
        .wait_for_non_stale_results.count

      total_pages = (total_count.to_f / page_size).ceil

      assert_equal(total_pages, 4)
      assert_equal(total_count, 7)
    end

    (1..total_pages).to_a do |page|
      @_store.open_session do |session|
        products = session.advanced.raw_query("FROM Products WHERE exists(uid) ORDER BY uid")
          .wait_for_non_stale_results
          .skip((page - 1) * page_size)
          .take(page_size)
          .all

        assert(products.size <= page_size)
        products.each_index {|index| assert_equal(products[index].uid, expected_uids[page - 1][index])}
      end
    end
  end

  #TODO: resolve issue with converting projections objects to docs
  # def test_should_query_select_fields
  #   @_store.open_session do |session|
  #     results = session.advanced.raw_query(
  #       "FROM Products "\
  #       "WHERE exact(uid BETWEEN $from AND $to)"\
  #       "SELECT doc_id", {
  #       :from => 2,
  #       :to => 4
  #     })
  #     .wait_for_non_stale_results
  #     .all
  #
  #     assert(results.all?{|result| result.instance_variable_defined?('@doc_id')})
  #   end
  # end

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