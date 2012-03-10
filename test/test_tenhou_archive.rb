$LOAD_PATH.unshift(File.dirname(__FILE__) + "/../lib")

require "test/unit"

require "mjai/tenhou_archive"


class TC_TenhouArchive < Test::Unit::TestCase
    
    include(Mjai)
    
    def test_furo_parser()
      assert_equal([:chi, 3, "8m", "6m 7m"], parse_furo(17463))
      assert_equal([:pon, 1, "9p", "9p 9p"], parse_furo(26633))
      assert_equal([:pon, 2, "W", "W W"], parse_furo(45674))
      assert_equal([:daiminkan, 3, "C", "C C C"], parse_furo(33795))
    end
    
    def parse_furo(fid)
      parser = TenhouArchive::FuroParser.new(fid)
      return [
        parser.type, parser.target_dir,
        parser.taken.to_s(), parser.consumed.join(" "),
      ]
    end
    
end
