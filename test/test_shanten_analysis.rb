$LOAD_PATH.unshift(File.dirname(__FILE__) + "/../lib")

require "test/unit"

require "mjai/shanten_analysis"
require "mjai/pai"


class TC_ShantenAnalysis < Test::Unit::TestCase
    
    include(Mjai)
    
    def test_shanten()
      
      assert_equal(-1, ShantenAnalysis.new(Pai.parse_pais("123m456p789sNNNFF"), -1).shanten)
      assert_equal(-1, ShantenAnalysis.new(Pai.parse_pais("114477m114477sCC"), -1).shanten)
      assert_equal(-1, ShantenAnalysis.new(Pai.parse_pais("19m19s19pESWNPFCC"), -1).shanten)
      
      assert_equal(-1, ShantenAnalysis.new(Pai.parse_pais("123m456p789sNNNFF")).shanten)
      assert_equal(0, ShantenAnalysis.new(Pai.parse_pais("123m456p789sNNNF")).shanten)
      assert_equal(1, ShantenAnalysis.new(Pai.parse_pais("12m45p789sNNNFFPC")).shanten)
      assert_equal(1, ShantenAnalysis.new(Pai.parse_pais("114477m11447sFP")).shanten)
      assert_equal(1, ShantenAnalysis.new(Pai.parse_pais("139m19s19pESWNPF")).shanten)
      assert_equal(1, ShantenAnalysis.new(Pai.parse_pais("139m19s19pESWNFF")).shanten)
      assert_equal(1, ShantenAnalysis.new(Pai.parse_pais("114477m1144777s")).shanten)
      assert_equal(1, ShantenAnalysis.new(Pai.parse_pais("114477m11447777s")).shanten)
      
    end
    
    def test_combinations()
      assert_equal(2, ShantenAnalysis.new(Pai.parse_pais("111222333mNNNFF")).combinations.size)
    end
    
end
