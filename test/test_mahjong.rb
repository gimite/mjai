require "test/unit"
require "./mahjong"
require "./tenhou_mjlog_loader"


class TC_Mahjong < Test::Unit::TestCase
    
    def test_shanten_counter()
      
      assert_equal(-1, ShantenCounter.new(Pai.parse_pais("123m456p789sNNNFF"), -1).shanten)
      assert_equal(-1, ShantenCounter.new(Pai.parse_pais("114477m114477sCC"), -1).shanten)
      assert_equal(-1, ShantenCounter.new(Pai.parse_pais("19m19s19pESWNPFCC"), -1).shanten)
      
      assert_equal(-1, ShantenCounter.new(Pai.parse_pais("123m456p789sNNNFF")).shanten)
      assert_equal(0, ShantenCounter.new(Pai.parse_pais("123m456p789sNNNF")).shanten)
      assert_equal(1, ShantenCounter.new(Pai.parse_pais("12m45p789sNNNFFPC")).shanten)
      assert_equal(1, ShantenCounter.new(Pai.parse_pais("114477m11447sFP")).shanten)
      assert_equal(1, ShantenCounter.new(Pai.parse_pais("139m19s19pESWNPF")).shanten)
      assert_equal(1, ShantenCounter.new(Pai.parse_pais("139m19s19pESWNFF")).shanten)
      assert_equal(1, ShantenCounter.new(Pai.parse_pais("114477m1144777s")).shanten)
      assert_equal(1, ShantenCounter.new(Pai.parse_pais("114477m11447777s")).shanten)
      
      assert_equal(2, ShantenCounter.new(Pai.parse_pais("111222333mNNNFF")).combinations.size)
      
    end
    
    def test_tenpai()
      
      assert(TenpaiInfo.new(Pai.parse_pais("123m456p789sNNNF")).tenpai?)
      assert(TenpaiInfo.new(Pai.parse_pais("123m456p789sNNNFP")).tenpai?)
      assert(TenpaiInfo.new(Pai.parse_pais("12m456p789sNNNFFP")).tenpai?)
      assert(TenpaiInfo.new(Pai.parse_pais("1112345678999mN")).tenpai?)
      assert(TenpaiInfo.new(Pai.parse_pais("114477m114477sPC")).tenpai?)
      assert(TenpaiInfo.new(Pai.parse_pais("114477m114477sP")).tenpai?)
      assert(TenpaiInfo.new(Pai.parse_pais("19m19s19pESWNPFC")).tenpai?)
      assert(TenpaiInfo.new(Pai.parse_pais("19m19s19pESWNPPF")).tenpai?)
      assert(TenpaiInfo.new(Pai.parse_pais("123m456p1234789s")).tenpai?)
      
      assert(!TenpaiInfo.new(Pai.parse_pais("12m45p789sNNNFFPC")).tenpai?)
      
    end
    
    def test_waited_pais()
      assert_equal("F",
          TenpaiInfo.new(Pai.parse_pais("123m456p789sNNNF")).waited_pais.join(" "))
      assert_equal("N F",
          TenpaiInfo.new(Pai.parse_pais("123m456p789sNNFF")).waited_pais.join(" "))
      assert_equal("3s",
          TenpaiInfo.new(Pai.parse_pais("123m456p12789sFF")).waited_pais.join(" "))
      assert_equal("1s 4s",
          TenpaiInfo.new(Pai.parse_pais("123m456p23789sFF")).waited_pais.join(" "))
      assert_equal("3s",
          TenpaiInfo.new(Pai.parse_pais("123m456p24789sFF")).waited_pais.join(" "))
      assert_equal("1s 4s 7s",
          TenpaiInfo.new(Pai.parse_pais("123m456p23456sFF")).waited_pais.join(" "))
      assert_equal("1s 4s",
          TenpaiInfo.new(Pai.parse_pais("123m456p1234789s")).waited_pais.join(" "))
      assert_equal("1m 2m 3m 4m 5m 6m 7m 8m 9m",
          TenpaiInfo.new(Pai.parse_pais("1112345678999m")).waited_pais.join(" "))
      assert_equal("P",
          TenpaiInfo.new(Pai.parse_pais("114477m114477sP")).waited_pais.join(" "))
      assert_equal("1m 9m 1p 9p 1s 9s E S W N P F C",
          TenpaiInfo.new(Pai.parse_pais("19m19s19pESWNPFC")).waited_pais.join(" "))
      assert_equal("C",
          TenpaiInfo.new(Pai.parse_pais("19m19s19pESWNPPF")).waited_pais.join(" "))
    end
    
    def test_tenhou_mjlog_loader()
      assert_equal([:chi, 3, "8m", "6m 7m"], parse_furo(17463))
      assert_equal([:pon, 1, "9p", "9p 9p"], parse_furo(26633))
      assert_equal([:pon, 2, "W", "W W"], parse_furo(45674))
      assert_equal([:daiminkan, 3, "C", "C C C"], parse_furo(33795))
    end
    
    def parse_furo(fid)
      parser = TenhouMjlogLoader::FuroParser.new(fid)
      return [
        parser.type, parser.target_dir,
        parser.taken.to_s(), parser.consumed.join(" "),
      ]
    end
    
end
