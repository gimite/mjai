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
      #decision = get_decision(Pai.parse_pais("123m 789m 134m 788p SS"))
      #decision = get_decision(Pai.parse_pais("23789m23789p23sNN"))
      context = Context.new({
          :oya => true,
          :bakaze => Pai.new("E"),
          :jikaze => Pai.new("E"),
          :doras => Pai.parse_pais("1p"),
      })
      decision = get_decision(Pai.parse_pais("23m 67m 13p 89p 2s EE WW C"), {:context => context})
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
    
end
