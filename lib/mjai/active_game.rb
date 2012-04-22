require "mjai/game"
require "mjai/action"
require "mjai/hora"


module Mjai
    
    class ActiveGame < Game
        
        def initialize(players)
          super(players)
          @game_type = :one_kyoku
        end
        
        attr_accessor(:game_type)
        
        def play()
          do_action({:type => :start_game, :names => self.players.map(){ |pl| pl.name }})
          @ag_oya = @chicha = @players[0]
          @ag_bakaze = Pai.new("E")
          @ag_honba = 0
          while !self.game_finished?
            play_kyoku()
          end
          do_action({:type => :end_game})
        end
        
        def play_kyoku()
          catch(:end_kyoku) do
            @pipais = @all_pais.shuffle()
            @pipais.shuffle!()
            @wanpais = @pipais.pop(14)
            dora_marker = @wanpais.pop()
            tehais = Array.new(4){ @pipais.pop(13).sort() }
            do_action({
                :type => :start_kyoku,
                :bakaze => @ag_bakaze,
                :kyoku => (4 + @ag_oya.id - @chicha.id) % 4 + 1,
                :honba => @ag_honba,
                :oya => @ag_oya,
                :dora_marker => dora_marker,
                :tehais => tehais,
            })
            @actor = self.oya
            while !@pipais.empty?
              mota()
              @actor = @players[(@actor.id + 1) % 4]
            end
            process_ryukyoku()
          end
          do_action({:type => :end_kyoku})
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
                  # Actually takes one from wanpai and moves one pai from pipai to wanpai,
                  # but it's equivalent to taking from pipai.
                  actions =
                    [Action.new({:type => :tsumo, :actor => action.actor, :pai => @pipais.pop()})]
                  # TODO Add dora.
                  next
                when :reach
                  reach = true
              end
              actions = choose_actions(responses)
              if reach && (actions.empty? || ![:dahai, :hora].include?(actions[0].type))
                deltas = [0, 0, 0, 0]
                deltas[tsumo_actor.id] = -1000
                do_action({
                    :type => :reach_accepted,:actor => tsumo_actor,
                    :deltas => deltas,
                    :scores => get_scores(deltas),
                })
              end
            end
          end
        end
        
        def update_state(action)
          super(action)
          if action.type == :tsumo && @pipais.size != self.num_pipais
            raise("num pipais mismatch: %p != %p" % [@pipais.size, self.num_pipais])
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
            do_action({
              :type => action.type,
              :actor => action.actor,
              :target => action.target,
              :pai => action.pai,
              :hora_tehais => tehais,
              :yakus => hora.yakus,
              :fu => hora.fu,
              :fan => hora.fan,
              :hora_points => hora.points,
              :deltas => deltas,
              :scores => get_scores(deltas),
            })
          end
          update_oya(actions.any?(){ |a| a.actor == self.oya }, false)
        end
        
        def process_ryukyoku()
          tenpais = []
          tehais = []
          for player in players
            if player.tenpai?
              tenpais.push(true)
              tehais.push(player.tehais)
            else
              tenpais.push(false)
              tehais.push([Pai::UNKNOWN] * player.tehais.size)
            end
          end
          tenpai_ids = (0...4).select(){ |i| tenpais[i] }
          noten_ids = (0...4).select(){ |i| !tenpais[i] }
          deltas = [0, 0, 0, 0]
          if (1..3).include?(tenpai_ids.size)
            for id in tenpai_ids
              deltas[id] += 3000 / tenpai_ids.size
            end
            for id in noten_ids
              deltas[id] -= 3000 / noten_ids.size
            end
          end
          do_action({
              :type => :ryukyoku,
              :reason => :fanpai,
              :tenpais => tenpais,
              :tehais => tehais,
              :deltas => deltas,
              :scores => get_scores(deltas),
          })
          update_oya(tenpais[self.oya.id], true)
        end
        
        def update_oya(renchan, ryukyoku)
          if renchan
            @ag_oya = self.oya
          else
            if self.oya == @players[3]
              @ag_bakaze = @ag_bakaze.succ
              if (@game_type == :tonpu && @ag_bakaze == Pai.new("S")) ||
                  (@game_type == :tonnan && @ag_bakaze == Pai.new("W"))
                # TODO Consider 南入, etc.
                @last = true
              end
            end
            @ag_oya = @players[(self.oya.id + 1) % 4]
          end
          if renchan || ryukyoku
            @ag_honba += 1
          else
            @ag_honba = 0
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
        
        def expect_response_from?(player)
          return true
        end
        
        def get_scores(deltas)
          return (0...4).map(){ |i| self.players[i].points + deltas[i] }
        end
        
    end
    
end
