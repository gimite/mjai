require "set"
require "mjai/pai"
require "mjai/mentsu"


module Mjai
    
    class ShantenAnalysis
        
        # ryanpen = 両面 or 辺搭
        MENTSU_TYPES = [:kotsu, :shuntsu, :toitsu, :ryanpen, :kanta, :single]
        
        MENTSU_CATEGORIES = {
          :kotsu => :complete,
          :shuntsu => :complete,
          :toitsu => :toitsu,
          :ryanpen => :tatsu,
          :kanta => :tatsu,
          :single => :single,
        }
        
        MENTSU_SIZES = {
          :complete => 3,
          :toitsu => 2,
          :tatsu => 2,
          :single => 1,
        }
        
        ALL_TYPES = [:normal, :chitoitsu, :kokushimuso]
        
        def self.benchmark()
          all_pais = (["m", "p", "s"].map(){ |t| (1..9).map(){ |n| Pai.new(t, n) } }.flatten() +
              (1..7).map(){ |n| Pai.new("t", n) }) * 4
          start_time = Time.now.to_f
          100.times() do
            pais = all_pais.sample(14).sort()
            p pais.join(" ")
            shanten = ShantenAnalysis.count(pais)
            p shanten
=begin
            for i in 0...pais.size
              remains_pais = pais.dup()
              remains_pais.delete_at(i)
              if ShantenAnalysis.count(remains_pais) == shanten
                p pais[i]
              end
            end
=end
            #gets()
          end
          p Time.now.to_f - start_time
        end

        def initialize(pais, max_shanten = nil, types = ALL_TYPES,
            num_used_pais = pais.size, need_all_combinations = true)
          
          @pais = pais
          @max_shanten = max_shanten
          @num_used_pais = num_used_pais
          @need_all_combinations = need_all_combinations
          raise(ArgumentError, "invalid number of pais") if @num_used_pais % 3 == 0
          @pai_set = Hash.new(0)
          for pai in @pais
            @pai_set[pai.remove_red()] += 1
          end
          
          @cache = {}
          results = []
          results.push(count_normal(@pai_set, [])) if types.include?(:normal)
          results.push(count_chitoi(@pai_set)) if types.include?(:chitoitsu)
          results.push(count_kokushi(@pai_set)) if types.include?(:kokushimuso)
          
          @shanten = 1.0/0.0
          @combinations = []
          for shanten, combinations in results
            next if @max_shanten && shanten > @max_shanten
            if shanten < @shanten
              @shanten = shanten
              @combinations = combinations
            elsif shanten == @shanten
              @combinations += combinations
            end
          end
          
        end
        
        attr_reader(:pais, :shanten, :combinations)
        
        DetailedCombination = Struct.new(:janto, :mentsus)
        
        def detailed_combinations
          num_required_mentsus = @pais.size / 3
          result = []
          for mentsus in @combinations.map(){ |ms| ms.map(){ |m| convert_mentsu(m) } }
            for janto_index in [nil] + (0...mentsus.size).to_a()
              t_mentsus = mentsus.dup()
              janto = nil
              if janto_index
                next if ![:toitsu, :kotsu].include?(mentsus[janto_index].type)
                janto = t_mentsus.delete_at(janto_index)
              end
              current_shanten =
                  -1 +
                  (janto_index ? 0 : 1) +
                  t_mentsus.map(){ |m| 3 - m.pais.size }.
                      sort()[0, num_required_mentsus].
                      inject(0, :+)
              next if current_shanten != @shanten
              result.push(DetailedCombination.new(janto, t_mentsus))
            end
          end
          return result
        end
        
        def convert_mentsu(mentsu)
          (type, pais) = mentsu
          if type == :ryanpen
            if [[1, 2], [8, 9]].include?(pais.map(){ |pai| pai.number })
              type = :penta
            else
              type = :ryanmen
            end
          end
          return Mentsu.new({:type => type, :pais => pais, :visibility => :an})
        end
        
        def count_chitoi(pai_set)
          num_toitsus = pai_set.select(){ |pai, n| n >= 2 }.size
          num_singles = pai_set.select(){ |pai, n| n == 1 }.size
          if num_toitsus == 6 && num_singles == 0
            # toitsu * 5 + kotsu * 1 or toitsu * 5 + kantsu * 1
            shanten = 1
          else
            shanten = -1 + [7 - num_toitsus, 0].max
          end
          return [shanten, [:chitoitsu]]
        end
        
        def count_kokushi(pai_set)
          yaochus = pai_set.select(){ |pai, n| pai.yaochu? }
          has_yaochu_toitsu = yaochus.any?(){ |pai, n| n >= 2 }
          return [(13 - yaochus.size) - (has_yaochu_toitsu ? 1 : 0), [:kokushimuso]]
        end
        
        def count_normal(pai_set, mentsus)
          # TODO 上がり牌を全部自分が持っているケースを考慮
          key = get_key(pai_set, mentsus)
          if !@cache[key]
            if pai_set.empty?
              #p mentsus
              min_shanten = get_min_shanten_for_mentsus(mentsus)
              min_combinations = [mentsus]
            else
              shanten_lowerbound = get_min_shanten_for_mentsus(mentsus) if @max_shanten
              if @max_shanten && shanten_lowerbound > @max_shanten
                min_shanten = 1.0/0.0
                min_combinations = []
              else
                min_shanten = 1.0/0.0
                first_pai = pai_set.keys.sort()[0]
                for type in MENTSU_TYPES
                  if @max_shanten == -1
                    next if [:ryanpen, :kanta].include?(type)
                    next if mentsus.any?(){ |t, ps| t == :toitsu } && type == :toitsu
                  end
                  (removed_pais, remains_set) = remove(pai_set, type, first_pai)
                  if remains_set
                    (shanten, combinations) =
                        count_normal(remains_set, mentsus + [[type, removed_pais]])
                    if shanten < min_shanten
                      min_shanten = shanten
                      min_combinations = combinations
                      break if !@need_all_combinations && min_shanten == -1
                    elsif shanten == min_shanten && shanten < 1.0/0.0
                      min_combinations += combinations
                    end
                  end
                end
              end
            end
            @cache[key] = [min_shanten, min_combinations]
          end
          return @cache[key]
        end
        
        def get_key(pai_set, mentsus)
          return [pai_set, Set.new(mentsus)]
        end
        
        def get_min_shanten_for_mentsus(mentsus)
          
          mentsu_categories = mentsus.map(){ |t, ps| MENTSU_CATEGORIES[t] }
          num_current_pais = mentsu_categories.map(){ |m| MENTSU_SIZES[m] }.inject(0, :+)
          num_remain_pais = @pais.size - num_current_pais
          
          min_shantens = []
          if index = mentsu_categories.index(:toitsu)
            # Assumes the 対子 is 雀頭.
            mentsu_categories.delete_at(index)
            min_shantens.push(get_min_shanten_without_janto(mentsu_categories, num_remain_pais))
          else
            # Assumes 雀頭 is missing.
            min_shantens.push(get_min_shanten_without_janto(mentsu_categories, num_remain_pais) + 1)
            if num_remain_pais >= 2
              # Assumes 雀頭 is in remaining pais.
              min_shantens.push(get_min_shanten_without_janto(mentsu_categories, num_remain_pais - 2))
            end
          end
          return min_shantens.min
          
        end
        
        def get_min_shanten_without_janto(mentsu_categories, num_remain_pais)
          
          # Assumes remaining pais generates best combinations.
          mentsu_categories += [:complete] * (num_remain_pais / 3)
          case num_remain_pais % 3
            when 1
              mentsu_categories.push(:single)
            when 2
              mentsu_categories.push(:toitsu)
          end
          
          sizes = mentsu_categories.map(){ |m| MENTSU_SIZES[m] }.sort_by(){ |n| -n }
          num_required_mentsus = @num_used_pais / 3
          return -1 + sizes[0...num_required_mentsus].inject(0){ |r, n| r + (3 - n) }
          
        end
        
        def remove(pai_set, type, first_pai)
          case type
            when :kotsu
              removed_pais = [first_pai] * 3
            when :shuntsu
              removed_pais = shuntsu_piece(first_pai, [0, 1, 2])
            when :toitsu
              removed_pais = [first_pai] * 2
            when :ryanpen
              removed_pais = shuntsu_piece(first_pai, [0, 1])
            when :kanta
              removed_pais = shuntsu_piece(first_pai, [0, 2])
            when :single
              removed_pais = [first_pai]
            else
              raise("should not happen")
          end
          return [nil, nil] if !removed_pais
          result_set = pai_set.dup()
          for pai in removed_pais
            if result_set[pai] > 0
              result_set[pai] -= 1
              result_set.delete(pai) if result_set[pai] == 0
            else
              return [nil, nil]
            end
          end
          return [removed_pais, result_set]
        end
        
        def shuntsu_piece(first_pai, relative_numbers)
          if first_pai.type == "t"
            return nil
          else
            return relative_numbers.map(){ |i| Pai.new(first_pai.type, first_pai.number + i) }
          end
        end
        
        def inspect
          return "\#<%p shanten=%d pais=<%s>>" % [self.class, @shanten, @pais.join(" ")]
        end
        
    end
    
end
