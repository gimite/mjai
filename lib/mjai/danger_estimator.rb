# coding: utf-8

require "set"
require "optparse"
require "with_progress"
require "./mahjong"


module Mjai
    
    
    class DangerEstimator
        
        class Scene
            
            URASUJI_INV_MAP = {
              1 => [5],
              2 => [1, 6],
              3 => [2, 7],
              4 => [3, 5, 8],
              5 => [1, 4, 6, 9],
              6 => [2, 5, 7],
              7 => [3, 8],
              8 => [4, 9],
              9 => [5],
            }
            
            SENKISUJI_INV_MAP = {
              3 => [1, 8],
              4 => [2, 9],
              5 => [3, 7],
              6 => [1, 8],
              7 => [2, 9],
            }
            
            @@feature_names = []
            
            def self.define_feature(name, &block)
              define_method(name, &block)
              @@feature_names.push(name)
            end
            
            def self.feature_names
              return @@feature_names
            end
            
            def initialize(game, me, dapai, reacher, prereach_sutehais)
              
              @game = game
              @dapai = dapai
              @me = me
              @reacher = reacher
              @prereach_sutehais = prereach_sutehais
              
              tehais = @me.tehais.dup()
              tehais.push(@dapai) if @dapai
              @anpai_set = to_pai_set(reacher.anpais)
              @prereach_sutehai_set = to_pai_set(@prereach_sutehais)
              @early_sutehai_set = to_pai_set(@prereach_sutehais[0...(@prereach_sutehais.size / 2)])
              @late_sutehai_set = to_pai_set(@prereach_sutehais[(@prereach_sutehais.size / 2)..-1])
              @dora_set = to_pai_set(@game.doras)
              @tehai_set = to_pai_set(tehais)
              
              visible = []
              visible += @game.doras
              visible += @me.tehais
              for player in @game.players
                visible += player.ho + player.furos.map(){ |f| f.pais }.flatten()
              end
              @visible_set = to_pai_set(visible)
              
              @candidates = tehais.
                  map(){ |pai| pai.remove_red() }.
                  uniq().
                  select(){ |pai| !@anpai_set.has_key?(pai) }
              
            end
            
            attr_reader(:candidates)
            
            def to_pai_set(pais)
              pai_set = Hash.new(0)
              for pai in pais
                pai_set[pai.remove_red()] += 1
              end
              return pai_set
            end
            
            # pai is without red.
            # Use bit vector to make match? faster.
            def feature_vector(pai)
              return DangerEstimator.bool_array_to_bit_vector(
                  @@feature_names.map(){ |s| __send__(s, pai) })
            end
            
            def anpai?(pai)
              return @anpai_set.has_key?(pai.remove_red())
            end
            
            define_feature("tsupai") do |pai|
              return pai.type == "t"
            end
            
            define_feature("suji") do |pai|
              if pai.type == "t"
                return false
              else
                return get_suji_numbers(pai).all?(){ |n| @anpai_set.has_key?(Pai.new(pai.type, n)) }
              end
            end
            
            # 片筋 or 筋
            define_feature("weak_suji") do |pai|
              return suji_of(pai, @anpai_set)
            end
            
            define_feature("reach_suji") do |pai|
              reach_pai = @prereach_sutehais[-1].remove_red()
              if pai.type == "t" || reach_pai.type != pai.type || pai.number == 1 || pai.number == 9
                return false
              else
                suji_numbers = get_suji_numbers(pai)
                return suji_numbers.all?(){ |n| @prereach_sutehai_set.include?(Pai.new(pai.type, n)) } &&
                    suji_numbers.include?(reach_pai.number) &&
                    @prereach_sutehai_set[reach_pai] == 1
              end
            end
            
            # http://ja.wikipedia.org/wiki/%E7%AD%8B_(%E9%BA%BB%E9%9B%80)#.E8.A3.8F.E3.82.B9.E3.82.B8
            define_feature("urasuji") do |pai|
              return urasuji_of(pai, @prereach_sutehai_set)
            end
            
            define_feature("early_urasuji") do |pai|
              return urasuji_of(pai, @early_sutehai_set)
            end
            
            define_feature("reach_urasuji") do |pai|
              return urasuji_of(pai, to_pai_set([self.reach_pai]))
            end
            
            # http://ja.wikipedia.org/wiki/%E7%AD%8B_(%E9%BA%BB%E9%9B%80)#.E9.96.93.E5.9B.9B.E9.96.93
            define_feature("aida4ken") do |pai|
              if pai.type == "t"
                return false
              else
                return ((2..5).include?(pai.number) &&
                      @prereach_sutehai_set.has_key?(Pai.new(pai.type, pai.number - 1)) &&
                      @prereach_sutehai_set.has_key?(Pai.new(pai.type, pai.number + 4))) ||
                    ((5..8).include?(pai.number) &&
                      @prereach_sutehai_set.has_key?(Pai.new(pai.type, pai.number - 4)) &&
                      @prereach_sutehai_set.has_key?(Pai.new(pai.type, pai.number + 1)))
              end
            end
            
            # http://ja.wikipedia.org/wiki/%E7%AD%8B_(%E9%BA%BB%E9%9B%80)#.E3.81.BE.E3.81.9F.E3.81.8E.E3.82.B9.E3.82.B8
            define_feature("matagisuji") do |pai|
              return matagisuji_of(pai, @prereach_sutehai_set)
            end
            
            define_feature("late_matagisuji") do |pai|
              return matagisuji_of(pai, @late_sutehai_set)
            end
            
            # http://ja.wikipedia.org/wiki/%E7%AD%8B_(%E9%BA%BB%E9%9B%80)#.E7.96.9D.E6.B0.97.E3.82.B9.E3.82.B8
            define_feature("senkisuji") do |pai|
              return senkisuji_of(pai, @prereach_sutehai_set)
            end
            
            define_feature("early_senkisuji") do |pai|
              return senkisuji_of(pai, @early_sutehai_set)
            end
            
            define_feature("outer_prereach_sutehai") do |pai|
              return outer(pai, @prereach_sutehai_set)
            end
            
            define_feature("outer_early_sutehai") do |pai|
              return outer(pai, @early_sutehai_set)
            end
            
            (0..3).each() do |n|
              define_feature("chances<=#{n}") do |pai|
                return n_chance_or_less(pai, n)
              end
            end
            
            (1..3).each() do |i|
              define_feature("visible>=%d" % i) do |pai|
                return visible_n_or_more(pai, i)
              end
            end
            
            (2..5).each() do |i|
              define_feature("%d<=n<=%d" % [i, 10 - i]) do |pai|
                return num_n_or_inner(pai, i)
              end
            end
            
            define_feature("dora") do |pai|
              return @dora_set.has_key?(pai)
            end
            
            define_feature("dora_suji") do |pai|
              return suji_of(pai, @dora_set)
            end
            
            define_feature("dora_matagi") do |pai|
              return matagisuji_of(pai, @dora_set)
            end
            
            (2..4).each() do |i|
              define_feature("in_tehais>=#{i}") do |pai|
                return @tehai_set[pai] >= i
              end
            end
            
            (2..4).each() do |i|
              define_feature("suji_in_tehais>=#{i}") do |pai|
                if pai.type == "t"
                  return false
                else
                  return get_suji_numbers(pai).any?(){ |n| @tehai_set[Pai.new(pai.type, n)] >= i }
                end
              end
            end
            
            (1..2).each() do |i|
              (1..(i * 2)).each() do |j|
                define_feature("+-#{i}_in_prereach_sutehais>=#{j}") do |pai|
                  n_or_more_of_neighbors_in_prereach_sutehais(pai, j, i)
                end
              end
            end
            
            (1..2).each() do |i|
              define_feature("#{i}_outer_prereach_sutehai") do |pai|
                n_outer_prereach_sutehai(pai, i)
              end
            end
            
            (1..2).each() do |i|
              define_feature("#{i}_inner_prereach_sutehai") do |pai|
                n_outer_prereach_sutehai(pai, -i)
              end
            end
            
            (1..8).each() do |i|
              define_feature("same_type_in_prereach>=#{i}") do |pai|
                if pai.type == "t"
                  return false
                else
                  num_same_type = (1..9).
                      select(){ |n| @prereach_sutehai_set.has_key?(Pai.new(pai.type, n)) }.
                      size
                  return num_same_type >= i
                end
              end
            end
            
            define_feature("fanpai") do |pai|
              return fanpai_fansu(pai) >= 1
            end
            
            define_feature("ryenfonpai") do |pai|
              return fanpai_fansu(pai) >= 2
            end
            
            define_feature("sangenpai") do |pai|
              return pai.type == "t" && pai.number >= 5
            end
            
            define_feature("fonpai") do |pai|
              return pai.type == "t" && pai.number < 5
            end
            
            define_feature("bakaze") do |pai|
              return pai == @game.bakaze
            end
            
            define_feature("jikaze") do |pai|
              return pai == @reacher.jikaze
            end
            
            def n_outer_prereach_sutehai(pai, n)
              if pai.type == "t"
                return false
              elsif pai.number < 6 - n || pai.number > 4 + n
                n_inner_pai = Pai.new(pai.type, pai.number < 5 ? pai.number + n : pai.number - n)
                return @prereach_sutehai_set.include?(n_inner_pai)
              else
                return false
              end
            end
            
            def n_or_more_of_neighbors_in_prereach_sutehais(pai, n, neighbor_distance)
              if pai.type == "t"
                return false
              else
                num_neighbors =
                    ((pai.number - neighbor_distance)..(pai.number + neighbor_distance)).
                    select(){ |n| @prereach_sutehai_set.has_key?(Pai.new(pai.type, n)) }.
                    size
                return num_neighbors >= n
              end
            end
            
            def suji_of(pai, target_pai_set)
              if pai.type == "t"
                return false
              else
                return get_suji_numbers(pai).any?(){ |n| target_pai_set.has_key?(Pai.new(pai.type, n)) }
              end
            end
            
            def get_suji_numbers(pai)
              return [pai.number - 3, pai.number + 3].select(){ |n| (1..9).include?(n) }
            end
            
            def n_chance_or_less(pai, n)
              if pai.type == "t" || (4..6).include?(pai.number)
                return false
              else
                return (1..2).any?() do |i|
                  kabe_pai = Pai.new(pai.type, pai.number + (pai.number < 5 ? i : -i))
                  @visible_set[kabe_pai] >= 4 - n
                end
              end
            end
            
            def num_n_or_inner(pai, n)
              return pai.type != "t" && pai.number >= n && pai.number <= 10 - n
            end
            
            def visible_n_or_more(pai, n)
              # n doesn't include itself.
              return @visible_set[pai] >= n + 1
            end
            
            def urasuji_of(pai, target_pai_set)
              if pai.type == "t"
                return false
              else
                urasuji_numbers = URASUJI_INV_MAP[pai.number]
                return urasuji_numbers.any?(){ |n| target_pai_set.has_key?(Pai.new(pai.type, n)) }
              end
            end
            
            def senkisuji_of(pai, target_pai_set)
              if pai.type == "t"
                return false
              else
                senkisuji_numbers = SENKISUJI_INV_MAP[pai.number]
                return senkisuji_numbers &&
                    senkisuji_numbers.any?(){ |n| target_pai_set.has_key?(Pai.new(pai.type, n)) }
              end
            end
            
            def matagisuji_of(pai, target_pai_set)
              if pai.type == "t"
                return false
              else
                matagisuji_numbers = []
                if pai.number >= 4
                  matagisuji_numbers += [pai.number - 2, pai.number - 1]
                end
                if pai.number <= 6
                  matagisuji_numbers += [pai.number + 1, pai.number + 2]
                end
                return matagisuji_numbers.any?(){ |n| target_pai_set.has_key?(Pai.new(pai.type, n)) }
              end
            end
            
            def outer(pai, target_pai_set)
              if pai.type == "t" || pai.number == 5
                return false
              else
                inner_numbers = pai.number < 5 ? ((pai.number + 1)..5) : (5..(pai.number - 1))
                return inner_numbers.any?(){ |n| target_pai_set.has_key?(Pai.new(pai.type, n)) }
              end
            end
            
            def reach_pai
              return @prereach_sutehais[-1]
            end
            
            def fanpai_fansu(pai)
              if pai.type == "t" && pai.number >= 5
                return 1
              else
                return (pai == @game.bakaze ? 1 : 0) + (pai == @reacher.jikaze ? 1 : 0)
              end
            end
            
        end

        StoredKyoku = Struct.new(:scenes)
        StoredScene = Struct.new(:candidates)
        DecisionNode = Struct.new(
            :average_prob, :conf_interval, :num_samples, :feature_name, :positive, :negative)
        
        class DecisionTree
            
            def initialize(path)
              @root = open(path, "rb"){ |f| Marshal.load(f) }
            end
            
            def estimate_prob(scene, pai)
              feature_vector = scene.feature_vector(pai.remove_red())
              p [pai, DangerEstimator.feature_vector_to_str(feature_vector)]
              node = @root
              while node.feature_name
                if DangerEstimator.get_feature_value(feature_vector, node.feature_name)
                  node = node.positive
                else
                  node = node.negative
                end
              end
              return node.average_prob
            end
            
        end
        
        def initialize()
          @min_gap = 0.0
        end
        
        attr_accessor(:verbose)
        attr_accessor(:min_gap)
        
        def extract_features_from_files(input_paths, output_path)
          $stderr.puts("%d files." % input_paths.size)
          open(output_path, "wb") do |f|
            meta_data = {
              :feature_names => Scene.feature_names,
            }
            Marshal.dump(meta_data, f)
            @stored_kyokus = []
            input_paths.enum_for(:each_with_progress).each_with_index() do |path, i|
              if i % 100 == 0 && i > 0
                Marshal.dump(@stored_kyokus, f)
                @stored_kyokus.clear()
              end
              extract_features_from_file(path)
            end
            Marshal.dump(@stored_kyokus, f)
          end
        end
        
        def extract_features_from_file(input_path)
          begin
            stored_kyoku = nil
            reacher = nil
            waited = nil
            prereach_sutehais = nil
            skip = false
            archive = Archive.new(input_path)
            archive.play() do |action|
              archive.dump_action(action) if self.verbose
              case action.type
                
                when :start_kyoku
                  stored_kyoku = StoredKyoku.new([])
                  reacher = nil
                  skip = false
                
                when :end_kyoku
                  next if skip
                  raise("should not happen") if !stored_kyoku
                  @stored_kyokus.push(stored_kyoku)
                  stored_kyoku = nil
                
                when :reach_accepted
                  if ["ASAPIN", "（≧▽≦）"].include?(action.actor.name) || reacher
                    skip = true
                  end
                  next if skip
                  reacher = action.actor
                  waited = TenpaiAnalysis.new(action.actor.tehais).waited_pais
                  prereach_sutehais = reacher.sutehais.dup()
                
                when :dahai
                  next if skip || !reacher || action.actor.reach?
                  scene = Scene.new(archive, action.actor, action.pai, reacher, prereach_sutehais)
                  stored_scene = StoredScene.new([])
                  #p [:candidates, action.actor, reacher, scene.candidates.join(" ")]
                  puts("reacher: %d" % reacher.id) if self.verbose
                  for pai in scene.candidates
                    hit = waited.include?(pai)
                    feature_vector = scene.feature_vector(pai)
                    stored_scene.candidates.push([feature_vector, hit])
                    if self.verbose
                      puts("candidate %s: hit=%d, %s" % [
                          pai,
                          hit ? 1 : 0,
                          DangerEstimator.feature_vector_to_str(feature_vector)])
                    end
                  end
                  stored_kyoku.scenes.push(stored_scene)
                  
              end
            end
          rescue Exception
            $stderr.puts("at #{input_path}")
            raise()
          end
        end
        
        def calculate_single_probabilities(features_path)
          criteria = Scene.feature_names.map(){ |s| [{s => false}, {s => true}] }.flatten()
          calculate_probabilities(features_path, criteria)
        end
        
        def generate_decision_tree(features_path, base_criterion = {}, base_node = nil, root = nil)
          p [:generate_decision_tree, base_criterion]
          targets = {}
          criteria = []
          criteria.push(base_criterion) if !base_node
          for name in Scene.feature_names
            next if base_criterion.has_key?(name)
            negative_criterion = base_criterion.merge({name => false})
            positive_criterion = base_criterion.merge({name => true})
            targets[name] = [negative_criterion, positive_criterion]
            criteria.push(negative_criterion, positive_criterion)
          end
          node_map = calculate_probabilities(features_path, criteria)
          base_node = node_map[base_criterion] if !base_node
          root = base_node if !root
          gaps = {}
          for name, (negative_criterion, positive_criterion) in targets
            negative = node_map[negative_criterion]
            positive = node_map[positive_criterion]
            next if !positive || !negative
            if positive.average_prob >= negative.average_prob
              gap = positive.conf_interval[0] - negative.conf_interval[1]
            else
              gap = negative.conf_interval[0] - positive.conf_interval[1]
            end
            p [name, gap]
            gaps[name] = gap if gap > @min_gap
          end
          max_name = gaps.keys.max_by(){ |s| gaps[s] }
          p [:max_name, max_name]
          if max_name
            (negative_criterion, positive_criterion) = targets[max_name]
            base_node.feature_name = max_name
            base_node.negative = node_map[negative_criterion]
            base_node.positive = node_map[positive_criterion]
            render_decision_tree(root, "all")
            generate_decision_tree(features_path, negative_criterion, base_node.negative, root)
            generate_decision_tree(features_path, positive_criterion, base_node.positive, root)
          end
          return base_node
        end
        
        def render_decision_tree(node, label, indent = 0)
          puts("%s%s : %.2f [%.2f, %.2f] (%d samples)" %
              ["  " * indent,
               label,
               node.average_prob * 100.0,
               node.conf_interval[0] * 100.0,
               node.conf_interval[1] * 100.0,
               node.num_samples])
          if node.feature_name
            for value, child in [[false, node.negative], [true, node.positive]].
                sort_by(){ |v, c| c.average_prob }
              render_decision_tree(child, "%s = %p" % [node.feature_name, value], indent + 1)
            end
          end
        end
        
        def calculate_probabilities(features_path, criteria)
          create_kyoku_probs_map(features_path, criteria)
          aggregate_pribabilities(criteria)
        end
        
        def create_kyoku_probs_map(features_path, criteria)
          
          @kyoku_probs_map = {}
          
          criterion_masks = {}
          for criterion in criteria
            positive_ary = [false] * Scene.feature_names.size
            negative_ary = [true] * Scene.feature_names.size
            for name, value in criterion
              index = Scene.feature_names.index(name)
              if value
                positive_ary[index] = true
              else
                negative_ary[index] = false
              end
            end
            criterion_masks[criterion] = [
              DangerEstimator.bool_array_to_bit_vector(positive_ary),
              DangerEstimator.bool_array_to_bit_vector(negative_ary),
            ]
          end
          
          open(features_path, "rb") do |f|
            meta_data = Marshal.load(f)
            if meta_data[:feature_names] != Scene.feature_names
              raise("feature set has been changed")
            end
            f.with_progress() do
              begin
                while true
                  stored_kyokus = Marshal.load(f)
                  for stored_kyoku in stored_kyokus
                    update_metrics_for_kyoku(stored_kyoku, criterion_masks)
                  end
                end
              rescue EOFError
              end
            end
          end
          
        end
        
        def aggregate_pribabilities(criteria)
          result = {}
          for criterion in criteria
            kyoku_probs = @kyoku_probs_map[criterion.object_id]
            next if !kyoku_probs
            result[criterion] = node = DecisionNode.new(
                kyoku_probs.inject(:+) / kyoku_probs.size,
                confidence_interval(kyoku_probs),
                kyoku_probs.size)
            puts("%p\n  %.2f [%.2f, %.2f] (%d samples)" %
                [criterion,
                 node.average_prob * 100.0,
                 node.conf_interval[0] * 100.0,
                 node.conf_interval[1] * 100.0,
                 node.num_samples])
          end
          return result
        end
        
        def update_metrics_for_kyoku(stored_kyoku, criterion_masks)
          scene_prob_sums = Hash.new(0.0)
          scene_counts = Hash.new(0)
          for stored_scene in stored_kyoku.scenes
            pai_freqs = {}
            for feature_vector, hit in stored_scene.candidates
              for criterion, (positive_mask, negative_mask) in criterion_masks
                if match?(feature_vector, positive_mask, negative_mask)
                  # Uses object_id as key for efficiency.
                  pai_freqs[criterion.object_id] ||= Hash.new(0)
                  pai_freqs[criterion.object_id][hit] += 1
                end
              end
              #p [pai, hit, feature_vector]
            end
            for criterion_id, freqs in pai_freqs
              scene_prob = freqs[true].to_f() / (freqs[false] + freqs[true])
              #p [:scene_prob, criterion, scene_prob]
              scene_prob_sums[criterion_id] += scene_prob
              scene_counts[criterion_id] += 1
            end
          end
          for criterion_id, count in scene_counts
            kyoku_prob = scene_prob_sums[criterion_id] / count
            #p [:kyoku_prob, criterion, kyoku_prob]
            @kyoku_probs_map[criterion_id] ||= []
            @kyoku_probs_map[criterion_id].push(kyoku_prob)
          end
        end
        
        def match?(feature_vector, positive_mask, negative_mask)
          return (feature_vector & positive_mask) == positive_mask &&
              (feature_vector | negative_mask) == negative_mask
        end
        
        # Uses bootstrap resampling.
        def confidence_interval(samples, conf_level = 0.95)
          num_tries = 1000
          averages = []
          num_tries.times() do
            sum = 0.0
            (samples.size + 2).times() do
              idx = rand(samples.size + 2)
              case idx
                when samples.size
                  sum += 0.0
                when samples.size + 1
                  sum += 1.0
                else
                  sum += samples[idx]
              end
            end
            averages.push(sum / (samples.size + 2))
          end
          averages.sort!()
          margin = (1.0 - conf_level) / 2
          return [
            averages[(num_tries * margin).to_i()],
            averages[(num_tries * (1.0 - margin)).to_i()],
          ]
        end
        
        def self.bool_array_to_bit_vector(bool_array)
          vector = 0
          bool_array.reverse_each() do |value|
            vector <<= 1
            vector |= 1 if value
          end
          return vector
        end

        def self.feature_vector_to_str(feature_vector)
          return (0...Scene.feature_names.size).select(){ |i| feature_vector[i] != 0 }.
              map(){ |i| Scene.feature_names[i] }.join(" ")
        end
        
        def self.get_feature_value(feature_vector, feature_name)
          return feature_vector[Scene.feature_names.index(feature_name)] != 0
        end
        
    end


    # For compatibility.
    # TODO Remove this.
    DecisionNode = DangerEstimator::DecisionNode
    
    
end
