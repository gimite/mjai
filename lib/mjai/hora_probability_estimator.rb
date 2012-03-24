# coding: utf-8

require "set"

require "with_progress"

require "mjai/archive"
require "mjai/shanten_analysis"


module Mjai
    
    class HoraProbabilityEstimator
        
        Criterion = Struct.new(:num_remain_turns, :shanten)
        Metrics = Struct.new(:hora_prob, :quick_hora_prob, :num_samples)
        
        class Scene
            
            def initialize(estimator, params)
              @estimator = estimator
              @visible_set = params[:visible_set]
              @num_invisible = 4 * (9 * 3 + 7) - @visible_set.values.inject(0, :+)
              @num_remain_turns = params[:num_remain_turns]
              @current_shanten = params[:current_shanten]
            end
            
            attr_reader(
                :estimator, :visible_set, :num_invisible,
                :num_remain_turns, :current_shanten)
            
            def get_tehais(remains)
              return Tehais.new(self, remains)
            end
            
        end
        
        class Tehais
            
            def initialize(scene, remains)
              @scene = scene
              @remains = remains
              @shanten_analysis = ShantenAnalysis.new(@remains, @scene.current_shanten, [:normal])
              @progress_prob = get_progress_prob()
              @hora_prob = get_hora_prob()
            end
            
            attr_reader(:progress_prob, :hora_prob)
            
            def get_hora_prob(num_remain_turns = @scene.num_remain_turns)
              return 0.0 if @progress_prob == 0.0
              return 0.0 if num_remain_turns < 0
              shanten = @shanten_analysis.shanten
              hora_prob_on_prog =
                  @scene.estimator.get_hora_prob(num_remain_turns - 2, shanten - 1)
              hora_prob_on_no_prog =
                  get_hora_prob(num_remain_turns - 2)
              hora_prob = @progress_prob * hora_prob_on_prog +
                  (1.0 - @progress_prob) * hora_prob_on_no_prog
              #p [:hora_prob, num_remain_turns, shanten, @progress_prob,
              #    hora_prob, hora_prob_on_prog, hora_prob_on_no_prog]
              return hora_prob
            end
            
            # Probability to decrease >= 1 shanten in 2 turns.
            def get_progress_prob()
              
              if @shanten_analysis.shanten > @scene.current_shanten
                return 0.0
              end
              
              #p [:remains, @remains.join(" ")]
              candidates = get_required_pais_candidates()
              
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
              double_cands = double_cands.select() do |pais|
                pais.all?(){ |pai| !single_cands.include?(pai) }
              end
              #p [:single, single_cands.sort().join(" ")]
              #p [:double, double_cands]
              
              # (p, *) or (*, p)
              any_single_prob = single_cands.map(){ |pai| get_pai_prob(pai) }.inject(0.0, :+)
              total_prob = 1.0 - (1.0 - any_single_prob) ** 2
              
              #p [:single_total, total_prob]
              for pai1, pai2 in double_cands
                prob1 = get_pai_prob(pai1)
                #p [:prob, pai1, state]
                prob2 = get_pai_prob(pai2)
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
            def get_required_pais_candidates()
              result = Set.new()
              for mentsus in @shanten_analysis.combinations
                for janto_index in [nil] + (0...mentsus.size).to_a()
                  t_mentsus = mentsus.dup()
                  if janto_index
                    next if ![:toitsu, :kotsu].include?(mentsus[janto_index][0])
                    t_mentsus.delete_at(janto_index)
                  end
                  t_shanten =
                      -1 +
                      (janto_index ? 0 : 1) +
                      t_mentsus.map(){ |t, ps| 3 - ps.size }.sort()[0, 4].inject(0, :+)
                  #p [:t_shanten, janto_index, t_shanten, @shanten_analysis.shanten]
                  next if t_shanten != @shanten_analysis.shanten
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
            
            def get_pai_prob(pai)
              return (4 - @scene.visible_set[pai]).to_f() / @scene.num_invisible
            end
            
        end
        
        def self.estimate(archive_paths, output_metrics_path)
          freqs_map = {}
          archive_paths.each_with_progress() do |path|
            p [:path, path]
            archive = Archive.load(path)
            criteria_map = nil
            winners = nil
            archive.each_action() do |action|
              next if action.actor && ["ASAPIN", "（≧▽≦）"].include?(action.actor.name)
              archive.dump_action(action)
              case action.type
                when :start_kyoku
                  criteria_map = {}
                  winners = []
                when :dahai
                  shanten_analysis = ShantenAnalysis.new(
                      action.actor.tehais,
                      nil,
                      ShantenAnalysis::ALL_TYPES,
                      action.actor.tehais.size,
                      false)
                  criterion = Criterion.new(
                      archive.num_pipais / 4.0,
                      ShantenAnalysis.new(action.actor.tehais).shanten)
                  p [:criterion, criterion]
                  criteria_map[action.actor] ||= []
                  criteria_map[action.actor].push(criterion)
                when :hora
                  winners.push(action.actor)
                when :end_kyoku
                  num_remain_turns = archive.num_pipais / 4.0
                  for player, criteria in criteria_map
                    for criterion in criteria
                      if winners.include?(player)
                        if criterion.num_remain_turns - num_remain_turns <= 2.0
                          result = :quick_hora
                        else
                          result = :slow_hora
                        end
                      else
                        result = :no_hora
                      end
                      normalized_criterion = Criterion.new(
                          criterion.num_remain_turns.to_i(),
                          criterion.shanten)
                      #p [player, normalized_criterion, result]
                      freqs_map[normalized_criterion] ||= Hash.new(0)
                      freqs_map[normalized_criterion][:total] += 1
                      freqs_map[normalized_criterion][result] += 1
                    end
                  end
              end
            end
          end
          metrics_map = {}
          for criterion, freqs in freqs_map
            metrics_map[criterion] = Metrics.new(
                (freqs[:quick_hora] + freqs[:slow_hora]).to_f() / freqs[:total],
                freqs[:quick_hora].to_f() / freqs[:total],
                freqs[:total])
          end
          open(output_metrics_path, "wb") do |f|
            Marshal.dump(metrics_map, f)
          end
        end
        
        def initialize(metrics_path)
          open(metrics_path, "rb") do |f|
            @metrics_map = Marshal.load(f)
          end
          adjust()
        end
        
        def get_scene(params)
          return Scene.new(self, params)
        end
        
        def get_hora_prob(num_remain_turns, shanten)
          if shanten <= -1
            return 1.0
          elsif num_remain_turns < 0
            return 0.0
          else
            return @metrics_map[Criterion.new(num_remain_turns, shanten)].hora_prob
          end
        end
        
        def dump_metrics_map()
          puts("\#turns\tshanten\thora_p\tsamples")
          for criterion, metrics in @metrics_map.sort_by(){ |c, m| [c.num_remain_turns, c.shanten] }
          #for criterion, metrics in @metrics_map.sort_by(){ |c, m| [c.shanten, c.num_remain_turns] }
            puts("%d\t%d\t%.3f\t%p" % [
                criterion.num_remain_turns,
                criterion.shanten,
                metrics.hora_prob,
                metrics.num_samples,
            ])
          end
        end
        
        def adjust()
          for shanten in 0..6
            adjust_for_sequence(17.downto(0).map(){ |n| Criterion.new(n, shanten) })
          end
          for num_remain_turns in 0..17
            adjust_for_sequence((0..6).map(){ |s| Criterion.new(num_remain_turns, s) })
          end
        end
        
        def adjust_for_sequence(criteria)
          prev_prob = 1.0
          for criterion in criteria
            metrics = @metrics_map[criterion]
            if !metrics || metrics.hora_prob > prev_prob
              #p [criterion, metrics && metrics.hora_prob, prev_prob]
              @metrics_map[criterion] = Metrics.new(prev_prob, nil, nil)
            end
            prev_prob = @metrics_map[criterion].hora_prob
          end
        end
        
    end
    
    # For compatibility.
    # TODO Remove this.
    HoraProbabilities = HoraProbabilityEstimator
    
end
