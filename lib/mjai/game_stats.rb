# coding: utf-8

require "mjai/archive"
require "mjai/confidence_interval"


module Mjai

    class GameStats

        YAKU_JA_NAMES = {
          :menzenchin_tsumoho => "面前清自摸和", :reach => "立直", :ippatsu => "一発",
          :chankan => "槍槓", :rinshankaiho => "嶺上開花", :haiteiraoyue => "海底摸月",
          :hoteiraoyui => "河底撈魚", :pinfu => "平和", :tanyaochu => "断么九",
          :ipeko => "一盃口", :jikaze => "面風牌", :bakaze => "圏風牌",
          :sangenpai => "三元牌", :double_reach => "ダブル立直", :chitoitsu => "七対子",
          :honchantaiyao => "混全帯么九", :ikkitsukan => "一気通貫",
          :sanshokudojun => "三色同順", :sanshokudoko => "三色同刻", :sankantsu => "三槓子",
          :toitoiho => "対々和", :sananko => "三暗刻", :shosangen => "小三元",
          :honroto => "混老頭", :ryanpeko => "二盃口", :junchantaiyao => "純全帯么九",
          :honiso => "混一色", :chiniso => "清一色", :renho => "人和", :tenho => "天和",
          :chiho => "地和", :daisangen => "大三元", :suanko => "四暗刻",
          :tsuiso => "字一色", :ryuiso => "緑一色", :chinroto => "清老頭",
          :churenpoton => "九蓮宝燈", :kokushimuso => "国士無双",
          :daisushi => "大四喜", :shosushi => "小四喜", :sukantsu => "四槓子",
          :dora => "ドラ", :uradora => "裏ドラ", :akadora => "赤ドラ",
        }

        def self.print(mjson_paths)

          num_errors = 0
          name_to_ranks = {}
          name_to_scores = {}
          name_to_kyoku_count = {}
          name_to_hora_count = {}
          name_to_yaku_stats = {}
          name_to_dora_stats = {}
          name_to_hoju_count = {}
          name_to_furo_kyoku_count = {}
          name_to_reach_count = {}
          name_to_hora_points = {}

          for path in mjson_paths

            archive = Archive.load(path)
            first_action = archive.raw_actions[0]
            last_action = archive.raw_actions[-1]
            if !last_action || last_action.type != :end_game
              num_errors += 1
              next
            end
            archive.do_action(first_action)

            scores = last_action.scores
            id_to_name = first_action.names

            chicha_id = archive.raw_actions[1].oya.id
            ranked_player_ids =
                (0...4).sort_by(){ |i| [-scores[i], (i + 4 - chicha_id) % 4] }
            for r in 0...4
              name = id_to_name[ranked_player_ids[r]]
              name_to_ranks[name] ||= []
              name_to_ranks[name].push(r + 1)
            end

            for p in 0...4
              name = id_to_name[p]
              name_to_scores[name] ||= []
              name_to_scores[name].push(scores[p])
            end

            # Kyoku specific fields.
            id_to_done_reach = {}
            id_to_done_furo = {}
            for raw_action in archive.raw_actions
              if raw_action.type == :hora
                name = id_to_name[raw_action.actor.id]
                name_to_hora_count[name] ||= 0
                name_to_hora_count[name] += 1
                name_to_hora_points[name] ||= []
                name_to_hora_points[name].push(raw_action.hora_points)
                for yaku, fan in raw_action.yakus
                  if yaku == :dora || yaku == :akadora || yaku == :uradora
                    name_to_dora_stats[name] ||= {}
                    name_to_dora_stats[name][yaku] ||= 0
                    name_to_dora_stats[name][yaku] += fan
                    next
                  end
                  name_to_yaku_stats[name] ||= {}
                  name_to_yaku_stats[name][yaku] ||= 0
                  name_to_yaku_stats[name][yaku] += 1
                end
                if raw_action.actor.id != raw_action.target.id
                  target_name = id_to_name[raw_action.target.id]
                  name_to_hoju_count[target_name] ||= 0
                  name_to_hoju_count[target_name] += 1
                end
              end
              if raw_action.type == :reach_accepted
                id_to_done_reach[raw_action.actor.id] = true
              end
              if raw_action.type == :pon
                id_to_done_furo[raw_action.actor.id] = true
              end
              if raw_action.type == :chi
                id_to_done_furo[raw_action.actor.id] = true
              end
              if raw_action.type == :daiminkan
                id_to_done_furo[raw_action.actor.id] = true
              end
              if raw_action.type == :end_kyoku
                for p in 0...4
                  name = id_to_name[p]

                  if id_to_done_furo[p]
                    name_to_furo_kyoku_count[name] ||= 0
                    name_to_furo_kyoku_count[name] += 1
                  end
                  if id_to_done_reach[p]
                    name_to_reach_count[name] ||= 0
                    name_to_reach_count[name] += 1
                  end
                  
                  name_to_kyoku_count[name] ||= 0
                  name_to_kyoku_count[name] += 1
                end

                # Reset kyoku specific fields.
                id_to_done_furo = {}
                id_to_done_reach = {}
              end
            end
          end
          if num_errors > 0
            puts("errors: %d / %d" % [num_errors, mjson_paths.size])
          end

          puts("Ranks:")
          for name, ranks in name_to_ranks.sort
            rank_conf_interval = ConfidenceInterval.calculate(ranks, :min => 1.0, :max => 4.0)
            puts("  %s: %.3f [%.3f, %.3f]" % [
                name,
                ranks.inject(0, :+).to_f() / ranks.size,
                rank_conf_interval[0],
                rank_conf_interval[1],
            ])
          end

          puts("Scores:")
          for name, scores in name_to_scores.sort
            puts("  %s: %d" % [
                name,
                scores.inject(0, :+).to_i() / scores.size,
            ])
          end

          puts("Hora rates:")
          for name, hora_count in name_to_hora_count.sort
            puts("  %s: %.1f%%" % [
                name,
                100.0 * hora_count / name_to_kyoku_count[name]
            ])
          end

          puts("Hoju rates:")
          for name, hoju_count in name_to_hoju_count.sort
            puts("  %s: %.1f%%" % [
                name,
                100.0 * hoju_count / name_to_kyoku_count[name]
            ])
          end

          puts("Furo rates:")
          for name, furo_kyoku_count in name_to_furo_kyoku_count.sort
            puts("  %s: %.1f%%" % [
                name,
                100.0 * furo_kyoku_count / name_to_kyoku_count[name]
            ])
          end

          puts("Reach rates:")
          for name, reach_count in name_to_reach_count.sort
            puts("  %s: %.1f%%" % [
                name,
                100.0 * reach_count / name_to_kyoku_count[name]
            ])
          end

          puts("Average hora points:")
          for name, hora_points in name_to_hora_points.sort
            puts("  %s: %d" % [
                name,
                hora_points.inject(0, :+).to_i() / hora_points.size,
            ])
          end

          puts("Yaku stats:")
          for name, yaku_stats in name_to_yaku_stats.sort
            hora_count = name_to_hora_count[name]
            puts("  %s (%d horas):" % [name, hora_count])
            for yaku, count in yaku_stats.sort_by{|yaku, count| -count}
              yaku_name = YAKU_JA_NAMES[yaku]
              puts("    %s: %d (%.1f%%)" % [yaku_name, count, 100.0 * count / hora_count])
            end
          end

          puts("Dora stats:")
          for name, dora_stats in name_to_dora_stats.sort
            hora_count = name_to_hora_count[name]
            puts("  %s (%d horas):" % [name, hora_count])
            for dora, count in dora_stats.sort_by{|dora, count| -count}
              dora_name = YAKU_JA_NAMES[dora]
              puts("    %s: %d (%.3f/hora)" % [dora_name, count, count.to_f() / hora_count])
            end
          end

        end
        
    end

end
