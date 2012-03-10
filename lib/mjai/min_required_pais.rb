require "set"
require "pp"
require "./mahjong"


module Mjai

    class MinRequiredPais
        
        def initialize(pais_or_shanten, num_allowed_extra = 0)
          if pais_or_shanten.is_a?(ShantenCounter)
            @shanten = pais_or_shanten
          else
            @shanten = ShantenCounter.new(pais_or_shanten, nil, [:normal])
          end
          @max_required_pais = @shanten.shanten + 1 + num_allowed_extra
          @seed_mentsus_candidates = get_seed_mentsus_candidates()
          p [:@seed_mentsus_candidates, @seed_mentsus_candidates.size]
        end
        
        attr_reader(:seed_mentsus_candidates)
        
        def candidates
          all_candidates = []
          for seed_mentsus in @seed_mentsus_candidates
            #pp [:seed, seed_mentsus]
            for pais in get_candidates(seed_mentsus, [], [])
              all_candidates.push(pais.sort())
            end
          end
          filtered_candidates = all_candidates.select() do |ps1|
            !all_candidates.any?(){ |ps2| ps2.size < ps1.size && (ps2 - ps1).empty? }
          end
          @candidates = Set.new(filtered_candidates)
          return @candidates
        end
        
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
        
        MENTSU_SIZES = {
          :kotsu => 3,
          :shuntsu => 3,
          :toitsu => 2,
          :ryanpen => 2,
          :kanta => 2,
          :single => 1,
        }
        
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
        
        def get_shanten(mentsu_types)
          shanten = 0
          if janto_idx = mentsu_types.index(:toitsu)
          elsif janto_idx = mentsu_types.index(:single)
            shanten += 1
          else
            # TODO 刻子や順子が頭に変わることも考える必要あり?
          end
          if janto_idx
            mentsu_types = mentsu_types.dup()
            mentsu_types.delete_at(janto_idx)
          end
          # TODO
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


    # NOTE: This doesn't output candidates which are generated from unoptimal seed combinations.
    class MinRequiredPais2
        
        SeedSet = Struct.new(:janto_seed, :mentsu_seeds)
        
        class Mentsu < Struct.new(:type, :pais)
            
            include(Comparable)
            
            def <=>(other)
              raise(ArgumentError, "comparison failed") if !other.is_a?(Mentsu)
              return [self.type, self.pais] <=> [other.type, other.pais]
            end
            
        end
        
        class Operator
            
            include(Enumerable)
            extend(Forwardable)
            
            def initialize(children)
              @children = []
              for child in children
                case child
                  when Pai
                    @children.push(PaiRequirement.new(child))
                  when self.class
                    @children.push(*child.children)
                  else
                    @children.push(child)
                end
              end
            end
            
            attr_reader(:children)
            def_delegators(:@children, :each, :[], :size, :empty?)
            
            def to_a()
              return @children
            end
            
            def ==(other)
              return self.class == other.class && to_a() == other.to_a()
            end
            
            alias eql? ==
            
            def hash
              return @children.hash
            end
            
        end
        
        class Or < Operator
            
            alias impossible? empty?
            
            def need_nothing?
              return @children.any?(){ |c| c.need_nothing? }
            end
            
            alias each_in_or each
            
            def each_in_and(&block)
              yield(self)
            end
            
            def to_s()
              if self.empty?
                return "IMPOSSIBLE"
              else
                return "(| %s)" % @children.join(" | ")
              end
            end
            
        end
        
        class And < Operator
            
            alias need_nothing? empty?
            
            def impossible?
              return @children.any?(){ |c| c.impossible? }
            end
            
            alias each_in_and each
            
            def each_in_or(&block)
              yield(self)
            end
            
            # NOTE: self.subsume?(self) == false
            def subsume?(other)
              raise("should not happen") if !other.is_a?(And)
              return self.size < other.size && (self.children - other.children).empty?
            end
            
            def to_s()
              if self.empty?
                return "NEED_NOTHING"
              else
                return "(& %s)" % @children.join(" & ")
              end
            end
            
        end
        
        class PaiRequirement
            
            def initialize(pai)
              @pai = pai
            end
            
            attr_reader(:pai)
            
            def need_nothing?
              return false
            end
            
            def impossible?
              return false
            end
            
            def each_in_or(&block)
              yield(self)
            end
            
            def each_in_and(&block)
              yield(self)
            end
            
            def to_s()
              return @pai.to_s()
            end
            
        end
        
        IMPOSSIBLE = Or.new([])
        NEED_NOTHING = And.new([])
        
        def self.cache(method_name)
          orig_method_name = "orig_#{method_name}"
          alias_method(orig_method_name, method_name)
          define_method(method_name) do |*args|
            key = [method_name] + args
            #pp(["->"] + key)
            cached = @cache.has_key?(key)
            @cache[key] = __send__(orig_method_name, *args) if !cached
            #pp([cached ? "<- (cached)" : "<-"] + key + [":", @cache[key]])
            return @cache[key]
          end
        end
        
        def initialize(pais_or_shanten, num_allowed_extra = 0, goal_shanten = -1)
          @cache = {}
          @mentsus_to_seeds = {}
          @required_pais_for_mentsu_cache = {}
          if pais_or_shanten.is_a?(ShantenCounter)
            @shanten = pais_or_shanten
          else
            @shanten = ShantenCounter.new(pais_or_shanten, nil, [:normal])
          end
          @goal_shanten = goal_shanten
          @goal_shanten_decrease = @shanten.shanten - goal_shanten
          @num_allowed_extra = num_allowed_extra
          @max_required_pais = @goal_shanten_decrease + num_allowed_extra
          @seed_candidates = get_seed_candidates()
        end
        
        attr_reader(:seed_candidates)
        
        def candidates
          all_candidates = []
          p [:seeds, @seed_candidates.size]
          for seed_set in @seed_candidates
            #pp [:seed, seed_set]
            for janto_shanten_decrease in [0, 1]
              janto_req = get_requirement_for_janto(seed_set.janto_seed, janto_shanten_decrease)
              #pp [:janto_req, seed_set.janto_seed, janto_shanten_decrease, janto_req]
              next if janto_req.impossible?
              max_shanten_decrease = seed_set.mentsu_seeds.map(){ |m| 3 - m.pais.size }.inject(:+)
              mentsus_req = get_requirement_for_mentsus(
                  seed_set.mentsu_seeds.select(){ |m| m.pais.size < 3 },
                  max_shanten_decrease,
                  @goal_shanten_decrease - janto_shanten_decrease,
                  @num_allowed_extra)
              mentsus_req.each_in_or() do |mentsus_term|
                all_candidates.push(simplify(and_of([janto_req, mentsus_term])))
              end
            end
          end
          #for candidate in all_candidates
          #  p [:all_candidate, candidate.to_s()]
          #end
          filtered_candidates = all_candidates.select() do |req1|
            !all_candidates.any?(){ |req2| req2.subsume?(req1) }
          end
          @candidates = Set.new(filtered_candidates)
          #for candidate in @candidates
          #  p [:filtered_candidate, candidate.to_s()]
          #end
          return @candidates
        end
        
        def simplify(req)
          if req.is_a?(And)
            return And.new(req.select(){ |c| !c.need_nothing? })
          else
            return req
          end
        end
        
        def get_requirement_for_janto(seed, goal_shanten_decrease)
          case goal_shanten_decrease
            when 0
              return NEED_NOTHING
            when 1
              if [:toitsu, :kotsu].include?(seed.type)
                return IMPOSSIBLE
              else
                return or_of(seed.pais)
              end
            else
              raise("should not happen")
          end
        end
        
        def get_requirement_for_mentsus(seeds, max_shanten_decrease, goal_shanten_decrease, max_extra)
          if seeds.empty?
            if goal_shanten_decrease == 0
              #p :good
              return NEED_NOTHING
            else
              #p :bad
              return IMPOSSIBLE
            end
          else
            cands = []
            car_max_shanten_decrease = 3 - seeds[0].pais.size
            car_min_shanten_decrease =
                car_max_shanten_decrease - (max_shanten_decrease - goal_shanten_decrease)
            for car_shanten_decrase in
                car_min_shanten_decrease..[car_max_shanten_decrease, goal_shanten_decrease].min
              for car_num_extra in 0..[1, max_extra].min
                car_req =
                    get_requirement_for_mentsu(seeds[0], car_shanten_decrase, car_num_extra)
                #pp [:mentsu_req, seeds[0], car_shanten_decrase, car_num_extra, car_req]
                next if car_req.impossible?
                cdr_req = get_requirement_for_mentsus(
                    seeds[1..-1],
                    max_shanten_decrease - car_max_shanten_decrease,
                    goal_shanten_decrease - car_shanten_decrase,
                    max_extra - car_num_extra)
                cdr_req.each_in_or() do |cdr_term|
                  cands.push(and_of([car_req, cdr_term]))
                end
              end
            end
            return or_of(cands)
          end
        end
        
        def get_requirement_for_mentsu(seed, shanten_decrease, num_extra)
          if shanten_decrease == 0 && num_extra == 0
            rel_cands = [[]]
          else
            case [seed.type, shanten_decrease, num_extra]
              when [:ryanpen, 1, 0]
                rel_cands = [[-1], [2]]
              when [:kanta, 1, 0]
                rel_cands = [[1]]
              when [:kanta, 1, 1]
                rel_cands = [[-2, -1], [3, 4]]
              when [:toitsu, 1, 0]
                rel_cands = [[0]]
              when [:toitsu, 1, 1]
                rel_cands = [[-2, -1], [-1, 1], [1, 2]]
              when [:single, 1, 0]
                rel_cands = [[-2], [-1], [0], [1], [2]]
              when [:single, 2, 0]
                rel_cands = [[0, 0], [-2, -1], [-1, 1], [1, 2]]
              else
                rel_cands = []
            end
          end
          return get_requirement_from_relative_numbers(seed.pais[0], rel_cands)
        end
        
        def get_requirement_from_relative_numbers(pai, rel_num_cands)
          terms = rel_num_cands.
            map(){ |is| is.map(){ |i| pai.number + i } }.
            select(){ |ns| ns.all?(){ |n| (n == 0 || pai.type != "t") && (1..9).include?(n) } }.
            map(){ |ns| and_of(ns.map(){ |n| Pai.new(pai.type, n) }) }
          return or_of(terms)
        end
        
        def get_seed_candidates()
          result = []
          seen_mentsus_set = Set.new()
          for combination in @shanten.combinations
            case combination
              when :chitoitsu
                raise("not implemented")
              when :kokushimuso
                raise("not implemented")
              else
                all_mentsus = combination.map(){ |t, ps| Mentsu.new(t, ps) }
                all_mentsus.combination(5) do |mentsus|
                  mentsus = mentsus.sort()  # To keep same set equal.
                  next if seen_mentsus_set.include?(mentsus)
                  seen_mentsus_set.add(mentsus)
                  for i in 0...mentsus.size
                    janto_seed = mentsus[i]
                    mentsu_seeds = mentsus.dup()
                    mentsu_seeds.delete_at(i)
                    if get_shanten(janto_seed, mentsu_seeds) == @shanten.shanten
                      seed_set = SeedSet.new(janto_seed, mentsu_seeds)
                      #pp [:seed_set, seed_set]
                      result.push(seed_set)
                    end
                  end
                end
            end
          end
          #pp result
          return result
        end
        
        def get_shanten(janto_seed, mentsu_seeds)
          shanten = -1
          shanten += 1 if ![:toitsu, :kotsu].include?(janto_seed.type)
          shanten += mentsu_seeds.map(){ |m| 3 - m.pais.size }.inject(0, :+)
          return shanten
        end
        
        def or_of(reqs)
          return join(Or, reqs)
        end
        
        def and_of(reqs)
          return join(And, reqs)
        end
        
        def join(op_class, reqs)
          return op_class.new(reqs)
        end
        
        cache(:get_requirement_for_janto)
        cache(:get_requirement_for_mentsus)
        cache(:get_requirement_for_mentsu)
        
        def self.benchmark(verbose = false)
          srand(0)
          all_pais = (["m", "p", "s"].map(){ |t| (1..9).map(){ |n| Pai.new(t, n) } }.flatten() +
              (1..7).map(){ |n| Pai.new("t", n) }) * 4
          while true
            pais = all_pais.sample(13).sort()
            shanten = ShantenCounter.new(pais, nil, [:normal])
            if verbose
              puts("%s (%d)" % [pais.join(" "), shanten.shanten])
            end
            if shanten.shanten >= 4
              goal_shanten = shanten.shanten - 1
            elsif shanten.shanten >= 2
              goal_shanten = shanten.shanten - 2
            else
              goal_shanten = -1
            end
            cands = MinRequiredPais2.new(shanten, 1, goal_shanten).candidates
            if verbose
              for candidate in cands
                p [:candidate, candidate.to_s()]
              end
              gets()
            end
          end
        end

    end

end


#MinRequiredPais2.benchmark(true)
