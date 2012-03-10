$LOAD_PATH.unshift(File.dirname(__FILE__) + "/../lib")

require "test/unit"

require "mjai/tenpai_analysis"


class TC_TenpaiAnalysis < Test::Unit::TestCase
    
    include(Mjai)
    
    def test_tenpai()
      
      assert(TenpaiAnalysis.new(Pai.parse_pais("123m456p789sNNNF")).tenpai?)
      assert(TenpaiAnalysis.new(Pai.parse_pais("123m456p789sNNNFP")).tenpai?)
      assert(TenpaiAnalysis.new(Pai.parse_pais("12m456p789sNNNFFP")).tenpai?)
      assert(TenpaiAnalysis.new(Pai.parse_pais("1112345678999mN")).tenpai?)
      assert(TenpaiAnalysis.new(Pai.parse_pais("114477m114477sPC")).tenpai?)
      assert(TenpaiAnalysis.new(Pai.parse_pais("114477m114477sP")).tenpai?)
      assert(TenpaiAnalysis.new(Pai.parse_pais("19m19s19pESWNPFC")).tenpai?)
      assert(TenpaiAnalysis.new(Pai.parse_pais("19m19s19pESWNPPF")).tenpai?)
      assert(TenpaiAnalysis.new(Pai.parse_pais("123m456p1234789s")).tenpai?)
      
      assert(!TenpaiAnalysis.new(Pai.parse_pais("12m45p789sNNNFFPC")).tenpai?)
      
    end
    
    def test_waited_pais()
      assert_equal("F",
          TenpaiAnalysis.new(Pai.parse_pais("123m456p789sNNNF")).waited_pais.join(" "))
      assert_equal("N F",
          TenpaiAnalysis.new(Pai.parse_pais("123m456p789sNNFF")).waited_pais.join(" "))
      assert_equal("3s",
          TenpaiAnalysis.new(Pai.parse_pais("123m456p12789sFF")).waited_pais.join(" "))
      assert_equal("1s 4s",
          TenpaiAnalysis.new(Pai.parse_pais("123m456p23789sFF")).waited_pais.join(" "))
      assert_equal("3s",
          TenpaiAnalysis.new(Pai.parse_pais("123m456p24789sFF")).waited_pais.join(" "))
      assert_equal("1s 4s 7s",
          TenpaiAnalysis.new(Pai.parse_pais("123m456p23456sFF")).waited_pais.join(" "))
      assert_equal("1s 4s",
          TenpaiAnalysis.new(Pai.parse_pais("123m456p1234789s")).waited_pais.join(" "))
      assert_equal("1m 2m 3m 4m 5m 6m 7m 8m 9m",
          TenpaiAnalysis.new(Pai.parse_pais("1112345678999m")).waited_pais.join(" "))
      assert_equal("P",
          TenpaiAnalysis.new(Pai.parse_pais("114477m114477sP")).waited_pais.join(" "))
      assert_equal("1m 9m 1p 9p 1s 9s E S W N P F C",
          TenpaiAnalysis.new(Pai.parse_pais("19m19s19pESWNPFC")).waited_pais.join(" "))
      assert_equal("C",
          TenpaiAnalysis.new(Pai.parse_pais("19m19s19pESWNPPF")).waited_pais.join(" "))
    end
    
end
