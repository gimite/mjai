$LOAD_PATH.unshift(File.dirname(__FILE__) + "/../lib")

require "test/unit"

require "mjai/hora_probability_estimator"


class TC_HoraProbabilityEstimator < Test::Unit::TestCase
    
    include(Mjai)
    
    def test_progress_prob()
      
      estimator = HoraProbabilityEstimator.new("data/hora_prob.marshal")
      scene = estimator.get_scene({
          :visible_set => Hash.new(0),
          :num_remain_turns => 16,
          :current_shanten => 1,
      })
      p scene.get_tehais(Pai.parse_pais("123789m3478pSSN")).progress_prob
      p scene.get_tehais(Pai.parse_pais("123789m1378pSSN")).progress_prob
      p scene.get_tehais(Pai.parse_pais("123789m3478pSSN")).hora_prob
      p scene.get_tehais(Pai.parse_pais("123789m1378pSSN")).hora_prob
      
    end
    
end
