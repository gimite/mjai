require "mjai/action"
require "mjai/pai"
require "mjai/furo"
require "mjai/hora"
require "mjai/validation_error"


module Mjai
    
    class Game
        
        def initialize(players = nil)
          self.players = players if players
          @bakaze = nil
          @kyoku_num = nil
          @honba = nil
          @chicha = nil
          @oya = nil
          @dora_markers = nil
          @current_action = nil
          @previous_action = nil
          @num_pipais = nil
          @num_initial_pipais = nil
          @first_turn = false
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
        
        def on_responses(&block)
          @on_responses = block
        end
        
        # Executes the action and returns responses for it from players.
        def do_action(action)
          
          if action.is_a?(Hash)
            action = Action.new(action)
          end
          
          update_state(action)
          
          @on_action.call(action) if @on_action
          
          responses = (0...4).map() do |i|
            @players[i].respond_to_action(action_in_view(action, i, true))
          end

          action_with_logs = action.merge({:logs => responses.map(){ |r| r && r.log }})
          responses = responses.map(){ |r| (!r || r.type == :none) ? nil : r.merge({:log => nil}) }
          @on_responses.call(action_with_logs, responses) if @on_responses

          @previous_action = action
          validate_responses(responses, action)
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
              @bakaze = action.bakaze
              @kyoku_num = action.kyoku
              @honba = action.honba
              @oya = action.oya
              @chicha ||= @oya
              @dora_markers = [action.dora_marker]
              @num_pipais = @num_initial_pipais = @all_pais.size - 13 * 4 - 14
              @first_turn = true
            when :tsumo
              @num_pipais -= 1
              if @num_initial_pipais - @num_pipais > 4
                @first_turn = false
              end
            when :chi, :pon, :daiminkan, :kakan, :ankan
              @first_turn = false
            when :dora
              @dora_markers.push(action.dora_marker)
          end
          
          for i in 0...4
            @players[i].update_state(action_in_view(action, i, false))
          end
          
        end
        
        def action_in_view(action, player_id, for_response)
          player = @players[player_id]
          with_response_hint = for_response && expect_response_from?(player)
          case action.type
            when :start_game
              return action.merge({:id => player_id})
            when :start_kyoku
              tehais_list = action.tehais.dup()
              for i in 0...4
                if i != player_id
                  tehais_list[i] = [Pai::UNKNOWN] * tehais_list[i].size
                end
              end
              return action.merge({:tehais => tehais_list})
            when :tsumo
              if action.actor == player
                return action.merge({
                    :possible_actions =>
                        with_response_hint ? player.possible_actions : nil,
                })
              else
                return action.merge({:pai => Pai::UNKNOWN})
              end
            when :dahai, :kakan
              if action.actor != player
                return action.merge({
                    :possible_actions =>
                        with_response_hint ? player.possible_actions : nil,
                })
              else
                return action
              end
            when :chi, :pon
              if action.actor == player
                return action.merge({
                    :cannot_dahai =>
                        with_response_hint ? player.kuikae_dahais : nil,
                })
              else
                return action
              end
            when :reach
              if action.actor == player
                return action.merge({
                    :cannot_dahai =>
                        with_response_hint ? (player.tehais.uniq() - player.possible_dahais) : nil,
                })
              else
                return action
              end
            else
              return action
          end
        end
        
        def validate_responses(responses, action)
          for i in 0...4
            response = responses[i]
            begin
              if response && response.actor != @players[i]
                raise(ValidationError, "Invalid actor.")
              end
              validate_response_type(response, @players[i], action)
              validate_response_content(response, action) if response
            rescue ValidationError => ex
              raise(ValidationError,
                  "Error in player %d's response: %s Response: %s" % [i, ex.message, response])
            end
          end
        end
        
        def validate_response_type(response, player, action)
          if response && response.type == :error
            raise(ValidationError, response.message)
          end
          is_actor = player == action.actor
          if expect_response_from?(player)
            case action.type
              when :start_game, :start_kyoku, :end_kyoku, :end_game, :error,
                  :hora, :ryukyoku, :dora, :reach_accepted
                valid = !response
              when :tsumo
                if is_actor
                  valid = response &&
                      [:dahai, :reach, :ankan, :kakan, :hora, :ryukyoku].include?(response.type)
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
                  # hora is for chankan.
                  valid = !response || response.type == :hora
                end
              when :log
                valid = !response
              else
                raise(ValidationError, "Unknown action type: '#{action.type}'")
            end
          else
            valid = !response
          end
          if !valid
            raise(ValidationError,
                "Unexpected response type '%s' for %s." % [response ? response.type : :none, action])
          end
        end
        
        def validate_response_content(response, action)
          
          case response.type
            
            when :dahai
              
              validate_fields_exist(response, [:pai, :tsumogiri])
              if action.actor.reach?
                # possible_dahais check doesn't subsume this check. Consider karagiri
                # (with tsumogiri=false) after reach.
                validate(response.tsumogiri, "tsumogiri must be true after reach.")
              end
              validate(
                  response.actor.possible_dahais.include?(response.pai),
                  "Cannot dahai this pai. The pai is not in the tehais, " +
                  "it's kuikae, or it causes noten reach.")
              
              # Validates that pai and tsumogiri fields are consistent.
              if [:tsumo, :reach].include?(action.type)
                if response.tsumogiri
                  tsumo_pai = response.actor.tehais[-1]
                  validate(
                      response.pai == tsumo_pai,
                      "tsumogiri is true but the pai is not tsumo pai: %s != %s" %
                      [response.pai, tsumo_pai])
                else
                  validate(
                      response.actor.tehais[0...-1].include?(response.pai),
                      "tsumogiri is false but the pai is not in tehais.")
                end
              else  # after furo
                validate(
                    !response.tsumogiri,
                    "tsumogiri must be false on dahai after furo.")
              end
            
            when :chi, :pon, :daiminkan, :ankan, :kakan
              if response.type == :ankan
                validate_fields_exist(response, [:consumed])
              elsif response.type == :kakan
                validate_fields_exist(response, [:pai, :consumed])
              else
                validate_fields_exist(response, [:target, :pai, :consumed])
                validate(
                    response.target == action.actor,
                    "target must be %d." % action.actor.id)
              end
              valid = response.actor.possible_furo_actions.any?() do |a|
                a.type == response.type &&
                    a.pai == response.pai &&
                    a.consumed.sort() == response.consumed.sort()
              end
              validate(valid, "The furo is not allowed.")
            
            when :reach
              validate(response.actor.can_reach?, "Cannot reach.")
            
            when :hora
              validate_fields_exist(response, [:target, :pai])
              validate(
                  response.target == action.actor,
                  "target must be %d." % action.actor.id)
              if response.target == response.actor
                tsumo_pai = response.actor.tehais[-1]
                validate(
                    response.pai == tsumo_pai,
                    "pai is not tsumo pai: %s != %s" % [response.pai, tsumo_pai])
              else
                validate(
                    response.pai == action.pai,
                    "pai is not previous dahai: %s != %s" % [response.pai, action.pai])
              end
              validate(response.actor.can_hora?, "Cannot hora.")
            
            when :ryukyoku
              validate_fields_exist(response, [:reason])
              validate(response.reason == :kyushukyuhai, "reason must be kyushukyuhai.")
              validate(response.actor.can_ryukyoku?, "Cannot ryukyoku.")
            
          end
          
        end
        
        def validate(criterion, message)
          raise(ValidationError, message) if !criterion
        end
        
        def validate_fields_exist(response, field_names)
          for name in field_names
            if !response.fields.has_key?(name)
              raise(ValidationError, "%s missing." % name)
            end
          end
        end
        
        def doras
          return @dora_markers ? @dora_markers.map(){ |pai| pai.succ } : nil
        end
        
        def get_hora(action, params = {})
          raise("should not happen") if action.type != :hora
          hora_type = action.actor == action.target ? :tsumo : :ron
          if hora_type == :tsumo
            tehais = action.actor.tehais[0...-1]
          else
            tehais = action.actor.tehais
          end
          uradoras = (params[:uradora_markers] || []).map(){ |pai| pai.succ }
          return Hora.new({
            :tehais => tehais,
            :furos => action.actor.furos,
            :taken => action.pai,
            :hora_type => hora_type,
            :oya => action.actor == self.oya,
            :bakaze => self.bakaze,
            :jikaze => action.actor.jikaze,
            :doras => self.doras,
            :uradoras => uradoras,
            :reach => action.actor.reach?,
            :double_reach => action.actor.double_reach?,
            :ippatsu => action.actor.ippatsu_chance?,
            :rinshan => action.actor.rinshan?,
            :haitei => self.num_pipais == 0,
            :first_turn => @first_turn,
            :chankan => params[:previous_action].type == :kakan,
          })
        end
        
        def first_turn?
          return @first_turn
        end
        
        def can_kan?
          return @dora_markers.size < 5
        end
        
        def ranked_players
          return @players.sort_by(){ |pl| [-pl.score, distance(pl, @chicha)] }
        end
        
        def distance(player1, player2)
          return (4 + player1.id - player2.id) % 4
        end
        
        def dump_action(action, io = $stdout)
          io.puts(action.to_json())
          io.print(render_board())
        end
        
        def render_board()
          result = ""
          if @bakaze && @kyoku_num && @honba
            result << ("%s-%d kyoku %d honba  " % [@bakaze, @kyoku_num, @honba])
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
