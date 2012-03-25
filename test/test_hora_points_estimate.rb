$LOAD_PATH.unshift(File.dirname(__FILE__) + "/../lib")

require "test/unit"

require "mjai/hora_points_estimate"
require "mjai/furo"


class TC_HoraPointsEstimate < Test::Unit::TestCase
    
    include(Mjai)
    
    def setup()
      @default_context = Context.new({
          :oya => false,
          :bakaze => Pai.new("E"),
          :jikaze => Pai.new("S"),
          :doras => Pai.parse_pais("2m"),
      })
    end
    
    def test_all()
      
      est = get_estimate("22m 678m 234p 56s E FF")
      assert_in_delta(1.0, est.yaku_pfans[:reach].expected)
      assert_in_delta(0.0, est.yaku_pfans[:pinfu].expected)
      assert_in_delta(0.0, est.yaku_pfans[:tanyaochu].expected)
      assert_in_delta(0.5, est.yaku_pfans[:fanpai].expected)
      assert_in_delta(2.5, est.yaku_pfans[:dora].expected)
      assert_in_delta(0.0, est.yaku_pfans[:akadora].expected)
      assert_in_delta(8137.5, est.average_points)
      
      est = get_estimate("23m 67m 234p 678p 5s5sr E")
      assert_in_delta(1.0, est.yaku_pfans[:reach].expected)
      assert_in_delta(1.0, est.yaku_pfans[:pinfu].expected)
      assert_in_delta(0.5, est.yaku_pfans[:tanyaochu].expected)
      assert_in_delta(0.0, est.yaku_pfans[:fanpai].expected)
      assert_in_delta(1.0, est.yaku_pfans[:dora].expected)
      assert_in_delta(1.0, est.yaku_pfans[:akadora].expected)
      
      est = get_estimate("13m 67m 234p 678p 55s E")
      assert_in_delta(0.5, est.yaku_pfans[:pinfu].expected)
      
      est = get_estimate("23m 67m 234p 55s E",
          [Furo.new({:type => :pon, :consumed => Pai.parse_pais("SS"), :taken => Pai.new("S")})])
      assert_in_delta(0.0, est.yaku_pfans[:reach].expected)
      assert_in_delta(0.0, est.yaku_pfans[:pinfu].expected)
      assert_in_delta(0.0, est.yaku_pfans[:tanyaochu].expected)
      assert_in_delta(1.0, est.yaku_pfans[:fanpai].expected)
      assert_in_delta(1.0, est.yaku_pfans[:dora].expected)
      assert_in_delta(0.0, est.yaku_pfans[:akadora].expected)
      
      est = get_estimate("23m 67m 234p 55s E",
          [Furo.new({:type => :pon, :consumed => Pai.parse_pais("99m"), :taken => Pai.new("9m")})])
      assert_in_delta(0.0, est.average_points)
      
      est = get_estimate("12m 456m 789m E FF PP")
      assert_in_delta(3.0, est.yaku_pfans[:iso].expected)
      
      est = get_estimate("12m 456m 789m FF",
          [Furo.new({:type => :pon, :consumed => Pai.parse_pais("99m"), :taken => Pai.new("9m")})])
      assert_in_delta(2.0, est.yaku_pfans[:iso].expected)
      
      est = get_estimate("11m 33m 55m 777m 999m E")
      assert_in_delta(6.0, est.yaku_pfans[:iso].expected)
      
      est = get_estimate("11m 33m 55m 777m E",
          [Furo.new({:type => :pon, :consumed => Pai.parse_pais("99m"), :taken => Pai.new("9m")})])
      assert_in_delta(5.0, est.yaku_pfans[:iso].expected)
      
    end
    
    def get_estimate(pais_str, furos = [])
      return HoraPointsEstimate.new({
          :shanten_analysis => ShantenAnalysis.new(Pai.parse_pais(pais_str), nil, [:normal]),
          :furos => furos,
          :context => @default_context,
      })
    end
    
end
