require "ostruct"

require "mjai/pai"
require "mjai/tenpai_analysis"


module Mjai
    
    class Player
        
        def initialize()
          @log_text = ""
        end
        
        attr_reader(:id)
        attr_reader(:tehais)  # 手牌
        attr_reader(:furos)  # 副露
        attr_reader(:ho)  # 河 (鳴かれた牌を含まない)
        attr_reader(:sutehais)  # 捨牌 (鳴かれた牌を含む)
        attr_reader(:extra_anpais)  # sutehais以外のこのプレーヤに対する安牌
        attr_reader(:reach_state)
        attr_reader(:reach_ho_index)
        attr_reader(:attributes)
        attr_reader(:log_text)
        attr_accessor(:name)
        attr_accessor(:game)
        attr_accessor(:score)
        
        def anpais
          return @sutehais + @extra_anpais
        end
        
        def reach?
          return @reach_state == :accepted
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
            when :start_kyoku
              @tehais = action.tehais[self.id]
              @furos = []
              @ho = []
              @sutehais = []
              @extra_anpais = []
              @reach_state = :none
              @reach_ho_index = nil
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
              when :reach
                @reach_state = :declared
              when :reach_accepted
                @reach_state = :accepted
                @reach_ho_index = @ho.size - 1
            end
          end
          
          if action.target == self
            case action.type
              when :chi, :pon, :daiminkan, :ankan
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
            hais = @tehais
          elsif action.type == :dahai && action.actor != self
            hora_type = :ron
            hais = @tehais + [action.pai]
          else
            return false
          end
          shanten_analysis ||= ShantenAnalysis.new(hais, -1)
          # TODO check yaku
          return shanten_analysis.shanten == -1 &&
              (hora_type == :tsumo || !self.furiten?)
        end
        
        def possible_furo_actions
          
          # TODO Consider red pai
          action = @game.current_action
          result = []
          
          if action.type == :dahai &&
              action.actor != self &&
              !self.reach? &&
              @game.num_pipais >= 4
            
            if @tehais.select(){ |pai| pai == action.pai }.size >= 3
              result.push(create_action({
                :type => :daiminkan,
                :pai => action.pai,
                :consumed => [action.pai] * 3,
                :target => action.actor
              }))
            elsif @tehais.select(){ |pai| pai == action.pai }.size >= 2
              result.push(create_action({
                :type => :pon,
                :pai => action.pai,
                :consumed => [action.pai] * 2,
                :target => action.actor
              }))
            elsif (action.actor.id + 1) % 4 == self.id && action.pai.type != "t"
              for i in 0...3
                consumed = (((-i)...(-i + 3)).to_a() - [0]).map() do |j|
                  Pai.new(action.pai.type, action.pai.number + j)
                end
                if consumed.all?(){ |pai| @tehais.index(pai) }
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
              @game.num_pipais > 0
            
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
        
        def possible_dahais(action = @game.current_action, tehais = @tehais)
          # Excludes kuikae.
          if action.type == :chi && action.actor == self
            if action.consumed[1].number == action.consumed[0].number + 1
              forbidden_rnums = [-1, 2]
            else
              forbidden_rnums = [1]
            end
          elsif action.type == :pon && action.actor == self
            forbidden_rnums = [0]
          else
            forbidden_rnums = []
          end
          cands = tehais.uniq()
          if !forbidden_rnums.empty?
            key_pai = action.consumed[0]
            return cands.select() do |pai|
              !(pai.type == key_pai.type &&
                  forbidden_rnums.any?(){ |rn| key_pai.number + rn == pai.number })
            end
          else
            return cands
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
        
        def log(text)
          @log_text << text << "\n"
          puts(text)
        end
        
        def clear_log()
          @log_text = ""
        end
        
        def inspect
          return "\#<%p:%d>" % [self.class, self.id]
        end
        
    end
    
end
