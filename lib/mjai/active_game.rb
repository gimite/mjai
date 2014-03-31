require "mjai/game"
require "mjai/action"
require "mjai/hora"
require "mjai/validation_error"


module Mjai
    
    class ActiveGame < Game
        
        ACTION_PREFERENCES = {
            :hora => 4,
            :ryukyoku => 3,
            :pon => 2,
            :daiminkan => 2,
            :chi => 1,
        }
        
        def initialize(players)
          super(players.shuffle())
          @game_type = :one_kyoku
        end
        
        attr_accessor(:game_type)
        
        def play()
          if ![:one_kyoku, :tonpu, :tonnan].include?(@game_type)
            raise("Unknown game_type")
          end
          begin
            do_action({:type => :start_game, :names => self.players.map(){ |pl| pl.name }})
            @ag_oya = @ag_chicha = @players[0]
            @ag_bakaze = Pai.new("E")
            @ag_honba = 0
            @ag_kyotaku = 0
            while !self.game_finished?
              play_kyoku()
            end
            do_action({:type => :end_game, :scores => get_final_scores()})
            return true
          rescue ValidationError => ex
            do_action({:type => :error, :message => ex.message})
            return false
          end
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
                :kyoku => (4 + @ag_oya.id - @ag_chicha.id) % 4 + 1,
                :honba => @ag_honba,
                :kyotaku => @ag_kyotaku,
                :oya => @ag_oya,
                :dora_marker => dora_marker,
                :tehais => tehais,
            })
            @actor = self.oya
            while !@pipais.empty?
              mota()
              @actor = @players[(@actor.id + 1) % 4]
            end
            process_fanpai()
          end
          do_action({:type => :end_kyoku})
        end
        
        # 摸打
        def mota()
          reach_pending = false
          kandora_pending = false
          tsumo_actor = @actor
          actions = [Action.new({:type => :tsumo, :actor => @actor, :pai => @pipais.pop()})]
          while !actions.empty?
            if actions[0].type == :hora
              if actions.size >= 3
                process_ryukyoku(:sanchaho, actions.map(){ |a| a.actor })
              else
                process_hora(actions)
              end
              throw(:end_kyoku)
            elsif actions[0].type == :ryukyoku
              raise("should not happen") if actions.size != 1
              process_ryukyoku(:kyushukyuhai, [actions[0].actor])
              throw(:end_kyoku)
            else
              raise("should not happen") if actions.size != 1
              action = actions[0]
              responses = do_action(action)
              next_actions = nil
              case action.type
                when :daiminkan, :kakan, :ankan
                  if action.type == :ankan
                    add_dora()
                  end
                  # Actually takes one from wanpai and moves one pai from pipai to wanpai,
                  # but it's equivalent to taking from pipai.
                  next_actions =
                    [Action.new({:type => :tsumo, :actor => action.actor, :pai => @pipais.pop()})]
                  # TODO Handle 4 kans.
                when :reach
                  reach_pending = true
              end
              next_actions ||= choose_actions(responses)
              if reach_pending &&
                  (next_actions.empty? || ![:dahai, :hora].include?(next_actions[0].type))
                @ag_kyotaku += 1
                deltas = [0, 0, 0, 0]
                deltas[tsumo_actor.id] = -1000
                do_action({
                    :type => :reach_accepted,
                    :actor => tsumo_actor,
                    :deltas => deltas,
                    :scores => get_scores(deltas),
                })
                reach_pending = false
              end
              if kandora_pending &&
                  !next_actions.empty? && [:dahai, :tsumo].include?(next_actions[0].type)
                add_dora()
                kandora_pending = false
              end
              if [:daiminkan, :kakan].include?(action.type)
                kandora_pending = true
              end
              if action.type == :dahai && (next_actions.empty? || next_actions[0].type != :hora)
                check_ryukyoku()
              end
              actions = next_actions
            end
          end
        end
        
        def check_ryukyoku()
          if players.all?(){ |pl| pl.reach? }
            process_ryukyoku(:suchareach)
            throw(:end_kyoku)
          end
          if first_turn? && !players[0].sutehais.empty? && players[0].sutehais[0].fonpai? &&
              players.all?(){ |pl| pl.sutehais == [players[0].sutehais[0]] }
            process_ryukyoku(:sufonrenta)
            throw(:end_kyoku)
          end
          kan_counts = players.map(){ |pl| pl.furos.count(){ |f| f.kan? } }
          if kan_counts.inject(0){ |total, n| total + n } == 4 && !kan_counts.include?(4)
            process_ryukyoku(:sukaikan)
            throw(:end_kyoku)
          end
        end
        
        def update_state(action)
          super(action)
          if action.type == :tsumo && @pipais.size != self.num_pipais
            raise("num pipais mismatch: %p != %p" % [@pipais.size, self.num_pipais])
          end
        end
        
        def choose_actions(actions)
          actions = actions.select(){ |a| a }
          max_pref = actions.map(){ |a| ACTION_PREFERENCES[a.type] || 0 }.max
          max_actions = actions.select(){ |a| (ACTION_PREFERENCES[a.type] || 0) == max_pref }
          return max_actions
        end
        
        def process_hora(actions)
          tsumibo = self.honba
          for action in actions.sort_by(){ |a| distance(a.actor, a.target) }
            uradora_markers = action.actor.reach? ? @wanpais.pop(self.dora_markers.size) : []
            hora = get_hora(action, {
                :uradora_markers => uradora_markers,
                :previous_action => self.previous_action,
            })
            raise("no yaku") if !hora.valid?
            deltas = [0, 0, 0, 0]
            deltas[action.actor.id] += hora.points + tsumibo * 300 + @ag_kyotaku * 1000
            if hora.hora_type == :tsumo
              for player in self.players
                next if player == action.actor
                deltas[player.id] -=
                    ((player == self.oya ? hora.oya_payment : hora.ko_payment) + tsumibo * 100)
              end
            else
              deltas[action.target.id] -= (hora.points + tsumibo * 300)
            end
            do_action({
              :type => action.type,
              :actor => action.actor,
              :target => action.target,
              :pai => action.pai,
              :hora_tehais => action.actor.tehais,
              :uradora_markers => uradora_markers,
              :yakus => hora.yakus,
              :fu => hora.fu,
              :fan => hora.fan,
              :hora_points => hora.points,
              :deltas => deltas,
              :scores => get_scores(deltas),
            })
            # Only kamicha takes them in case of daburon.
            tsumibo = 0
            @ag_kyotaku = 0
          end
          update_oya(actions.any?(){ |a| a.actor == self.oya }, false)
        end
        
        def process_ryukyoku(reason, actors=[])
          actor = (reason == :kyushukyuhai) ? actors[0] : nil
          tenpais = []
          tehais = []
          for player in players
            if reason == :suchareach || actors.include?(player)  # :sanchaho, :kyushukyuhai
              tenpais.push(reason != :kyushukyuhai)
              tehais.push(player.tehais)
            else
              tenpais.push(false)
              tehais.push([Pai::UNKNOWN] * player.tehais.size)
            end
          end
          do_action({
              :type => :ryukyoku,
              :actor => actor,
              :reason => reason,
              :tenpais => tenpais,
              :tehais => tehais,
              :deltas => [0, 0, 0, 0],
              :scores => players.map(){ |player| player.score }
          })
          update_oya(true, true)
        end
        
        def process_fanpai()
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
            @ag_oya = @players[(self.oya.id + 1) % 4]
            @ag_bakaze = @ag_bakaze.succ if @ag_oya == @players[0]
          end
          if renchan || ryukyoku
            @ag_honba += 1
          else
            @ag_honba = 0
          end
          case @game_type
            when :tonpu
              @last = decide_last(Pai.new("E"), renchan)
            when :tonnan
              @last = decide_last(Pai.new("S"), renchan)
          end
        end
        
        def decide_last(last_bakaze, tenpai_renchan)
          if @players.any? { |pl| pl.score < 0 }
            return true
          end

          if @ag_bakaze == last_bakaze.succ.succ
            return true
          end
          if @ag_bakaze == last_bakaze.succ
            return @players.any? { |pl| pl.score >= 30000 }
          end

          # Agari-yame, tenpai-yame
          if @ag_bakaze == last_bakaze && @ag_oya == @players[3] &&
              tenpai_renchan && @players[3].score >= 30000 &&
              (0..2).all? { |i| @players[i].score < @players[3].score }
            return true
          end

          return false
        end
        
        def add_dora()
          dora_marker = @wanpais.pop()
          do_action({:type => :dora, :dora_marker => dora_marker})
        end
        
        def game_finished?
          if @last
            return true
          else
            @last = true if @game_type == :one_kyoku
            return false
          end
        end
        
        def get_final_scores()
          # The winner takes remaining kyotaku.
          deltas = [0, 0, 0, 0]
          deltas[self.ranked_players[0].id] = @ag_kyotaku * 1000
          return get_scores(deltas)
        end
        
        def expect_response_from?(player)
          return true
        end
        
        def get_scores(deltas)
          return (0...4).map(){ |i| self.players[i].score + deltas[i] }
        end
        
    end
    
end
