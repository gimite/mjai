require "set"
require "pp"
require "./mahjong"


class MinRequiredPais
    
    def initialize(pais_or_shanten, num_allowed_extra = 0)
      if pais_or_shanten.is_a?(ShantenCounter)
        @shanten = pais_or_shanten
      else
        @shanten = ShantenCounter.new(pais_or_shanten, nil, [:normal])
      end
      @max_required_pais = @shanten.shanten + 1 + num_allowed_extra
      seed_mentsus_cands = get_seed_mentsus_candidates()
      p [:seed_mentsus_cands, seed_mentsus_cands.size]
      all_candidates = []
      for seed_mentsus in seed_mentsus_cands
        #pp [:seed, seed_mentsus]
        for pais in get_candidates(seed_mentsus, [], [])
          all_candidates.push(pais.sort())
        end
      end
      filtered_candidates = all_candidates.select() do |ps1|
        !all_candidates.any?(){ |ps2| ps2.size < ps1.size && (ps2 - ps1).empty? }
      end
      @candidates = Set.new(filtered_candidates)
    end
    
    attr_reader(:candidates)
    
    def get_seed_mentsus_candidates()
      result = []
      for mentsus in @shanten.combinations
        case mentsus
          when :chitoitsu
            raise("not implemented")
          when :kokushimuso
            raise("not implemented")
          else
            mentsus.combination(5) do |seed_mentsus|
              if get_num_required_pais(seed_mentsus) <= @max_required_pais
                #pp [:seed, seed_mentsus]
                result.push(seed_mentsus)
              end
            end
        end
      end
      return result
    end
    
    def get_num_required_pais(seed_mentsus)
      seed_mentsus = seed_mentsus.dup()
      if janto_index = seed_mentsus.index(){ |t, ps| t == :toitsu }
        result = 0
      elsif janto_index = seed_mentsus.index(){ |t, ps| t == :single }
        result = 1
      elsif janto_index = seed_mentsus.index(){ |t, ps| t == :kotsu }
        # TODO なんかこのへん怪しい
        result = 0
      else
        return 1.0/0.0
      end
      result += (0...seed_mentsus.size).
          select(){ |i| i != janto_index }.
          map(){ |i| 3 - seed_mentsus[i][1].size }.
          inject(0, :+)
      return result
    end
    
    def get_candidates(remain_mentsus, created_mentsu_types, required_pais)
      #pp [:get_candidates, remain_mentsus, created_mentsu_types, required_pais]
      if required_pais.size > @max_required_pais
        return []
      elsif remain_mentsus.empty?
        num_required_mentsus = @shanten.pais.size / 3
        if created_mentsu_types.size != num_required_mentsus + 1
          return []
        end
        if created_mentsu_types.select(){ |t| t == :toitsu }.size != 1
          return []
        end
        #p [:found, required_pais]
        return [required_pais]
      else
        (mtype, pais) = remain_mentsus[0]
        case mtype
          when :shuntsu
            new_cands = [[:shuntsu, []]]
          when :kotsu
            new_cands = [[:kotsu, [], :toitsu, []]]
          when :ryanpen, :kanta
            new_cands = []
            for n in [pais[0].number - 2, 1].max .. [pais[-1].number, 7].min
              req_pais = (n..(n+2)).map(){ |i| Pai.new(pais[0].type, i) } - pais
              new_cands.push([:shuntsu, req_pais])
            end
          when :toitsu
            new_cands = [[:toitsu, []], [:kotsu, [pais[0]]]]
          when :single
            new_cands = []
            new_cands.push([:toitsu, [pais[0]]])
            new_cands.push([:kotsu, [pais[0]] * 2])
            if pais[0].type != "t"
              for rel_nums in [[-2, -1], [-1, 1], [1, 2]]
                nums = rel_nums.map(){ |r| pais[0].number + r }
                next if nums.any?(){ |n| !(1..9).include?(n) }
                new_cands.push([:shuntsu, nums.map(){ |n| Pai.new(pais[0].type, n) }])
              end
            end
          else
            raise("should not happen")
        end
        #pp [:new_cands, mtype, pais, new_cands]
        #new_cands.push([nil, []])
        result = []
        for new_mtype, new_required_pais in new_cands
          result += get_candidates(
              remain_mentsus[1..-1],
              created_mentsu_types + (new_mtype ? [new_mtype] : []),
              required_pais + new_required_pais)
        end
        return result
      end
    end
    
    # 6.48 -> 1.78
    def self.benchmark(verbose = false, num_allowed_extra = 0)
      srand(0)
      all_pais = (["m", "p", "s"].map(){ |t| (1..9).map(){ |n| Pai.new(t, n) } }.flatten() +
          (1..7).map(){ |n| Pai.new("t", n) }) * 4
      10.times() do
        pais = all_pais.sample(14).sort()
        if verbose
          puts("%s (%d)" % [pais.join(" "), ShantenCounter.new(pais, nil, [:normal]).shanten])
        end
        cands = MinRequiredPais.new(pais, num_allowed_extra).candidates
        if verbose
          for cand in cands.to_a().sort()
            puts("  %s" % cand.join(" "))
          end
          gets()
        end
      end
    end

end
