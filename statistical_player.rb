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
                  if self.reach?
                    return create_action({:type => :dahai, :pai => action.pai})
                  else
                    return create_action({:type => :reach})
                  end
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
            
            index_to_metrics = {}
            for pai in self.tehais.uniq()
              idx = self.tehais.index(pai)
              remains = self.tehais.dup()
              remains.delete_at(idx)
              #p [:take, self.tehais[idx]]
              (num_broad_mentsus, prob) = get_hora_prob(remains, visible_set, visible.size)
              p [:hora_prob, self.tehais[idx], num_broad_mentsus, prob]
              index_to_metrics[idx] = [num_broad_mentsus, prob]
            end
            
            max_broad_mentsus = index_to_metrics.values.map(){ |m, pr| m }.max
            max_pai_index = index_to_metrics.keys.
                select(){ |i| index_to_metrics[i][0] == max_broad_mentsus }.
                max_by(){ |i| index_to_metrics[i][1] }
            
            p [:dahai, self.tehais[max_pai_index]]
            #if self.id == 0
              print("> ")
              gets()
            #end
            
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
    
    def get_hora_prob(remains, visible_set, num_visible)
      
      state = State.new()
      state.visible_set = visible_set
      state.num_invisible = board.all_pais.size - num_visible
      state.num_tsumos = board.num_pipais / 4
      
      (num_jantos, num_mentsus, janto_improvers, mentsu_improvers) = get_improvers(remains)
      
      #p [:num, num_jantos, num_mentsus]
      #p :janto
      janto_imp_prob = get_prob_for_improvers(janto_improvers, state)
      #p [:prob, janto_imp_prob]
      #p :mentsu
      mentsu_imp_prob = get_prob_for_improvers(mentsu_improvers, state)
      #p [:prob, mentsu_imp_prob]
      return [
          num_jantos + num_mentsus,
          janto_imp_prob ** (1 - num_jantos) * mentsu_imp_prob ** (4 - num_mentsus),
      ]
    end
    
    def get_prob_for_improvers(improvers, state)
      return get_prob_for_improvers_with_monte_carlo(improvers, state)
    end
    
    def get_prob_for_improvers_approximately(improvers, state)
      req = MinRequiredPais2::Or.new(improvers.map(){ |ps| MinRequiredPais2::And.new(ps) })
      #p req.to_s()
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
    
    def get_prob_for_improvers_with_monte_carlo(improvers, state)
      invisibles = []
      for pai in self.board.all_pais.uniq
        next if pai.red?
        (4 - state.visible_set[pai]).times() do
          invisibles.push(pai)
        end
      end
      meet_freq = 0
      num_tries = 10000
      num_tries.times() do
        tsumos = invisibles.sample(state.num_tsumos)
        meet = have_improvers?(to_pai_set(tsumos), improvers)
        #p [:meet, tsumos.sort().join(" "), meet]
        meet_freq += 1 if meet
      end
      return meet_freq.to_f() / num_tries
    end
    
    def have_improvers?(pai_set, improvers)
      return improvers.any?() do |pais|
        to_pai_set(pais).all?() do |pai, count|
          pai_set[pai] >= count
        end
      end
    end
    
    # This is too slow but left here as most precise baseline.
    def get_hora_prob_with_monte_carlo(tehais, visible_set, num_visible)
      invisibles = []
      for pai in self.board.all_pais.uniq
        next if pai.red?
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
    def get_improvers(tehais)
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
      #p [:cands, cands.to_a().sort()]
      (tehai_num_jantos, tehai_num_mentsus) = num_mentsus(tehai_set)
      #p [:tehai_num_mentsus, tehai_num_jantos, tehai_num_mentsus]
      janto_improvers = Set.new()
      mentsu_improvers = Set.new()
      for pais in cands
        pais.each(){ |pai| tehai_set[pai] += 1 }
        (new_num_jantos, new_num_mentsus) = num_mentsus(tehai_set)
        pais.each(){ |pai| tehai_set[pai] -= 1 }
        if new_num_jantos + new_num_mentsus > tehai_num_jantos + tehai_num_mentsus
          if new_num_jantos > tehai_num_jantos && pais.size == 1
            janto_improvers.add(pais)
          end
          if new_num_mentsus > tehai_num_mentsus
            mentsu_improvers.add(pais)
          end
        end
      end
      return [
          tehai_num_jantos,
          tehai_num_mentsus,
          filter_improvers(janto_improvers),
          filter_improvers(mentsu_improvers),
      ]
    end
    
    def filter_improvers(all_result)
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
      num_without_janto = num_3pai_mentsus(pai_set)
      max_num_with_janto = 0
      for pai in pai_set.keys.select(){ |pai| pai_set[pai] >= 2 }
        pai_set[pai] -= 2
        num = num_3pai_mentsus(pai_set)
        max_num_with_janto = num if num > max_num_with_janto
        pai_set[pai] += 2
      end
      # e.g. Prefers [0, 4] to [1, 3]
      if max_num_with_janto == num_without_janto
        return [1, max_num_with_janto]
      else
        return [0, num_without_janto]
      end
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

class MockBoard
    
    def initialize()
      pais = (0...4).map() do |i|
        ["m", "p", "s"].map(){ |t| (1..9).map(){ |n| Pai.new(t, n, n == 5 && i == 0) } } +
            (1..7).map(){ |n| Pai.new("t", n) }
      end
      @all_pais = pais.flatten().sort()
    end
    
    attr_reader(:all_pais)
    
end
