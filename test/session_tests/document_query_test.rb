require 'date'
require 'ravendb'
require 'spec_helper'

class DocumentQueryTest < TestBase
  def setup
    super

    @lastfm = LastFmAnalyzed.new(@_store, self)

    @lastfm.execute
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
      results = session.query({
        :collection => 'Products'
      })
      .where_equals('name', 'test101')
      .wait_for_non_stale_results
      .all

      assert_equal(results.size, 1)
      assert_equal(results.first.name, 'test101')
    end
  end

  def test_should_query_by_few_conditions_joined_by_or
    @_store.open_session do |session|
      results = session
        .query({
          :collection => 'Products'
        })
        .where_equals('name', 'test101')
        .where_equals('uid', 4)
        .wait_for_non_stale_results
        .all

      assert_equal(results.size, 2)
      assert(results.first.name.include?('test101') || results.last.name.include?('test101'))
      assert(results.first.uid == 2 || results.last.uid == 2)
    end
  end

  def test_should_query_by_few_conditions_joined_by_and
    @_store.open_session do |session|
      results = session
        .query({
          :collection => 'Products'
        })
        .using_default_operator(RavenDB::QueryOperator::And)
        .where_equals('name', 'test107')
        .where_equals('uid', 5)
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
      results = session
        .query({
          :collection => 'Products'
        })
        .where_in('name', names)
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
      results = session
        .query({
           :collection => 'Products'
        })
        .where_starts_with('name', 'n')
        .wait_for_non_stale_results
        .all

      assert_equal(results.size, 1)
      assert_equal(results.first.name, 'new_testing')
    end
  end

  def test_should_query_by_ends_with
    @_store.open_session do |session|
      results = session
        .query({
           :collection => 'Products'
        })
        .where_ends_with('name', '7')
        .wait_for_non_stale_results
        .all

      assert_equal(results.size, 2)
      assert(results.all? {|result| result.name = 'test107'})
    end
  end

  def test_should_query_by_between
    @_store.open_session do |session|
      results = session
        .query({
          :collection => 'Products'
        })
        .where_between('uid', 2, 4)
        .wait_for_non_stale_results
        .all

      assert_equal(results.size, 3)
      assert(results.all? {|result| (2..4).to_a.include?(result.uid) })
    end
  end

  def test_should_query_by_exists
    @_store.open_session do |session|
      results = session
        .query
        .where_exists('ordering')
        .wait_for_non_stale_results
        .all

      assert(results.all? {|result| result.instance_variable_defined?('@ordering') })
    end
  end

  def test_should_fail_query_by_unexisting_index
    @_store.open_session do |session|
      assert_raises(RavenDB::IndexDoesNotExistException) do
        session
          .query({
             :index_name => 's'
           })
          .wait_for_non_stale_results
          .all
      end
    end
  end

  def test_should_query_by_index
    uids = [4, 6, 90]

    @_store.open_session do |session|
      session
        .query({
          :index_name => 'Testing_Sort'
        })
        .where_in('uid', uids)
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
      results = session
        .query
        .where_exists('ordering')
        .order_by('ordering')
        .wait_for_non_stale_results
        .all

      assert_equal(results.first.ordering, 'a')
    end
  end

  def test_should_query_with_descending_ordering
    @_store.open_session do |session|
      results = session
        .query
        .where_exists('ordering')
        .order_by_descending('ordering')
        .wait_for_non_stale_results
        .all

      assert_equal(results.first.ordering, 'd')
    end
  end

  def test_should_query_with_includes
    @_store.open_session do |session|
      session
        .query({
          :collection => 'Orders'
        })
        .where_equals('uid', 92)
        .include('product_id')
        .wait_for_non_stale_results
        .all

      session.load('Products/108')
      assert_equal(session.number_of_requests_in_session, 1)
    end
  end

  def test_should_query_with_nested_objects
    @_store.open_session do |session|
      results = session
        .query({
           :collection => 'Companies'
        })
        .where_equals('name', 'withNesting')
        .wait_for_non_stale_results
        .all

      assert(results.first.is_a?(Company))
      assert(results.first.product.is_a?(Product))
    end
  end

  def test_should_paginate
    expected_uids = [[2,3],[4,5],[6,90],[95]]
    page_size = 2
    total_pages = nil

    @_store.open_session do |session|
      total_count = session
        .query({
          :collection => 'Products'
        })
        .where_exists('uid')
        .wait_for_non_stale_results
        .count

      total_pages = (total_count.to_f / page_size).ceil

      assert_equal(total_pages, 4)
      assert_equal(total_count, 7)
    end

    (1..total_pages).to_a do |page|
      @_store.open_session do |session|
        products = session
          .query({
            :collection => 'Products'
          })
          .where_exists('uid')
          .order_by('uid')
          .wait_for_non_stale_results
          .skip((page - 1) * page_size)
          .take(page_size)
          .all

        assert(products.size <= page_size)
        products.each_index {|index| assert_equal(products[index].uid, expected_uids[page - 1][index])}
      end
    end
  end

  def test_should_query_select_fields
    @_store.open_session do |session|
      results = session
        .query({
          :index_name => 'Testing_Sort',
          :document_type => Product
        })
        .select_fields(['doc_id'])
        .where_between('uid', 2, 4, true)
        .wait_for_non_stale_results
        .all

      assert(results.all?{|result| result.instance_variable_defined?('@doc_id')})
    end
  end

  def test_should_search_by_single_keyword
    @_store.open_session do |session|
      results = session
        .query({
          :index_name => LastFmAnalyzed.name,
          :document_type => LastFm
        })
        .search('query', 'Me')
        .wait_for_non_stale_results
        .all

      assert_equal(results.size, 2)
      results.each{|last_fm| @lastfm.check_fulltext_search_result(last_fm, ['Me'])}
    end
  end

  def test_should_search_by_two_keywords
    @_store.open_session do |session|
      results = session
        .query({
          :index_name => LastFmAnalyzed.name,
          :document_type => LastFm
        })
        .search('query', 'Me Bobo')
        .wait_for_non_stale_results
        .all

      assert_equal(results.size, 3)

      results.each do |last_fm|
        @lastfm.check_fulltext_search_result(last_fm, ['Me', 'Bobo'])
      end
    end
  end

  def test_should_search_full_text_with_boost
    @_store.open_session do |session|
      results = session
        .query({
          :index_name => LastFmAnalyzed.name,
          :document_type => LastFm
        })
        .search('query', 'Me')
        .boost(10)
        .search('query', 'Bobo')
        .boost(2)
        .wait_for_non_stale_results
        .all

      assert_equal(results.size, 3)
      assert_equal(results.last.title, 'Spanish Grease')

      results.each do |last_fm|
        @lastfm.check_fulltext_search_result(last_fm, ['Me', 'Bobo'])
      end
    end
  end

  protected

end