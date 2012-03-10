require "mjai/action"
require "mjai/pai"
require "mjai/furo"


module Mjai
    
    class Game
        
        def initialize(players)
          @game_type = :one_kyoku
          @players = players
          for player in @players
            player.game = self
          end
          @bakaze = nil
          @oya = nil
          @dora_markers = nil
          @previous_action = nil
        end
        
        attr_reader(:players)
        attr_accessor(:game_type)
        attr_reader(:all_pais)
        attr_reader(:bakaze)
        attr_reader(:oya)
        attr_reader(:honba)
        attr_reader(:dora_markers)  # ドラ表示牌
        attr_reader(:previous_action)
        attr_reader(:all_pais)
        attr_reader(:num_pipais)
        attr_accessor(:last)  # kari
        
        def on_action(&block)
          @on_action = block
        end
        
        def do_action(action)
          
          if action.is_a?(Hash)
            action = Action.new(action)
          end
          @actor = action.actor if action.actor
          
          case action.type
            when :start_game
              # TODO change this by red config
              pais = (0...4).map() do |i|
                ["m", "p", "s"].map(){ |t| (1..9).map(){ |n| Pai.new(t, n, n == 5 && i == 0) } } +
                    (1..7).map(){ |n| Pai.new("t", n) }
              end
              @all_pais = pais.flatten().sort()
            when :start_kyoku
              if action.oya == @oya  # 連荘
                @honba += 1
              else
                if action.oya.id == 0
                  @bakaze = @bakaze ? @bakaze.succ : Pai.new("E")
                end
                @honba = 0
              end
              @oya = action.oya
              @dora_markers = [action.dora_marker]
              @num_pipais = @all_pais.size - 13 * 4 - 14
            when :tsumo
              @num_pipais -= 1
            when :dora
              @dora_markers.push(action.dora_marker)
          end
          
          actions = (0...4).map(){ |i| action_in_view(action, i) }
          for i in 0...4
            @players[i].process_action(actions[i])
          end
          
          @on_action.call(action) if @on_action
          
          responses = (0...4).map(){ |i| @players[i].respond_to_action(actions[i]) }
          validate_responses(responses, action)
          
          @previous_action = action
          return responses
          
        end
        
        def action_in_view(action, player_id)
          player = @players[player_id]
          case action.type
            when :start_game
              return Action.new({:type => :start_game, :id => player_id, :names => action.names})
            when :haipai
              pais = action.actor == player ? action.pais : [Pai::UNKNOWN] * action.pais.size
              return Action.new({:type => :haipai, :actor => action.actor, :pais => pais})
            when :tsumo
              pai = action.actor == player ? action.pai : Pai::UNKNOWN
              return Action.new({:type => :tsumo, :actor => action.actor, :pai => pai})
            else
              return action
          end
        end
        
        def validate_responses(responses, action)
          for i in 0...4
            response = responses[i]
            raise("invalid actor") if response && response.actor != @players[i]
            is_actor = @players[i] == action.actor
            if expect_response_from?(@players[i])
              case action.type
                when :start_game, :start_kyoku, :haipai, :end_kyoku, :end_game,
                    :hora, :ryukyoku, :dora, :reach_accepted
                  valid = !response
                when :tsumo
                  if is_actor
                    valid = response && [:dahai, :reach, :ankan, :kakan, :hora].include?(response.type)
                  else
                    valid = !response
                  end
                when :dahai
                  if is_actor
                    valid = !response
                  else
                    valid = !response || [:chi, :pon, :daiminkan, :hora].include?(response.type)
                  end
                when :chi, :pon, :reach
                  if is_actor
                    valid = response && response.type == :dahai
                  else
                    valid = !response
                  end
                when :ankan, :daiminkan
                  # Actor should wait for tsumo.
                  valid = !response
                when :kakan
                  if is_actor
                    # Actor should wait for tsumo.
                    valid = !response
                  else
                    valid = !response || response.type == :hora
                  end
                else
                  raise("unknown action type: #{action.type}")
              end
            else
              valid = !response
            end
            raise("bad response %p for %p" % [response, action]) if !valid
          end
        end
        
        def doras
          return @dora_markers ? @dora_markers.map(){ |pai| pai.succ } : nil
        end
        
        def dump_action(action)
          puts(action.to_json())
          dump()
        end
        
        def dump()
          if @bakaze && @honba && @oya
            print("%s-%d kyoku %d honba  " % [@bakaze, @oya.id + 1, @honba])
          end
          print("pipai: %d  " % @pipais.size) if @pipais
          print("dora_marker: %s  " % @dora_markers.join(" ")) if @dora_markers
          puts()
          @players.each_with_index() do |player, i|
            if player.tehais
              puts("%s%s%d%s tehai: %s %s" %
                   [player == @actor ? "*" : " ",
                    player == @oya ? "{" : "[",
                    i,
                    player == @oya ? "}" : "]",
                    Pai.dump_pais(player.tehais),
                    player.furos.join(" ")])
              if player.reach_ho_index
                ho_str =
                    Pai.dump_pais(player.ho[0...player.reach_ho_index]) + "=" +
                    Pai.dump_pais(player.ho[player.reach_ho_index..-1])
              else
                ho_str = Pai.dump_pais(player.ho)
              end
              puts("     ho:    %s" % ho_str)
            end
          end
          puts("-" * 80)
          #gets()
        end
        
    end
    
end