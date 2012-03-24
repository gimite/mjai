$LOAD_PATH.unshift(File.dirname(__FILE__) + "/../lib")

require "test/unit"

require "mjai/statistical_player"
require "mjai/context"


class TC_StatisticalPlayer < Test::Unit::TestCase
    
    include(Mjai)
    
    def setup()
      @hora_prob_estimator = HoraProbabilityEstimator.new("data/hora_prob.marshal")
      @default_context = Context.new({
          :oya => false,
          :bakaze => Pai.new("E"),
          :jikaze => Pai.new("S"),
          :doras => Pai.parse_pais("3m"),
      })
    end
    
    def test_dahai_decision()
      decision = get_decision(Pai.parse_pais("123789m134788pSS"))
      #decision = get_decision(Pai.parse_pais("23789m23789p23sNN"))
      #34 788 SS -> 34_ 78_ SS, 34_ 888 SS, 34_ 88 SSS
      #34 88 SS -> 34_ 888 SS, 34_ 88 SSS
    end
    
    def get_decision(tehais, params = {})
      default_params = {
          :visible_set => to_pai_set(tehais),
          :context => @default_context,
          :hora_prob_estimator => @hora_prob_estimator,
          :num_remain_turns => 16,
          :current_shanten_analysis => ShantenAnalysis.new(tehais, nil, [:normal]),
          :sutehai_cands => tehais,
      }
      decision = StatisticalPlayer::DahaiDecision.new(default_params.merge(params))
      p [:best_dahai, decision.best_dahai_indices.map(){ |i| tehais[i] }]
      return decision
    end
    
    def to_pai_set(pais)
      pai_set = Hash.new(0)
      for pai in pais
        pai_set[pai.remove_red()] += 1
      end
      return pai_set
    end
    
=begin
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
=end
    
end
