require "./mahjong"
require "./min_required_pais"


class StatisticalPlayer < Player
    
    def respond_to_action(action)
      
      if action.actor == self
        
        case action.type
          
          when :tsumo, :chi, :pon, :reach
            
            current_shanten = ShantenCounter.new(self.tehais, nil, [:normal]).shanten
            if action.type == :tsumo
              case current_shanten
                when -1
                  return create_action({:type => :hora, :target => action.actor, :pai => action.pai})
                when 0
                  return create_action({:type => :reach}) if !self.reach?
              end
            end
            p [:shanten, current_shanten]
            
            visible = []
            visible += self.board.doras
            visible += self.tehais
            for player in self.board.players
              visible += player.ho + player.furos.map(){ |f| f.pais }.flatten()
            end
            visible_set = to_pai_set(visible)
            
            if current_shanten >= 4
              goal_shanten = current_shanten - 1
            elsif current_shanten >= 2
              goal_shanten = current_shanten - 2
            else
              goal_shanten = -1
            end
            
            targets = []
            #total_seeds = 0
            for pai in self.tehais.uniq()
              idx = self.tehais.index(pai)
              remains = self.tehais.dup()
              remains.delete_at(idx)
              shanten = ShantenCounter.new(remains, current_shanten, [:normal])
              if shanten.shanten != current_shanten
                next
              end
              targets.push([idx, shanten])
              #total_seeds += MinRequiredPais.new(shanten, 1).seed_mentsus_candidates.size
            end
            #num_allowed_extra = total_seeds >= 400 ? 0 : 1
            #p [:num_allowed_extra, num_allowed_extra, total_seeds]
            
            max_prob = -1.0/0.0
            max_pai_index = nil
            for idx, shanten in targets
              prob = get_hora_prob(shanten, visible_set, visible.size, goal_shanten)
              p [:hora_prob, self.tehais[idx], prob]
              if prob > max_prob
                max_prob = prob
                max_pai_index = idx
              end
            end
            p [:dahai, self.tehais[max_pai_index]]
            if self.id == 0
              print("> ")
              gets()
            end
            
            return create_action({:type => :dahai, :pai => self.tehais[max_pai_index]})
            
        end
        
      else  # action.actor != self
        
        case action.type
          when :dahai
            if ShantenCounter.new(self.tehais + [action.pai], -1).shanten == -1
              return create_action({:type => :hora, :target => action.actor, :pai => action.pai})
            end
        end
        
      end
      
      return nil
    end
    
    State = Struct.new(:visible_set, :num_invisible, :num_tsumos)
    
    def get_hora_prob(shanten, visible_set, num_visible, goal_shanten)
      
      state = State.new()
      state.visible_set = visible_set
      state.num_invisible = board.all_pais.size - num_visible
      num_all_tsumos = board.num_pipais / 4
      # Assumes shanten decease is linear.
      state.num_tsumos = num_all_tsumos * (shanten.shanten - goal_shanten) / (shanten.shanten - (-1))
      
      req = MinRequiredPais2::Or.new(MinRequiredPais2.new(shanten, 1, goal_shanten).candidates.to_a())
      return get_prob_for_requirement(req, state)
      
    end
    
    def get_prob_for_requirement(req, state)
      case req
        when MinRequiredPais2::PaiRequirement
          num_same_invisible = 4 - state.visible_set[req.pai]
          prob = 1.0 -
              num_permutations(state.num_invisible - num_same_invisible, state.num_tsumos) /
              num_permutations(state.num_invisible, state.num_tsumos).to_f()
        when MinRequiredPais2::Or
          neg_prob = 1.0
          for child in req.children
            neg_prob *= (1.0 - get_prob_for_requirement(child, state))
          end
          prob = 1.0 - neg_prob
        when MinRequiredPais2::And
          prob = 1.0
          for child in req.children
            prob *= get_prob_for_requirement(child, state)
          end
        else
          raise("should not happen")
      end
      #p [:prob, req.to_s(), prob]
      return prob
    end
    
    # This is too slow but left here as most precise baseline.
    def get_hora_prob_with_monte_carlo(tehais, visible_set, num_visible)
      invisibles = []
      for pai in board.all_pais.uniq
        pai = pai.remove_red()
        (4 - visible_set[pai]).times() do
          invisibles.push(pai)
        end
      end
      num_tsumos = board.num_pipais / 4
      hora_freq = 0
      num_tries = 1000
      num_tries.times() do
        tsumos = invisibles.sample(num_tsumos)
        pais = tehais + tsumos
        #p [:pais, pais.sort().join(" ")]
        can_be = can_be_hora?(pais)
        #p [:can_be, can_be]
        next if !can_be
        shanten = ShantenCounter.new(pais, -1, [:normal], 14, false)
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
    
    # NOTE: This doesn't output two pais in long distance e.g. 16m for 2345m for now.
    def improvers(tehais)
      tehai_set = to_pai_set(tehais)
      cands = Set.new()
      for pai, count in tehai_set
        cands.add([pai])
        cands.add([pai, pai])
        if pai.type != "t"
          for rs in [[-1], [1], [-2, -1], [-1, 1], [1, 2]]
            pais = rs.map(){ |r| Pai.new(pai.type, pai.number + r) }
            if pais.all?(){ |pai| (1..9).include?(pai.number) }
              cands.add(pais)
            end
          end
        end
      end
      p [:cands, cands.to_a().sort()]
      tehai_num_mentsus = num_mentsus(tehai_set)
      p [:tehai_num_mentsus, tehai_num_mentsus]
      all_result = Set.new()
      single_improvers = Set.new()
      for pais in cands
        pais.each(){ |pai| tehai_set[pai] += 1 }
        new_num_mentsus = num_mentsus(tehai_set)
        pais.each(){ |pai| tehai_set[pai] -= 1 }
        if new_num_mentsus > tehai_num_mentsus
          all_result.add(pais)
        end
      end
      filtered_result = Set.new()
      for pais in all_result
        case pais.size
          when 1
            filtered_result.add(pais)
          when 2
            if pais.all?(){ |pai| !all_result.include?([pai]) }
              filtered_result.add(pais)
            end
          else
            raise("should not happen")
        end
      end
      return filtered_result
    end
    
    def num_mentsus(pais)
      pai_set = pais.is_a?(Hash) ? pais : to_pai_set(pais)
      max_num = 0
      for pai in pai_set.keys.select(){ |pai| pai_set[pai] >= 2 } + [nil]
        pai_set[pai] -= 2 if pai
        num = num_3pai_mentsus(pai_set) + (pai ? 1 : 0)
        max_num = num if num > max_num
        pai_set[pai] += 2 if pai
      end
      return max_num
    end
    
    def num_3pai_mentsus(pai_set)
      kotsu_pais = pai_set.keys.select(){ |pai| pai_set[pai] >= 3 }
      return num_3pai_mentsus_recurse(pai_set, kotsu_pais)
    end
    
    def num_3pai_mentsus_recurse(pai_set, kotsu_pais)
      if kotsu_pais.empty?
        return num_shuntsus(pai_set)
      else
        car_pai = kotsu_pais[0]
        cdr_pais = kotsu_pais[1..-1]
        num_without = num_3pai_mentsus_recurse(pai_set, cdr_pais)
        pai_set[car_pai] -= 3
        num_with = num_3pai_mentsus_recurse(pai_set, cdr_pais) + 1
        pai_set[car_pai] += 3
        return [num_without, num_with].max
      end
    end
    
    def num_shuntsus(pai_set)
      pai_set = pai_set.dup()
      num = 0
      for pai in pai_set.keys.sort()
        next if pai.type == "t"
        shuntsu_pais = (0..2).map(){ |i| Pai.new(pai.type, pai.number + i) }
        while shuntsu_pais.all?(){ |sp| pai_set[sp] > 0 }
          shuntsu_pais.each(){ |sp| pai_set[sp] -= 1 }
          num += 1
        end
      end
      return num
    end
    
    def num_permutations(n, m)
      return ((n - m + 1)..n).inject(1, :*)
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
        for pais in improvers(pais).to_a().sort()
          puts(pais.join(" "))
        end
        gets()
      end
    end
    
end

#StatisticalPlayer.new.random_test()
