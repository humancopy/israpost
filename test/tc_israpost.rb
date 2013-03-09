require_relative "../post_rate.rb"
require "test/unit"

class TestClass < Test::Unit::TestCase
  
  def setup
    @r = PostRate.new()
  end
  
  def test_empty_initialize
    @r = PostRate.new()
  end
  
  def test_partial_initialize
    @r = PostRate.new(country: :jp)
    assert_kind_of(PostRate, @r)
    @r = PostRate.new(weight: 200)
    assert_kind_of(PostRate, @r)
  end
  
  def test_attributes
    @r.attributes = {country: "Mongolia", weight: '1000', parcel: true}
    assert_equal "MONGOLIA", @r.country
    assert_equal 1000, @r.weight
    assert @r.parcel
    @r.parcel=nil
    
    assert_raise(InvalidCountry) {@r.attributes = {country: "Ur of the Chaldees"} }
    assert_raise(InvalidWeight)  {@r.attributes = {weight: 0} }
    assert_raise(InvalidWeight)  {@r.attributes = {weight: -3} }
  end
  
  def test_country
    @r.country = "Japan"
    assert_equal("JAPAN", @r.country)
  end
  
  def test_cost
    @r.country = :usa
    @r.weight = 3500
    assert_equal(188.60, @r.cost)
    @r.country = :jp
    @r.weight=3000
    assert_equal(157, @r.cost)
    @r.weight=3500
    assert_equal(170.5, @r.cost)
  end
  
  def test_invalid_country
    # assert_raise( RuntimeError ) { SimpleNumber.new('a') }
  end
end