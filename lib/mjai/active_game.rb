require "mjai/game"
require "mjai/action"
require "mjai/hora"


module Mjai
    
    class ActiveGame < Game
        
        def play()
          do_action(Action.new({:type => :start_game}))
          @next_oya = @players[0]
          while !self.game_finished?
            play_kyoku()
          end
          do_action(Action.new({:type => :end_game}))
        end
        
        def play_kyoku()
          $stderr.puts("play_kyoku")
          catch(:end_kyoku) do
            @pipais = @all_pais.shuffle()
            @pipais.shuffle!()
            @wanpais = @pipais.pop(14)
            dora_marker = @wanpais.pop()
            do_action(Action.new({:type => :start_kyoku, :oya => @next_oya, :dora_marker => dora_marker}))
            #gets() # kari
            for player in @players
              do_action(Action.new(
                  {:type => :haipai, :actor => player, :pais => @pipais.pop(13) }))
            end
            @actor = self.oya
            while !@pipais.empty?
              mota()
              @actor = @players[(@actor.id + 1) % 4]
            end
            process_ryukyoku()
          end
          do_action(Action.new({:type => :end_kyoku}))
        end
        
        # 摸打
        def mota()
          reach = false
          tsumo_actor = @actor
          actions = [Action.new({:type => :tsumo, :actor => @actor, :pai => @pipais.pop()})]
          while !actions.empty?
            if actions[0].type == :hora
              # actions.size >= 2 in case of double/triple ron
              process_hora(actions)
              throw(:end_kyoku)
            else
              raise("should not happen") if actions.size != 1
              action = actions[0]
              responses = do_action(action)
              case action.type
                when :daiminkan, :kakan, :ankan
                  actions =
                    [Action.new({:type => :tsumo, :actor => action.actor, :pai => @wanpais.pop()})]
                  # TODO 王牌の補充、ドラの追加
                  next
                when :reach
                  reach = true
              end
              actions = choose_actions(responses)
              if reach && (actions.empty? || ![:dahai, :hora].include?(actions[0].type))
                do_action(Action.new({:type => :reach_accepted, :actor => tsumo_actor}))
              end
            end
          end
        end
        
        def choose_actions(actions)
          action = actions.find(){ |a| a }  # TODO fix this
          return action ? [action] : []
        end
        
        def process_hora(actions)
          # TODO ダブロンの上家取り
          for action in actions
            hora_type = action.actor == action.target ? :tsumo : :ron
            if hora_type == :tsumo
              tehais = action.actor.tehais[0...-1]
            else
              tehais = action.actor.tehais
            end
            hora = Hora.new({
              :tehais => tehais,
              :furos => action.actor.furos,
              :taken => action.pai,
              :hora_type => hora_type,
              :oya => action.actor == self.oya,
              :bakaze => self.bakaze,
              :jikaze => action.actor.jikaze,
              :doras => self.doras,
              :uradoras => [],  # TODO
              :reach => action.actor.reach?,
              :double_reach => false,  # TODO
              :ippatsu => false,  # TODO
              :rinshan => false,  # TODO
              :haitei => @pipais.empty?,
              :first_turn => false,  # TODO
              :chankan => false,  # TODO
            })
            raise("no yaku") if !hora.valid?
            #p [:hora, hora.fu, hora.fan, hora.points, hora.yakus]
            deltas = [0, 0, 0, 0]
            # TODO 積み棒
            deltas[action.actor.id] += hora.points + self.honba * 300
            deltas[action.actor.id] += self.players.select(){ |pl| pl.reach? }.size * 1000
            if hora_type == :tsumo
              for player in self.players
                next if player == action.actor
                deltas[player.id] -=
                    ((player == self.oya ? hora.oya_payment : hora.ko_payment) + self.honba * 100)
              end
            else
              deltas[action.target.id] -= (hora.points + self.honba * 300)
            end
            for player in self.players
              player.points += deltas[player.id]
            end
            # TODO 役をフィールドに追加
            do_action(Action.new({
              :type => action.type,
              :actor => action.actor,
              :target => action.target,
              :pai => action.pai,
              :fu => hora.fu,
              :fan => hora.fan,
              :hora_points => hora.points,
              :deltas => deltas,
              :player_points => self.players.map(){ |pl| pl.points },
            }))
          end
          update_next_oya(actions.any?(){ |a| a.actor == self.oya })
        end
        
        def process_ryukyoku()
          tenpais = @players.map(){ |p| p.tenpai? }
          # TODO 点数計算
          do_action(Action.new({:type => :ryukyoku, :reason => :fanpai}))
          update_next_oya(tenpais[self.oya.id])
        end
        
        def update_next_oya(renchan)
          if renchan
            @next_oya = self.oya
          elsif self.bakaze == Pai.new("S") && self.oya == @players[3]
            # TODO Consider 西入、東風戦.
            @last = true
          else
            @next_oya = @players[(self.oya.id + 1) % 4]
          end
        end
        
        def game_finished?
          # TODO fix this
          if @last
            return true
          else
            @last = true if @game_type == :one_kyoku
            return false
          end
        end
        
        def num_pipais
          return @pipais.size
        end
        
        def expect_response_from?(player)
          return true
        end
        
    end
    
end
