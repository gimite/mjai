$LOAD_PATH.unshift(File.dirname(__FILE__) + "/../lib")

require "test/unit"

require "mjai/pai"


class TC_Pai < Test::Unit::TestCase
    
    include(Mjai)
    
    def test_dora()
      assert_equal(Pai.new("2m"), Pai.new("1m").succ)
      assert_equal(Pai.new("3m"), Pai.new("2m").succ)
      assert_equal(Pai.new("4m"), Pai.new("3m").succ)
      assert_equal(Pai.new("5m"), Pai.new("4m").succ)
      assert_equal(Pai.new("6m"), Pai.new("5m").succ)
      assert_equal(Pai.new("7m"), Pai.new("6m").succ)
      assert_equal(Pai.new("8m"), Pai.new("7m").succ)
      assert_equal(Pai.new("9m"), Pai.new("8m").succ)
      assert_equal(Pai.new("1m"), Pai.new("9m").succ)
      assert_equal(Pai.new("S"), Pai.new("E").succ)
      assert_equal(Pai.new("W"), Pai.new("S").succ)
      assert_equal(Pai.new("N"), Pai.new("W").succ)
      assert_equal(Pai.new("E"), Pai.new("N").succ)
      assert_equal(Pai.new("F"), Pai.new("P").succ)
      assert_equal(Pai.new("C"), Pai.new("F").succ)
      assert_equal(Pai.new("P"), Pai.new("C").succ)
    end
    
end
