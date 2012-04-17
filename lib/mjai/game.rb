require "mjai/action"
require "mjai/pai"
require "mjai/furo"


module Mjai
    
    class Game
        
        def initialize(players = nil)
          self.players = players if players
          @chicha = nil
          @bakaze = nil
          @oya = nil
          @dora_markers = nil
          @current_action = nil
          @previous_action = nil
          @num_pipais = nil
        end
        
        attr_reader(:players)
        attr_reader(:all_pais)
        attr_reader(:bakaze)
        attr_reader(:oya)
        attr_reader(:honba)
        attr_reader(:dora_markers)  # ドラ表示牌
        attr_reader(:current_action)
        attr_reader(:previous_action)
        attr_reader(:all_pais)
        attr_reader(:num_pipais)
        attr_accessor(:last)  # kari
        
        def players=(players)
          @players = players
          for player in @players
            player.game = self
          end
        end
        
        def on_action(&block)
          @on_action = block
        end
        
        # Executes the action and returns responses for it from players.
        def do_action(action)
          
          if action.is_a?(Hash)
            action = Action.new(action)
          end
          
          if action.type != :log
            for player in @players
              if !player.log_text.empty?
                do_action({:type => :log, :actor => player, :text => player.log_text})
                player.clear_log()
              end
            end
          end
          
          update_state(action)
          
          @on_action.call(action) if @on_action
          
          responses = (0...4).map() do |i|
            @players[i].respond_to_action(action_in_view(action, i))
          end
          validate_responses(responses, action)
          
          @previous_action = action
          return responses
          
        end
        
        # Updates internal state of Game and Player objects by the action.
        def update_state(action)
          
          @current_action = action
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
              if !@chicha
                @chicha = action.oya
                @bakaze = Pai.new("E")
                @honba = 0
              elsif action.oya == @oya  # 連荘
                @honba += 1
              else
                @bakaze = @bakaze.succ if action.oya == @chicha
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
          
          for i in 0...4
            @players[i].update_state(action_in_view(action, i))
          end
          
        end
        
        def action_in_view(action, player_id)
          player = @players[player_id]
          case action.type
            when :start_game
              return action.merge({:id => player_id})
            when :haipai
              pais = action.actor == player ? action.pais : [Pai::UNKNOWN] * action.pais.size
              return action.merge({:pais => pais})
            when :tsumo
              pai = action.actor == player ? action.pai : Pai::UNKNOWN
              return action.merge({:pai => pai})
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
                    valid = response &&
                        [:dahai, :reach, :ankan, :kakan, :hora].include?(response.type)
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
                when :log
                  valid = !response
                else
                  raise("unknown action type: #{action.type}")
              end
            else
              valid = !response
            end
            raise("bad response %p for %p" % [response, action]) if !valid
            if response
              case response.type
                when :dahai
                  if !@players[i].possible_dahais.include?(response.pai)
                    raise("dahai not allowed: %p" % response)
                  end
              end
            end
          end
        end
        
        def doras
          return @dora_markers ? @dora_markers.map(){ |pai| pai.succ } : nil
        end
        
        def dump_action(action)
          puts(action.to_json())
          print(render_board())
        end
        
        def render_board()
          result = ""
          if @chicha && @bakaze && @honba && @oya
            kyoku_num = (4 + @oya.id - @chicha.id) % 4 + 1
            result << ("%s-%d kyoku %d honba  " % [@bakaze, kyoku_num, @honba])
          end
          result << ("pipai: %d  " % self.num_pipais) if self.num_pipais
          result << ("dora_marker: %s  " % @dora_markers.join(" ")) if @dora_markers
          result << "\n"
          @players.each_with_index() do |player, i|
            if player.tehais
              result << ("%s%s%d%s tehai: %s %s\n" %
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
              result << ("     ho:    %s\n" % ho_str)
            end
          end
          result << ("-" * 80) << "\n"
          return result
        end
        
    end
    
end
