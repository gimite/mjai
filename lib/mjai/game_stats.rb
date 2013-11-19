require "mjai/archive"
require "mjai/confidence_interval"


module Mjai

    class GameStats

        def self.print(mjson_paths)
          num_errors = 0
          name_to_ranks = {}
          for path in mjson_paths
            archive = Archive.load(path)
            first_action = archive.raw_actions[0]
            last_action = archive.raw_actions[-1]
            archive.do_action(first_action)
            if last_action.type != :end_game
              num_errors += 1
              next
            end
            chicha_id = archive.raw_actions[1].oya.id
            ranked_player_ids =
                (0...4).sort_by(){ |i| [-last_action.scores[i], (i + 4 - chicha_id) % 4] }
            for r in 0...4
              name = first_action.names[ranked_player_ids[r]]
              name_to_ranks[name] ||= []
              name_to_ranks[name].push(r + 1)
            end
          end
          if num_errors > 0
            puts("errors: %d / %d" % [num_errors, mjson_paths.size])
          end
          puts("ranks:")
          for name, ranks in name_to_ranks
            rank_conf_interval = ConfidenceInterval.calculate(ranks, :min => 1.0, :max => 4.0)
            puts("  %s: %.3f [%.3f, %.3f]" % [
                name,
                ranks.inject(0, :+).to_f() / ranks.size,
                rank_conf_interval[0],
                rank_conf_interval[1],
            ])
          end
        end

    end

end
