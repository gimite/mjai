require "mjai/pai"
require "mjai/player"
require "mjai/shanten_analysis"
require "mjai/danger_estimator"


module Mjai

    class StatisticalPlayer < Player
        
        def initialize()
          super()
          @danger_tree = DangerEstimator::DecisionTree.new("data/danger.all.tree")
        end
        
        def respond_to_action(action)
          
          if !action.actor
            
            case action.type
              when :start_kyoku
                @prereach_sutehais_map = {}
            end
            
          elsif action.actor == self
            
            case action.type
              
              when :tsumo, :chi, :pon, :reach
                
                current_shanten = ShantenAnalysis.new(self.tehais, nil, [:normal]).shanten
                if action.type == :tsumo
                  case current_shanten
                    when -1
                      return create_action({:type => :hora, :target => action.actor, :pai => action.pai})
                    when 0
                      if self.reach?
                        return create_action({:type => :dahai, :pai => action.pai})
                      elsif self.game.num_pipais >= 4
                        return create_action({:type => :reach})
                      end
                  end
                end
                p [:shanten, current_shanten]
                
                if current_shanten == 0
                  sutehai_cands = self.tehais.uniq()
                else
                  safe_probs = {}
                  for pai in self.tehais.uniq()
                    safe_probs[pai] = 1.0
                  end
                  has_reacher = false
                  for player in self.game.players
                    if player != self && player.reach?
                      p [:reacher, player, @prereach_sutehais_map[player]]
                      has_reacher = true
                      scene = DangerEstimator::Scene.new(
                          self.game, self, nil, player, @prereach_sutehais_map[player])
                      for pai in safe_probs.keys
                        if scene.anpai?(pai)
                          safe_prob = 1.0
                        else
                          safe_prob = 1.0 - @danger_tree.estimate_prob(scene, pai)
                        end
                        p [:safe_prob, pai, safe_prob]
                        safe_probs[pai] *= safe_prob
                      end
                    end
                  end
                  max_safe_prob = safe_probs.values.max
                  sutehai_cands = safe_probs.keys.select(){ |pai| safe_probs[pai] == max_safe_prob }
                end
                p [:sutehai_cands, sutehai_cands]
                
                visible = []
                visible += self.game.doras
                visible += self.tehais
                for player in self.game.players
                  visible += player.ho + player.furos.map(){ |f| f.pais }.flatten()
                end
                visible_set = to_pai_set(visible)
                
                scores = {}
                for pai in sutehai_cands
                  #p [:pai, pai]
                  idx = self.tehais.index(pai)
                  remains = self.tehais.dup()
                  remains.delete_at(idx)
                  prog_prob = get_progress_prob(
                      remains, visible_set, visible.size, current_shanten)
                  cheapness = pai.type == "t" ? 5 : (5 - pai.number).abs
                  scores[idx] = [prog_prob, cheapness]
                  p [:score, self.tehais[idx], scores[idx]]
                end
                
                max_pai_index = scores.keys.max_by(){ |i| scores[i] }
                
                p [:dahai, self.tehais[max_pai_index]]
                #if self.id == 0
                #if has_reacher
                #  print("> ")
                #  gets()
                #end
                
                return create_action({:type => :dahai, :pai => self.tehais[max_pai_index]})
                
            end
            
          else  # action.actor != self
            
            case action.type
              when :dahai
                if ShantenAnalysis.new(self.tehais + [action.pai], -1).shanten == -1 &&
                    !self.furiten?
                  return create_action({:type => :hora, :target => action.actor, :pai => action.pai})
                end
              when :reach_accepted
                @prereach_sutehais_map[action.actor] = action.actor.sutehais.dup()
            end
            
          end
          
          return nil
        end
        
        State = Struct.new(:visible_set, :num_invisible, :num_tsumos)
        
        # Probability to decrease >= 1 shanten in 2 turns.
        def get_progress_prob(remains, visible_set, num_visible, current_shanten)
          
          state = State.new()
          state.visible_set = visible_set
          state.num_invisible = game.all_pais.size - num_visible
          #state.num_tsumos = game.num_pipais / 4
          
          shanten = ShantenAnalysis.new(remains, current_shanten, [:normal])
          if shanten.shanten > current_shanten
            return 0.0
          end
          
          #p [:remains, remains.join(" ")]
          candidates = get_required_pais_candidates(shanten)
          
          single_cands = Set.new()
          double_cands = Set.new()
          for pais in candidates
            case pais.size
              when 1
                single_cands.add(pais[0])
              when 2
                double_cands.add(pais)
              else
                raise("should not happen")
            end
          end
          double_cands = double_cands.select(){ |pais| pais.all?(){ |pai| !single_cands.include?(pai) } }
          #p [:single, single_cands.sort().join(" ")]
          #p [:double, double_cands]
          
          # (p, *) or (*, p)
          any_single_prob = single_cands.map(){ |pai| get_pai_prob(pai, state) }.inject(0.0, :+)
          total_prob = 1.0 - (1.0 - any_single_prob) ** 2
          
          #p [:single_total, total_prob]
          for pai1, pai2 in double_cands
            prob1 = get_pai_prob(pai1, state)
            #p [:prob, pai1, state]
            prob2 = get_pai_prob(pai2, state)
            #p [:prob, pai2, state]
            if pai1 == pai2
              # (p1, p1)
              total_prob += prob1 * prob2
            else
              # (p1, p2), (p2, p1)
              total_prob += prob1 * prob2 * 2
            end
          end
          #p [:total_prob, total_prob]
          return total_prob
        end
        
        # Pais required to decrease 1 shanten.
        # Can be multiple pais, but not all multi-pai cases are included.
        # - included: 45m for 13m
        # - not included: 2m6s for 23m5s
        def get_required_pais_candidates(shanten)
          result = Set.new()
          for mentsus in shanten.combinations
            for janto_index in [nil] + (0...mentsus.size).to_a()
              t_mentsus = mentsus.dup()
              if janto_index
                next if ![:toitsu, :kotsu].include?(mentsus[janto_index][0])
                t_mentsus.delete_at(janto_index)
              end
              current_shanten =
                  -1 +
                  (janto_index ? 0 : 1) +
                  t_mentsus.map(){ |t, ps| 3 - ps.size }.sort()[0, 4].inject(0, :+)
              #p [:current_shanten, janto_index, current_shanten, shanten.shanten]
              next if current_shanten != shanten.shanten
              num_groups = t_mentsus.select(){ |t, ps| ps.size >= 2 }.size
              for type, pais in t_mentsus
                rnums_cands = []
                if !janto_index && pais.size == 1
                  # 1 -> janto
                  rnums_cands.push([0])
                end
                if !janto_index && pais.size == 2 && num_groups >= 5
                  # 2 -> janto
                  case type
                    when :ryanpen
                      rnums_cands.push([0], [1])
                    when :kanta
                      rnums_cands.push([0], [2])
                  end
                end
                if pais.size == 2
                  # 2 -> 3
                  case type
                    when :ryanpen
                      rnums_cands.push([-1], [2])
                    when :kanta
                      rnums_cands.push([1], [-2, -1], [3, 4])
                    when :toitsu
                      rnums_cands.push([0], [-2, -1], [-1, 1], [1, 2])
                    else
                      raise("should not happen")
                  end
                end
                if pais.size == 1 && num_groups < 4
                  # 1 -> 2
                  rnums_cands.push([-2], [-1], [0], [1], [2])
                end
                if pais.size == 1
                  # 1 -> 3
                  rnums_cands.push([-2, -1], [-1, 1], [1, 2], [0, 0])
                end
                for rnums in rnums_cands
                  in_range = rnums.all?() do |rn|
                    (rn == 0 || pais[0].type != "t") && (1..9).include?(pais[0].number + rn)
                  end
                  if in_range
                    result.add(rnums.map(){ |rn| Pai.new(pais[0].type, pais[0].number + rn) })
                  end
                end
              end
            end
          end
          return result
        end
        
        def get_pai_prob(pai, state)
          return (4 - state.visible_set[pai]).to_f() / state.num_invisible
        end
        
        # This is too slow but left here as most precise baseline.
        def get_hora_prob_with_monte_carlo(tehais, visible_set, num_visible)
          invisibles = []
          for pai in self.game.all_pais.uniq
            next if pai.red?
            (4 - visible_set[pai]).times() do
              invisibles.push(pai)
            end
          end
          num_tsumos = game.num_pipais / 4
          hora_freq = 0
          num_tries = 1000
          num_tries.times() do
            tsumos = invisibles.sample(num_tsumos)
            pais = tehais + tsumos
            #p [:pais, pais.sort().join(" ")]
            can_be = can_be_hora?(pais)
            #p [:can_be, can_be]
            next if !can_be
            shanten = ShantenAnalysis.new(pais, -1, [:normal], 14, false)
            #pp [:shanten, tehais, tsumos, shanten.shanten]
            #if shanten.shanten == -1
            #  pp [:comb, shanten.combinations[0]]
            #end
            hora_freq += 1 if shanten.shanten == -1
          end
          return hora_freq.to_f() / num_tries
        end
        
        def can_be_hora?(pais)
          pai_set = to_pai_set(pais)
          kotsus = pai_set.select(){ |pai, c| c >= 3 }
          toitsus = pai_set.select(){ |pai, c| c >= 2 }
          num_cont = 1
          # TODO 重複を考慮
          num_shuntsus = 0
          pais.map(){ |pai| pai.remove_red() }.sort().uniq().each_cons(2) do |prev_pai, pai|
            if pai.type != "t" && pai.type == prev_pai.type && pai.number == prev_pai.number + 1
              num_cont += 1
              if num_cont >= 3
                num_shuntsus += 1
                num_cont = 0
              end
            else
              num_cont = 1
            end
          end
          return kotsus.size + num_shuntsus >= 4 && toitsus.size >= 1
        end
        
        def to_pai_set(pais)
          pai_set = Hash.new(0)
          for pai in pais
            pai_set[pai.remove_red()] += 1
          end
          return pai_set
        end
        
        def random_test()
          all_pais = (["m", "p", "s"].map(){ |t| (1..9).map(){ |n| Pai.new(t, n) } }.flatten() +
              (1..7).map(){ |n| Pai.new("t", n) }) * 4
          while true
            pais = all_pais.sample(13).sort()
            puts(pais.join(" "))
            (nj, nm, jimp, mimp) = get_improvers(pais)
            p [nj, nm]
            for name, imp in [["jimp", jimp], ["mimp", mimp]]
              for pais in imp.to_a().sort()
                puts("%s: %s" % [name, pais.join(" ")])
              end
            end
            gets()
          end
        end
        
    end

    class MockGame
        
        def initialize()
          pais = (0...4).map() do |i|
            ["m", "p", "s"].map(){ |t| (1..9).map(){ |n| Pai.new(t, n, n == 5 && i == 0) } } +
                (1..7).map(){ |n| Pai.new("t", n) }
          end
          @all_pais = pais.flatten().sort()
        end
        
        attr_reader(:all_pais)
        
    end

end
