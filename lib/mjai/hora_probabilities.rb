# coding: utf-8

require "with_progress"

require "mjai/archive"
require "mjai/shanten_analysis"


module Mjai
    
    class HoraProbabilities
        
        Criterion = Struct.new(:num_remain_turns, :shanten)
        Metrics = Struct.new(:hora_prob, :quick_hora_prob, :num_samples)
        
        def estimate(archive_paths)
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
                  #break  # kari
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
          return metrics_map
        end
        
        def dump_metrics_map(metrics_map)
          puts("\#turns\tshanten\thora_p\tquick_p\tsamples")
          for criterion, metrics in metrics_map.sort_by(){ |c, m| [c.shanten, c.num_remain_turns] }
            puts("%d\t%d\t%.3f\t%.3f\t%d" % [
                criterion.num_remain_turns,
                criterion.shanten,
                metrics.hora_prob,
                metrics.quick_hora_prob,
                metrics.num_samples,
            ])
          end
        end
        
    end
    
end
