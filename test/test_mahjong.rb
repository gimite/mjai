require "test/unit"
require "./mahjong"
require "./tenhou_mjlog_loader"


class TC_Mahjong < Test::Unit::TestCase
    
    def test_shanten_counter()
      assert_equal(-1, ShantenCounter.new(Pai.parse_pais("123m456p789sNNNFF")).shanten)
      assert_equal(0, ShantenCounter.new(Pai.parse_pais("123m456p789sNNNF")).shanten)
      assert_equal(0, ShantenCounter.new(Pai.parse_pais("123m456p789sNNNFP")).shanten)
      assert_equal(0, ShantenCounter.new(Pai.parse_pais("12m456p789sNNNFFP")).shanten)
      assert_equal(1, ShantenCounter.new(Pai.parse_pais("12m45p789sNNNFFPC")).shanten)
      assert_equal(0, ShantenCounter.new(Pai.parse_pais("1112345678999mN")).shanten)
      assert_equal(-1, ShantenCounter.new(Pai.parse_pais("114477m114477sCC")).shanten)
      assert_equal(0, ShantenCounter.new(Pai.parse_pais("114477m114477sPC")).shanten)
      assert_equal(0, ShantenCounter.new(Pai.parse_pais("114477m114477sP")).shanten)
      assert_equal(2, ShantenCounter.new(Pai.parse_pais("ESWN")).shanten)
      assert_equal(2, ShantenCounter.new(Pai.parse_pais("111222333mNNNFF")).combinations.size)
    end
    
    def test_waited_pais()
      assert_equal("F",
          ShantenCounter.new(Pai.parse_pais("123m456p789sNNNF")).waited_pais.join(" "))
      assert_equal("N F",
          ShantenCounter.new(Pai.parse_pais("123m456p789sNNFF")).waited_pais.join(" "))
      assert_equal("3s",
          ShantenCounter.new(Pai.parse_pais("123m456p12789sFF")).waited_pais.join(" "))
      assert_equal("1s 4s",
          ShantenCounter.new(Pai.parse_pais("123m456p23789sFF")).waited_pais.join(" "))
      assert_equal("3s",
          ShantenCounter.new(Pai.parse_pais("123m456p24789sFF")).waited_pais.join(" "))
      assert_equal("1s 4s 7s",
          ShantenCounter.new(Pai.parse_pais("123m456p23456sFF")).waited_pais.join(" "))
      assert_equal("1s 4s",
          ShantenCounter.new(Pai.parse_pais("123m456p1234789s")).waited_pais.join(" "))
      assert_equal("1m 2m 3m 4m 5m 6m 7m 8m 9m",
          ShantenCounter.new(Pai.parse_pais("1112345678999m")).waited_pais.join(" "))
      assert_equal("P",
          ShantenCounter.new(Pai.parse_pais("114477m114477sP")).waited_pais.join(" "))
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
