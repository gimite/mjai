require "test/unit"
require "./min_required_pais"


class TC_MinRequiredPais < Test::Unit::TestCase
    
    def to_pais_set(strs)
      return Set.new(strs.map(){ |s| Pai.parse_pais(s) })
    end
    
    def test_candidates()
      assert_equal(
          to_pais_set(["16s", "19s", "46s", "49s"]),
          MinRequiredPais.new(Pai.parse_pais("123m456p2378sWNN")).candidates)
      assert_equal(
          to_pais_set(["17s", "1sN", "47s", "4sN"]),
          MinRequiredPais.new(Pai.parse_pais("123m456p2377sWNN")).candidates)
    end
    
end
