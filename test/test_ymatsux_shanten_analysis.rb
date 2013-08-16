$LOAD_PATH.unshift(File.dirname(__FILE__) + "/../lib")

require "pp"
require "test/unit"

require "mjai/ymatsux_shanten_analysis"
require "mjai/pai"


class TC_YmatsuxShantenAnalysis < Test::Unit::TestCase
    
    include(Mjai)
    
    def test_hoge()
      assert_equal(
          [
              1, 1, 1, 0, 0, 0, 0, 0, 0,
              0, 0, 0, 1, 1, 1, 0, 0, 0,
              0, 0, 0, 0, 0, 0, 0, 0, 0,
              1, 1, 1, 0, 1, 1, 0,
          ],
          YmatsuxShantenAnalysis.pais_to_count_vector(Pai.parse_pais("123m456pESWPF")))
    end

    def test_shanten()
      assert_equal(-1, YmatsuxShantenAnalysis.new(Pai.parse_pais("123m456p789sNNNFF")).shanten)
      assert_equal(-1, YmatsuxShantenAnalysis.new(Pai.parse_pais("123m456p789sNNNFF")).shanten)
      assert_equal(0, YmatsuxShantenAnalysis.new(Pai.parse_pais("123m456p789sNNNF")).shanten)
      assert_equal(1, YmatsuxShantenAnalysis.new(Pai.parse_pais("12m45p789sNNNFFPC")).shanten)
    end
    
end
