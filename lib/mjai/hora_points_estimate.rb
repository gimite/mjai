$LOAD_PATH.unshift("./lib")  # kari
require "set"
require "pp"

require "mjai/pai"
require "mjai/shanten_analysis"
require "mjai/situation"
require "mjai/hora"


module Mjai
    
    class HoraPointsEstimate
        
        # TODO Calculate with statistics.
        TSUMO_HORA_PROB = 0.5
        
        # TODO Add ippatsu, uradora
        SUPPORTED_YAKUS = [:reach, :tanyaochu, :pinfu, :fanpai, :dora, :akadora]
        
        class ProbablisticFan
            
            def self.prob_average(pfans)
              return prob_weighted_average(pfans.map(){ |pf| [pf, 1.0 / pfans.size] })
            end
            
            def self.prob_weighted_average(weighted_pfans)
              new_probs = Hash.new(0.0)
              for pfan, weight in weighted_pfans
                for fan, prob in pfan.probs
                  new_probs[fan] += prob * weight
                end
              end
              return ProbablisticFan.new(new_probs)
            end
            
            def initialize(arg)
              if arg.is_a?(Integer)
                @probs = {arg => 1.0}
              else
                @probs = arg
              end
            end
            
            attr_reader(:probs)
            
            def +(other)
              return apply(:+, other)
            end
            
            def *(other)
              return apply(:*, other)
            end
            
            def apply(operator, other)
              new_probs = Hash.new(0.0)
              for f1, p1 in @probs
                for f2, p2 in other.probs
                  new_probs[f1.__send__(operator, f2)] += p1 * p2 if p1 * p2 > 0.0
                end
              end
              return ProbablisticFan.new(new_probs)
            end
            
        end
        
        class HoraCombination
            
            def initialize(used_combination, hp_est)
              @used_combination = used_combination
              @hp_est = hp_est
              @janto_candidates = HoraPointsEstimate.janto_candidates(@used_combination.janto)
              @mentsu_candidates = @used_combination.mentsus.map() do |mentsu|
                HoraPointsEstimate.complete_candidates(mentsu)
              end
            end
            
            attr_reader(:used_combination)
            attr_reader(:janto_candidates)
            attr_reader(:mentsu_candidates)
            
            def yaku_pfan(yaku)
              case yaku
                when :reach
                  return self.reach_pfan
                when :tanyaochu
                  return self.tanyaochu_pfan
                when :pinfu
                  return self.pinfu_pfan
                when :fanpai
                  return self.fanpai_pfan
                when :dora
                  return self.dora_pfan
                when :akadora
                  return self.akadora_pfan
                else
                  raise("not implemented")
              end
            end
            
            def reach_pfan
              # TODO Change if not menzen.
              return ProbablisticFan.new(1)
            end
            
            def tanyaochu_pfan
              prob = 1.0
              for cands in [@janto_candidates] + @mentsu_candidates
                prob *= get_prob(cands){ |m| !has_yaochu?(m) }
              end
              return ProbablisticFan.new({0 => 1.0 - prob, 1 => prob})
            end
            
            def pinfu_pfan
              prob = 1.0
              prob *= get_prob(@janto_candidates) do |m|
                @hp_est.situation.fanpai_fan(m.pais[0]) == 0
              end
              for cands in @mentsu_candidates
                prob *= get_prob(cands){ |m| m.type == :shuntsu }
              end
              if prob > 0.0
                incompletes = @used_combination.mentsus.select(){ |m| m.pais.size < 3 }
                ryanmen_prob =
                    incompletes.map(){ |m| get_ryanmen_prob(m) }.inject(0.0, :+) / incompletes.size
                prob *= ryanmen_prob
              end
              return ProbablisticFan.new({0 => 1.0 - prob, 1 => prob})
            end
            
            def fanpai_pfan
              pfan = ProbablisticFan.new(0)
              for cands in @mentsu_candidates
                fan1_prob = get_fanpai_prob(cands, 1)
                fan2_prob = get_fanpai_prob(cands, 2)
                pfan += ProbablisticFan.new({
                    0 => 1.0 - fan1_prob - fan2_prob,
                    1 => fan1_prob,
                    2 => fan2_prob,
                })
              end
              return pfan
            end
            
            def dora_pfan
              pfan = ProbablisticFan.new(0)
              for cands in [@janto_candidates] + @mentsu_candidates
                probs = Hash.new(0.0)
                for mentsu, prob in cands
                  probs[get_dora_fan(mentsu)] += prob
                end
                pfan += ProbablisticFan.new(probs)
              end
              return pfan
            end
            
            def akadora_pfan
              # Note that red is removed from @mentsu_candidates etc.
              red_pais = @hp_est.shanten_analysis.pais.
                  select(){ |pai| pai.red? }.
                  map(){ |pai| pai.remove_red() }
              pfan = ProbablisticFan.new(0)
              for red_pai in red_pais
                neg_prob = 1.0
                for cands in [@janto_candidates] + @mentsu_candidates
                  neg_prob *=
                      get_prob(cands){ |m| !m.pais.any?(){ |pai| red_pais.include?(pai) } }
                end
                pfan += ProbablisticFan.new({0 => neg_prob, 1 => 1.0 - neg_prob})
              end
              return pfan
            end
            
            def has_yaochu?(mentsu)
              return mentsu.pais.any?(){ |pai| pai.yaochu? }
            end
            
            def get_prob(mentsu_cands, &block)
              return mentsu_cands.select(){ |m, pr| yield(m) }.map(){ |m, pr| pr }.inject(0.0, :+)
            end
            
            def get_fanpai_prob(mentsu_cands, fan)
              return get_prob(mentsu_cands) do |m|
                m.type == :kotsu && @hp_est.situation.fanpai_fan(m.pais[0]) == fan
              end
            end
            
            def get_dora_fan(mentsu)
              fans = mentsu.pais.map() do |pai|
                @hp_est.situation.doras.count(pai.remove_red())
              end
              return fans.inject(0, :+)
            end
            
            # Assuming the mentsu becomes shuntsu in the end, returns the probability that
            # its waiting form is ryanmen.
            def get_ryanmen_prob(mentsu)
              case mentsu.type
                when :ryanmen
                  return 1.0
                when :kanta, :penta
                  return 0.0
                when :single
                  case mentsu.pais[0].number
                    when 1, 9
                      return 0.0
                    when 2, 8
                      # [3] out of [1, 3, 4]
                      return 1.0 / 3.0
                    else
                      # [2, 4] out of [1, 2, 4, 5]
                      return 0.5
                  end
                else
                  raise("should not happen: %p" % mentsu.type)
              end
            end
            
        end
        
        def initialize(shanten_analysis, situation)
          @shanten_analysis = shanten_analysis
          @situation = situation
          @hora_combinations = self.get_hora_combinations
        end
        
        attr_reader(:shanten_analysis, :hora_combinations, :situation)
        
        # key: [menzen, tsumo, pinfu]
        FU_MAP = {
            [false, false, false] => 30,
            [false, false, true] => 30,
            [false, true, false] => 30,
            [false, true, true] => 30,
            [true, false, false] => 40,
            [true, false, true] => 30,
            [true, true, false] => 30,
            [true, true, true] => 20,
        }
        
        def average_points
          yaku_pfans = self.yaku_pfans
          pfan = yaku_pfans.values.inject(ProbablisticFan.new(0), :+)
          pinfu_prob = yaku_pfans[:pinfu].probs[1]
          is_menzen = true  # TODO Change if not menzen.
          result = 0.0
          for is_tsumo in [false, true]
            for is_pinfu in [false, true]
              base_prob =
                  (is_tsumo ? TSUMO_HORA_PROB : 1.0 - TSUMO_HORA_PROB) *
                  (is_pinfu ? pinfu_prob : 1.0 - pinfu_prob)
              next if base_prob == 0.0
              fu = FU_MAP[[is_menzen, is_tsumo, is_pinfu]]
              for fan, fan_prob in pfan.probs
                fan += 1 if is_menzen && is_tsumo
                datum = Hora::PointsDatum.new(fu, fan, @situation.oya, is_tsumo ? :tsumo : :ron)
                p [is_tsumo, is_pinfu, base_prob, fan, fan_prob, fu, datum.points]
                result += datum.points * fan_prob * base_prob
              end
            end
          end
          return result
        end
        
        def yaku_pfans
          result = {}
          for yaku in SUPPORTED_YAKUS
            result[yaku] = yaku_pfan(yaku)
          end
          return result
        end
        
        def yaku_pfan(yaku)
          pfans = @hora_combinations.map(){ |hc| hc.yaku_pfan(yaku) }
          return ProbablisticFan.prob_average(pfans)
        end
        
        def each_combination(&block)
          for combination in @shanten_analysis.detailed_combinations
            #p combination
            if combination.janto
              yield(combination)
            else
              num_groups = combination.mentsus.select(){ |m| m.pais.size >= 2 }.size
              combination.mentsus.each_with_index() do |mentsu, i|
                if mentsu.pais.size == 1
                  maybe_janto = true
                elsif [:ryanmen, :kanchan, :penta].include?(mentsu.type) && num_groups >= 5
                  maybe_janto = true
                else
                  maybe_janto = false
                end
                if maybe_janto
                  remains = combination.mentsus.dup()
                  remains.delete_at(i)
                  yield(ShantenAnalysis::DetailedCombination.new(mentsu, remains))
                end
              end
            end
          end
        end
        
        def used_combinations
          result = Set.new()
          each_combination() do |combination|
            completes = combination.mentsus.select(){ |m| m.pais.size >= 3 }.sort()
            tatsus = combination.mentsus.select(){ |m| m.pais.size == 2 }.sort()
            singles = combination.mentsus.select(){ |m| m.pais.size == 1 }.sort()
            #pp [:used_exp_combi, combination]
            #p [:completes, completes.size]
            mentsu_combinations = []
            if completes.size >= 4
              mentsu_combinations.push(completes)
            elsif completes.size + tatsus.size >= 4
              tatsus.combination(4 - completes.size) do |t_tatsus|
                mentsu_combinations.push(completes + t_tatsus)
              end
            else
              singles.combination(4 - completes.size - tatsus.size) do |t_singles|
                mentsu_combinations.push(completes + tatsus + t_singles)
              end
            end
            #p [:mentsu_combinations, mentsu_combinations]
            for mentsus in mentsu_combinations
              result.add(ShantenAnalysis::DetailedCombination.new(combination.janto, mentsus))
            end
          end
          return result
        end
        
        def get_hora_combinations()
          self.used_combinations.map(){ |c| HoraCombination.new(c, self) }
        end
        
        def self.complete_candidates(mentsu)
          if [:shuntsu, :kotsu, :kantsu].include?(mentsu.type)
            return [[mentsu, 1.0]]
          end
          rcands = []
          case mentsu.type
            when :ryanmen, :penta
              rcands += [[:shuntsu, [-1, 0, 1]], [:shuntsu, [0, 1, 2]]]
            when :kanta
              rcands += [[:shuntsu, [0, 1, 2]]]
            when :toitsu
              rcands += [[:kotsu, [0, 0, 0]]]
            when :single
              rcands += [
                  [:shuntsu, [-2, -1, 0]],
                  [:shuntsu, [-1, 0, 1]],
                  [:shuntsu, [0, 1, 2]],
                  [:kotsu, [0, 0, 0]]
              ]
            else
              raise("should not happen: %p" % mentsu.type)
          end
          cands = []
          first_pai = mentsu.pais[0]
          for type, rnums in rcands
            in_range = rnums.all?() do |rn|
              (rn == 0 || first_pai.type != "t") && (1..9).include?(first_pai.number + rn)
            end
            if in_range
              cands.push(Mentsu.new({
                  :type => type,
                  :pais => rnums.map(){ |rn| Pai.new(first_pai.type, first_pai.number + rn) },
              }))
            end
          end
          return cands.map(){ |m| [m, 1.0 / cands.size] }
        end
        
        def self.janto_candidates(mentsu)
          pai_cands = mentsu.pais.uniq()
          return pai_cands.map() do |pai|
            [Mentsu.new({:type => :toitsu, :pais => [pai, pai]}), 1.0 / pai_cands.size]
          end
        end
        
    end
    
end


include(Mjai)

@situation = Situation.new({
    :oya => false,
    :bakaze => Pai.new("E"),
    :jikaze => Pai.new("S"),
    :doras => Pai.parse_pais("2m"),
})

def dump(pais_str, verbose = false)
  p pais_str
  hp_est = HoraPointsEstimate.new(
      ShantenAnalysis.new(Pai.parse_pais(pais_str), nil, [:normal]),
      @situation)
  if verbose
    p [:shanten, hp_est.shanten_analysis.shanten]
    p :orig
    for combi in hp_est.shanten_analysis.combinations
      pp combi
    end
    p :detailed
    for combi in hp_est.shanten_analysis.detailed_combinations
      pp combi
    end
    p :expanded
    hp_est.each_combination() do |combi|
      pp combi
    end
    p [:used, hp_est.used_combinations.size]
    for combi in hp_est.used_combinations
      pp combi
    end
    p [:hora, hp_est.hora_combinations.size]
    for hcombi in hp_est.hora_combinations
      p [:current_janto, hcombi.used_combination.janto.pais.join(" ")]
      for mentsu in hcombi.used_combination.mentsus
        p [:current_mentsu, mentsu.pais.join(" ")]
      end
      pp hcombi
    end
  end
  for yaku, pfan in hp_est.yaku_pfans
    p [yaku, pfan.probs.reject(){ |k, v| k == 0 }.sort()] if pfan.probs[0] < 0.999
  end
  p [:avg_pts, hp_est.average_points]
end

case ARGV.shift()
  when "test"
    dump("22m678m234p56sEFF")
    dump("23m67m234p55sEFFF")
    dump("67m234p55sEFFFPP")
    dump("23m67m234678p55sE")
    dump("23m67m234678p5s5srE")
    dump("13m67m234678p55sE")
    dump("123789m1236p5sNN")
    dump("123789m45p5pr6pWNN")
  when "random"
    pais = (0...4).map() do |i|
      ["m", "p", "s"].map(){ |t| (1..9).map(){ |n| Pai.new(t, n, n == 5 && i == 0) } } +
          (1..7).map(){ |n| Pai.new("t", n) }
    end
    all_pais = pais.flatten().sort()
    while true
      pais = all_pais.sample(13).sort()
      start_time = Time.now
      dump(pais.join(" "))
      p [:time, Time.now - start_time]
      gets()
    end
  else
    raise("hoge")
end

#hp_est = HoraPointsEstimate.new(
#    ShantenAnalysis.new(Pai.parse_pais("23m67m34888p5589s"), nil, [:normal]))
#hp_est = HoraPointsEstimate.new(
#    ShantenAnalysis.new(Pai.parse_pais("22m67m234678p55sE"), nil, [:normal]))
#pp HoraPointsEstimate.complete_candidates(
#    Mentsu.new({:type => :ryanmen, :pais => Pai.parse_pais("23m")}))
#pp HoraPointsEstimate.complete_candidates(
#    Mentsu.new({:type => :penta, :pais => Pai.parse_pais("12m")}))
