require "ostruct"

require "mjai/pai"
require "mjai/tenpai_analysis"


module Mjai
    
    class Player
        
        attr_reader(:id)
        attr_reader(:tehais)  # 手牌
        attr_reader(:furos)  # 副露
        attr_reader(:ho)  # 河 (鳴かれた牌を含まない)
        attr_reader(:sutehais)  # 捨牌 (鳴かれた牌を含む)
        attr_reader(:extra_anpais)  # sutehais以外のこのプレーヤに対する安牌
        attr_reader(:reach_state)
        attr_reader(:reach_ho_index)
        attr_reader(:attributes)
        attr_accessor(:name)
        attr_accessor(:game)
        attr_accessor(:score)
        
        def anpais
          return @sutehais + @extra_anpais
        end
        
        def reach?
          return @reach_state == :accepted
        end
        
        def double_reach?
          return @double_reach
        end
        
        def ippatsu_chance?
          return @ippatsu_chance
        end
        
        def rinshan?
          return @rinshan
        end
        
        def update_state(action)
          
          if @game.previous_action &&
              @game.previous_action.type == :dahai &&
              @game.previous_action.actor != self &&
              action.type != :hora
            @extra_anpais.push(@game.previous_action.pai)
          end
          
          case action.type
            when :start_game
              @id = action.id
              @name = action.names[@id] if action.names
              @score = 25000
              @attributes = OpenStruct.new()
              @tehais = nil
              @furos = nil
              @ho = nil
              @sutehais = nil
              @extra_anpais = nil
              @reach_state = nil
              @reach_ho_index = nil
              @double_reach = false
              @ippatsu_chance = false
              @rinshan = false
            when :start_kyoku
              @tehais = action.tehais[self.id]
              @furos = []
              @ho = []
              @sutehais = []
              @extra_anpais = []
              @reach_state = :none
              @reach_ho_index = nil
              @double_reach = false
              @ippatsu_chance = false
              @rinshan = false
            when :chi, :pon, :daiminkan, :kakan, :ankan
              @ippatsu_chance = false
          end
          
          if action.actor == self
            case action.type
              when :tsumo
                @tehais.push(action.pai)
              when :dahai
                delete_tehai(action.pai)
                @tehais.sort!()
                @ho.push(action.pai)
                @sutehais.push(action.pai)
                @ippatsu_chance = false
                @rinshan = false
                @extra_anpais.clear() if !self.reach?
              when :chi, :pon, :daiminkan, :ankan
                for pai in action.consumed
                  delete_tehai(pai)
                end
                @furos.push(Furo.new({
                  :type => action.type,
                  :taken => action.pai,
                  :consumed => action.consumed,
                  :target => action.target,
                }))
                if [:daiminkan, :ankan].include?(action.type)
                  @rinshan = true
                end
              when :kakan
                delete_tehai(action.pai)
                pon_index =
                    @furos.index(){ |f| f.type == :pon && f.taken.same_symbol?(action.pai) }
                raise("should not happen") if !pon_index
                @furos[pon_index] = Furo.new({
                  :type => :kakan,
                  :taken => @furos[pon_index].taken,
                  :consumed => @furos[pon_index].consumed + [action.pai],
                  :target => @furos[pon_index].target,
                })
                @rinshan = true
              when :reach
                @reach_state = :declared
                @double_reach = true if @game.first_turn?
              when :reach_accepted
                @reach_state = :accepted
                @reach_ho_index = @ho.size - 1
                @ippatsu_chance = true
            end
          end
          
          if action.target == self
            case action.type
              when :chi, :pon, :daiminkan
                pai = @ho.pop()
                raise("should not happen") if pai != action.pai
            end
          end
          
          if action.scores
            @score = action.scores[self.id]
          end
          
        end
        
        def jikaze
          if @game.oya
            return Pai.new("t", 1 + (4 + @id - @game.oya.id) % 4)
          else
            return nil
          end
        end
        
        def tenpai?
          return ShantenAnalysis.new(@tehais, 0).shanten <= 0
        end
        
        def furiten?
          return false if @tehais.size % 3 != 1
          return false if @tehais.include?(Pai::UNKNOWN)
          tenpai_info = TenpaiAnalysis.new(@tehais)
          return false if !tenpai_info.tenpai?
          anpais = self.anpais
          return tenpai_info.waited_pais.any?(){ |pai| anpais.include?(pai) }
        end
        
        def can_reach?(shanten_analysis = nil)
          shanten_analysis ||= ShantenAnalysis.new(@tehais, 0)
          return @game.current_action.type == :tsumo &&
              @game.current_action.actor == self &&
              shanten_analysis.shanten <= 0 &&
              @furos.empty? &&
              !self.reach? &&
              self.game.num_pipais >= 4 &&
              @score >= 1000
        end
        
        def can_hora?(shanten_analysis = nil)
          action = @game.current_action
          if action.type == :tsumo && action.actor == self
            hora_type = :tsumo
            pais = @tehais
          elsif [:dahai, :kakan].include?(action.type) && action.actor != self
            hora_type = :ron
            pais = @tehais + [action.pai]
          else
            return false
          end
          shanten_analysis ||= ShantenAnalysis.new(pais, -1)
          hora_action =
              create_action({:type => :hora, :target => action.actor, :pai => pais[-1]})
          return shanten_analysis.shanten == -1 &&
              @game.get_hora(hora_action, {:previous_action => action}).valid? &&
              (hora_type == :tsumo || !self.furiten?)
        end
        
        def can_ryukyoku?
          return @game.current_action.type == :tsumo &&
              @game.current_action.actor == self &&
              @game.first_turn? &&
              @tehais.select(){ |pai| pai.yaochu? }.uniq().size >= 9
        end
        
        # Possible actions except for dahai.
        def possible_actions
          action = @game.current_action
          result = []
          if (action.type == :tsumo && action.actor == self) ||
              ([:dahai, :kakan].include?(action.type) && action.actor != self)
            if can_hora?
              result.push(create_action({
                  :type => :hora,
                  :target => action.actor,
                  :pai => action.pai,
              }))
            end
            if can_reach?
              result.push(create_action({:type => :reach}))
            end
            if can_ryukyoku?
              result.push(create_action({:type => :ryukyoku, :reason => :kyushukyuhai}))
            end
          end
          result += self.possible_furo_actions
          return result
        end
        
        def possible_furo_actions
          
          action = @game.current_action
          result = []
          
          if action.type == :dahai &&
              action.actor != self &&
              !self.reach? &&
              @game.num_pipais > 0
            
            if @game.can_kan?
              for consumed in get_pais_combinations([action.pai] * 3, @tehais)
                result.push(create_action({
                  :type => :daiminkan,
                  :pai => action.pai,
                  :consumed => consumed,
                  :target => action.actor
                }))
              end
            end
            for consumed in get_pais_combinations([action.pai] * 2, @tehais)
              result.push(create_action({
                :type => :pon,
                :pai => action.pai,
                :consumed => consumed,
                :target => action.actor
              }))
            end
            if (action.actor.id + 1) % 4 == self.id && action.pai.type != "t"
              for i in 0...3
                target_pais = (((-i)...(-i + 3)).to_a() - [0]).map() do |j|
                  Pai.new(action.pai.type, action.pai.number + j)
                end
                for consumed in get_pais_combinations(target_pais, @tehais)
                  result.push(create_action({
                    :type => :chi,
                    :pai => action.pai,
                    :consumed => consumed,
                    :target => action.actor,
                  }))
                end
              end
            end
            # Excludes furos which forces kuikae afterwards.
            result = result.select() do |a|
              a.type == :daiminkan || !possible_dahais_after_furo(a).empty?
            end
            
          elsif action.type == :tsumo &&
              action.actor == self &&
              @game.num_pipais > 0 &&
              @game.can_kan?
            
            for pai in self.tehais.uniq
              same_pais = self.tehais.select(){ |tp| tp.same_symbol?(pai) }
              if same_pais.size >= 4
                if self.reach?
                  orig_tenpai = TenpaiAnalysis.new(self.tehais[0...-1])
                  new_tenpai = TenpaiAnalysis.new(
                      self.tehais.select(){ |tp| !tp.same_symbol?(pai) })
                  ok = new_tenpai.tenpai? && new_tenpai.waited_pais == orig_tenpai.waited_pais
                else
                  ok = true
                end
                result.push(create_action({:type => :ankan, :consumed => same_pais})) if ok
              end
              pon = self.furos.find(){ |f| f.type == :pon && f.taken.same_symbol?(pai) }
              if pon
                result.push(create_action({:type => :kakan, :pai => pai, :consumed => pon.pais}))
              end
            end
            
          end
          
          return result
          
        end
        
        def get_pais_combinations(target_pais, source_pais)
          return Set.new([[]]) if target_pais.empty?
          result = Set.new()
          for pai in source_pais.select(){ |pai| target_pais[0].same_symbol?(pai) }.uniq
            new_source_pais = source_pais.dup()
            new_source_pais.delete_at(new_source_pais.index(pai))
            for cdr_pais in get_pais_combinations(target_pais[1..-1], new_source_pais)
              result.add(([pai] + cdr_pais).sort())
            end
          end
          return result
        end
        
        def possible_dahais(action = @game.current_action, tehais = @tehais)

          if self.reach? && action.type == :tsumo && action.actor == self

            # Only tsumogiri is allowed after reach.
            return [action.pai]

          elsif action.type == :reach

            # Tehais after the dahai must be tenpai just after reach.
            result = []
            for pai in tehais.uniq()
              pais = tehais.dup()
              pais.delete_at(pais.index(pai))
              if ShantenAnalysis.new(pais, 0).shanten <= 0
                result.push(pai)
              end
            end
            return result

          else

            # Excludes kuikae.
            return tehais.uniq() - kuikae_dahais(action, tehais)

          end

        end

        def kuikae_dahais(action = @game.current_action, tehais = @tehais)
          consumed = action.consumed ? action.consumed.sort() : nil
          if action.type == :chi && action.actor == self
            if consumed[1].number == consumed[0].number + 1
              forbidden_rnums = [-1, 2]
            else
              forbidden_rnums = [1]
            end
          elsif action.type == :pon && action.actor == self
            forbidden_rnums = [0]
          else
            forbidden_rnums = []
          end
          if forbidden_rnums.empty?
            return []
          else
            key_pai = consumed[0]
            return tehais.uniq().select() do |pai|
              pai.type == key_pai.type &&
                  forbidden_rnums.any?(){ |rn| key_pai.number + rn == pai.number }
            end
          end
        end
        
        def possible_dahais_after_furo(action)
          remains = @tehais.dup()
          for pai in action.consumed
            remains.delete_at(remains.index(pai))
          end
          return possible_dahais(action, remains)
        end
        
        def context
          return Context.new({
            :oya => self == self.game.oya,
            :bakaze => self.game.bakaze,
            :jikaze => self.jikaze,
            :doras => self.game.doras,
            :uradoras => [],  # TODO
            :reach => self.reach?,
            :double_reach => false,  # TODO
            :ippatsu => false,  # TODO
            :rinshan => false,  # TODO
            :haitei => self.game.num_pipais == 0,
            :first_turn => false,  # TODO
            :chankan => false,  # TODO
          })
        end
        
        def delete_tehai(pai)
          pai_index = @tehais.index(pai) || @tehais.index(Pai::UNKNOWN)
          raise("trying to delete %p which is not in tehais: %p" % [pai, @tehais]) if !pai_index
          @tehais.delete_at(pai_index)
        end
        
        def create_action(params = {})
          return Action.new({:actor => self}.merge(params))
        end
        
        def rank
          return @game.ranked_players.index(self) + 1
        end
        
        def inspect
          return "\#<%p:%p>" % [self.class, self.id]
        end
        
    end
    
end
