require "set"
require "pp"
require "./mahjong"


class MinRequiredPais
    
    def initialize(pais)
      @pais = pais
      @shanten = ShantenCounter.new(@pais, nil, [:normal])
      @candidates = Set.new()
      for mentsus in @shanten.combinations
        case mentsus
          when :chitoitsu
            raise("not implemented")
          when :kokushimuso
            raise("not implemented")
          else
            mentsus.combination(5) do |seed_mentsus|
              if seed_mentsus_shanten(seed_mentsus) == @shanten.shanten
                #pp [:seed, seed_mentsus]
                for pais in get_candidates(seed_mentsus, [], [])
                  @candidates.add(pais.sort())
                end
              end
            end
        end
      end
    end
    
    attr_reader(:candidates)
    
    def seed_mentsus_shanten(seed_mentsus)
      seed_mentsus = seed_mentsus.dup()
      if janto_index = seed_mentsus.index(){ |t, ps| t == :toitsu }
        base_shanten = -1
      elsif janto_index = seed_mentsus.index(){ |t, ps| t == :single }
        base_shanten = 0
      else
        return 1.0/0.0
      end
      return base_shanten + (0...seed_mentsus.size).
          select(){ |i| i != janto_index }.
          map(){ |i| 3 - seed_mentsus[i][1].size }.
          inject(0, :+)
    end
    
    def get_candidates(remain_mentsus, created_mentsu_types, required_pais)
      #pp [:get_candidates, remain_mentsus, created_mentsu_types, required_pais]
      if required_pais.size > @shanten.shanten + 1
        return []
      elsif remain_mentsus.empty?
        num_required_mentsus = @pais.size / 3
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
          when :shuntsu, :kotsu
            new_cands = [[mtype, []]]
          when :ryanpen, :kanta
            rel_nums = mtype == :ryanpen ? [-1, 2] : [1]
            new_req_pai_cands = rel_nums.map(){ |r| pais[0].number + r }.
                select(){ |n| (1..9).include?(n) }.
                map(){ |n| Pai.new(pais[0].type, n) }
            new_cands = new_req_pai_cands.map(){ |pai| [:shuntsu, [pai]] }
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
    def self.benchmark()
      verbose = false
      srand(0)
      all_pais = (["m", "p", "s"].map(){ |t| (1..9).map(){ |n| Pai.new(t, n) } }.flatten() +
          (1..7).map(){ |n| Pai.new("t", n) }) * 4
      10.times() do
        pais = all_pais.sample(14).sort()
        if verbose
          puts("%s (%d)" % [pais.join(" "), ShantenCounter.new(pais, nil, [:normal]).shanten])
        end
        cands = MinRequiredPais.new(pais).candidates
        if verbose
          for cand in cands.to_a().sort()
            puts("  %s" % cand.join(" "))
          end
          gets()
        end
      end
    end

end


#p MinRequiredPais.new(Pai.parse_pais("123m456p2378sWNN")).candidates
#p MinRequiredPais.new(Pai.parse_pais("123m456p2377sWNN")).candidates
#exit

