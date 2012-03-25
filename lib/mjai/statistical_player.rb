require "mjai/pai"
require "mjai/player"
require "mjai/shanten_analysis"
require "mjai/danger_estimator"
require "mjai/hora_probability_estimator"
require "mjai/hora_points_estimate"


module Mjai

    class StatisticalPlayer < Player
        
        DahaiEval = Struct.new(:cheapness, :prob_info, :points_estimate, :expected_points, :score)
        
        class Scene
            
            def initialize(params)
              
              visible_set = params[:visible_set]
              context = params[:context]
              hora_prob_estimator = params[:hora_prob_estimator]
              num_remain_turns = params[:num_remain_turns]
              current_shanten_analysis = params[:current_shanten_analysis]
              furos = params[:furos]
              sutehai_cands = params[:sutehai_cands]
              score_type = params[:score_type]
              
              tehais = current_shanten_analysis.pais
              scene = hora_prob_estimator.get_scene({
                  :visible_set => visible_set,
                  :num_remain_turns => num_remain_turns,
                  :current_shanten => current_shanten_analysis.shanten,
              })
              
              @evals = {}
              for pai in sutehai_cands
                #p [:pai, pai]
                eval = DahaiEval.new()
                if pai
                  idx = tehais.index(pai)
                  remains = tehais.dup()
                  remains.delete_at(idx)
                  shanten_analysis = ShantenAnalysis.new(
                      remains, current_shanten_analysis.shanten, [:normal])
                  eval.cheapness = pai.type == "t" ? 5 : (5 - pai.number).abs
                else
                  remains = tehais
                  shanten_analysis = current_shanten_analysis
                end
                # TODO Reuse shanten_analysis
                eval.prob_info = scene.get_tehais(remains)
                eval.points_estimate = HoraPointsEstimate.new({
                    :shanten_analysis => shanten_analysis,
                    :furos => furos,
                    :context => context,
                })
                eval.expected_points =
                    eval.points_estimate.average_points * eval.prob_info.hora_prob
                case score_type
                  when :expected_points
                    eval.score =
                        [eval.expected_points, eval.prob_info.progress_prob, eval.cheapness]
                  when :progress_prob
                    eval.score = [eval.prob_info.progress_prob, eval.cheapness]
                  else
                    raise("unknown score_type")
                end
                if eval.prob_info.progress_prob > 0.0
                  puts("%s: ept=%d ppr=%.3f hpr=%.3f apt=%d (%s)" % [
                      pai,
                      eval.expected_points,
                      eval.prob_info.progress_prob,
                      eval.prob_info.hora_prob,
                      eval.points_estimate.average_points,
                      eval.points_estimate.yaku_debug_str,
                  ])
                end
                @evals[pai] = eval
              end
              
              max_score = @evals.values.map(){ |e| e.score }.max
              @best_dahais = @evals.keys.select(){ |pai| @evals[pai].score == max_score }
              @best_dahai = @best_dahais.sample
              
            end
            
            attr_reader(:best_dahais, :best_dahai, :evals)
            
        end
        
        def initialize(params)
          super()
          @score_type = params[:score_type]
          @danger_tree = DangerEstimator::DecisionTree.new("data/danger.all.tree")
          @hora_prob_estimator = HoraProbabilityEstimator.new("data/hora_prob.marshal")
        end
        
        def respond_to_action(action)
          
          if !action.actor
            
            case action.type
              when :start_kyoku
                @prereach_sutehais_map = {}
            end
            
          elsif action.actor == self
            
            case action.type
              
              when :tsumo, :chi, :pon, :reach
                
                current_shanten_analysis = ShantenAnalysis.new(self.tehais, nil, [:normal])
                current_shanten = current_shanten_analysis.shanten
                if can_hora?(current_shanten_analysis)
                  return create_action({
                      :type => :hora,
                      :target => action.actor,
                      :pai => action.pai,
                  })
                elsif can_reach?(current_shanten_analysis)
                  return create_action({:type => :reach})
                elsif self.reach?
                  return create_action({:type => :dahai, :pai => action.pai})
                end
                p [:shanten, current_shanten]
                
                if current_shanten == 0
                  sutehai_cands = self.possible_dahais
                else
                  safe_probs = {}
                  for pai in self.possible_dahais
                    safe_probs[pai] = 1.0
                  end
                  has_reacher = false
                  for player in self.game.players
                    if player != self && player.reach?
                      p [:reacher, player, @prereach_sutehais_map[player]]
                      has_reacher = true
                      scene = DangerEstimator::Scene.new(
                          self.game, self, nil, player, @prereach_sutehais_map[player])
                      for pai in safe_probs.keys
                        if scene.anpai?(pai)
                          safe_prob = 1.0
                        else
                          safe_prob = 1.0 - @danger_tree.estimate_prob(scene, pai)
                        end
                        p [:safe_prob, pai, safe_prob]
                        safe_probs[pai] *= safe_prob
                      end
                    end
                  end
                  max_safe_prob = safe_probs.values.max
                  sutehai_cands = safe_probs.keys.select(){ |pai| safe_probs[pai] == max_safe_prob }
                end
                p [:sutehai_cands, sutehai_cands]
                
                scene = get_scene({
                    :current_shanten_analysis => current_shanten_analysis,
                    :sutehai_cands => sutehai_cands,
                })
                
                p [:dahai, scene.best_dahai]
                #if self.id == 0
                #if has_reacher
                #  print("> ")
                #  gets()
                #end
                
                return create_action({
                    :type => :dahai,
                    :pai => scene.best_dahai,
                })
                
            end
            
          else  # action.actor != self
            
            case action.type
              when :dahai
                if self.can_hora?
                  return create_action({
                      :type => :hora,
                      :target => action.actor,
                      :pai => action.pai,
                  })
                else
                  furo_actions = self.possible_furo_actions
                  if !furo_actions.empty? &&
                      !self.game.players.any?(){ |pl| pl != self && pl.reach? }
                    current_shanten_analysis = ShantenAnalysis.new(self.tehais, nil, [:normal])
                    current_scene = get_scene({
                        :current_shanten_analysis => current_shanten_analysis,
                        :sutehai_cands => [nil],
                    })
                    current_expected_points = current_scene.evals[nil].expected_points
                    for action in furo_actions
                      next if action.type == :daiminkan  # TODO Implement later
                      remains = self.tehais.dup()
                      for pai in action.consumed
                        remains.delete_at(remains.index(pai))
                      end
                      furo = Furo.new({
                          :type => action.type,
                          :taken => action.pai,
                          :consumed => action.consumed,
                          :target => action.target,
                      })
                      shanten_analysis_with_furo = ShantenAnalysis.new(remains, nil, [:normal])
                      scene_with_furo = get_scene({
                          :current_shanten_analysis => shanten_analysis_with_furo,
                          :furos => self.furos + [furo],
                          :sutehai_cands => remains.uniq(),
                      })
                      best_eval =
                          scene_with_furo.best_dahais.
                          map(){ |pai| scene_with_furo.evals[pai] }.
                          max_by(){ |e| e.expected_points }
                      expected_points_with_furo = best_eval.expected_points
                      puts("furo_cand: %s" % action)
                      puts("  shanten: %d -> %d" % [
                          current_shanten_analysis.shanten,
                          shanten_analysis_with_furo.shanten,
                      ])
                      puts("  ept: %d -> %d" % [current_expected_points, expected_points_with_furo])
                      if expected_points_with_furo > current_expected_points
                        #gets()  # kari
                        return action
                      end
                    end
                  end
                end
              when :reach_accepted
                @prereach_sutehais_map[action.actor] = action.actor.sutehais.dup()
            end
            
          end
          
          return nil
        end
        
        def get_scene(params)
          visible = []
          visible += self.game.doras
          visible += self.tehais
          for player in self.game.players
            visible += player.ho + player.furos.map(){ |f| f.pais }.flatten()
          end
          visible_set = to_pai_set(visible)
          default_params = {
            :visible_set => visible_set,
            :context => self.context,
            :hora_prob_estimator => @hora_prob_estimator,
            :num_remain_turns => self.game.num_pipais / 4,
            :furos => self.furos,
            :score_type => @score_type,
          }
          params = default_params.merge(params)
          # pp params.reject(){ |k, v| [:visible_set, :hora_prob_estimator, :context].include?(k) }
          return Scene.new(params)
        end
        
        # This is too slow but left here as most precise baseline.
        def get_hora_prob_with_monte_carlo(tehais, visible_set, num_visible)
          invisibles = []
          for pai in self.game.all_pais.uniq
            next if pai.red?
            (4 - visible_set[pai]).times() do
              invisibles.push(pai)
            end
          end
          num_tsumos = game.num_pipais / 4
          hora_freq = 0
          num_tries = 1000
          num_tries.times() do
            tsumos = invisibles.sample(num_tsumos)
            pais = tehais + tsumos
            #p [:pais, pais.sort().join(" ")]
            can_be = can_be_hora?(pais)
            #p [:can_be, can_be]
            next if !can_be
            shanten = ShantenAnalysis.new(pais, -1, [:normal], 14, false)
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

    class MockGame
        
        def initialize()
          pais = (0...4).map() do |i|
            ["m", "p", "s"].map(){ |t| (1..9).map(){ |n| Pai.new(t, n, n == 5 && i == 0) } } +
                (1..7).map(){ |n| Pai.new("t", n) }
          end
          @all_pais = pais.flatten().sort()
        end
        
        attr_reader(:all_pais)
        
    end

end
