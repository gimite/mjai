$LOAD_PATH.unshift(File.dirname(__FILE__) + "/../lib")

require "test/unit"

require "mjai/shanten_analysis"
require "mjai/pai"


class TC_ShantenAnalysis < Test::Unit::TestCase
    
    include(Mjai)
    
    def test_dora()
      
      assert_equal(Pai.new("1m").succ, Pai.new("2m"))
      assert_equal(Pai.new("2m").succ, Pai.new("3m"))
      assert_equal(Pai.new("3m").succ, Pai.new("4m"))
      assert_equal(Pai.new("4m").succ, Pai.new("5m"))
      assert_equal(Pai.new("5m").succ, Pai.new("6m"))
      assert_equal(Pai.new("6m").succ, Pai.new("7m"))
      assert_equal(Pai.new("7m").succ, Pai.new("8m"))
      assert_equal(Pai.new("8m").succ, Pai.new("9m"))
      assert_equal(Pai.new("9m").succ, Pai.new("1m"))
      assert_equal(Pai.new("E").succ, Pai.new("S"))
      assert_equal(Pai.new("S").succ, Pai.new("W"))
      assert_equal(Pai.new("W").succ, Pai.new("N"))
      assert_equal(Pai.new("N").succ, Pai.new("E"))
      assert_equal(Pai.new("P").succ, Pai.new("F"))
      assert_equal(Pai.new("F").succ, Pai.new("C"))
      assert_equal(Pai.new("C").succ, Pai.new("P"))
      
    end
    
end
