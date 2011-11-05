require "test/unit"
require "./statistical_player"


class TC_StatisticalPlayer < Test::Unit::TestCase
    
    def test_num_mentsus()
      
      player = StatisticalPlayer.new()
      assert_equal([1, 4], player.num_mentsus(Pai.parse_pais("123789m111789sEE")))
      assert_equal([0, 4], player.num_mentsus(Pai.parse_pais("123789m111789sES")))
      assert_equal([0, 3], player.num_mentsus(Pai.parse_pais("12789m111789sESF")))
      assert_equal([0, 4], player.num_mentsus(Pai.parse_pais("112233m111789sES")))
      assert_equal([0, 4], player.num_mentsus(Pai.parse_pais("122334m111789sES")))
      assert_equal([1, 4], player.num_mentsus(Pai.parse_pais("111444777m111sEE")))
      assert_equal([1, 3], player.num_mentsus(Pai.parse_pais("11123777m111sEES")))
      assert_equal([1, 2], player.num_mentsus(Pai.parse_pais("123789m11sESWPFC")))
      assert_equal([1, 4], player.num_mentsus(Pai.parse_pais("123456789m111sCC")))
      assert_equal([1, 4], player.num_mentsus(Pai.parse_pais("11112345678999m")))
      assert_equal([0, 4], player.num_mentsus(Pai.parse_pais("1123789m111789sE")))
      
    end
    
end
