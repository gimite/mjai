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
      assert_operator(
          scene.get_tehais(Pai.parse_pais("123m 789m 34p 78p SS N")).progress_prob,
          :>,
          scene.get_tehais(Pai.parse_pais("123m 789m 13p 78p SS N")).progress_prob)
      assert_operator(
          scene.get_tehais(Pai.parse_pais("123m 789m 34p 78p SS N")).hora_prob,
          :>,
          scene.get_tehais(Pai.parse_pais("123m 789m 13p 78p SS N")).hora_prob)
      
      scene = estimator.get_scene({
          :visible_set => Hash.new(0),
          :num_remain_turns => 16,
          :current_shanten => 2,
      })
      assert_in_delta(
          scene.get_tehais(Pai.parse_pais("112p 77p 355s 789s PP")).progress_prob,
          scene.get_tehais(Pai.parse_pais("112p 77p 355s PP")).progress_prob)
      
    end
    
end
