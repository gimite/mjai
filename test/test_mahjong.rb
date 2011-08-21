require "test/unit"
require "./mahjong"
require "./tenhou_mjlog_loader"


class TC_Mahjong < Test::Unit::TestCase
    
    def test_shanten_counter()
      assert_equal(ShantenCounter.count(Pai.parse_pais("123m456p789sNNNFF")), -1)
      assert_equal(ShantenCounter.count(Pai.parse_pais("123m456p789sNNNFP")), 0)
      assert_equal(ShantenCounter.count(Pai.parse_pais("12m456p789sNNNFFP")), 0)
      assert_equal(ShantenCounter.count(Pai.parse_pais("12m45p789sNNNFFPC")), 1)
      assert_equal(ShantenCounter.count(Pai.parse_pais("1112345678999mN")), 0)
      assert_equal(ShantenCounter.count(Pai.parse_pais("114477m114477sCC")), -1)
      assert_equal(ShantenCounter.count(Pai.parse_pais("114477m114477sPC")), 0)
      assert_equal(ShantenCounter.count(Pai.parse_pais("114477m114477sP")), 0)
    end
    
    def test_tenhou_mjlog_loader()
      assert_equal(parse_furo(17463), [:chi, 3, "8m", "6m 7m"])
      assert_equal(parse_furo(26633), [:pon, 1, "9p", "9p 9p"])
      assert_equal(parse_furo(45674), [:pon, 2, "W", "W W"])
      assert_equal(parse_furo(33795), [:daiminkan, 3, "C", "C C C"])
    end
    
    def parse_furo(fid)
      parser = TenhouMjlogLoader::FuroParser.new(fid)
      return [
        parser.type, parser.target_dir,
        parser.taken.to_s(), parser.consumed.join(" "),
      ]
    end
    
end
