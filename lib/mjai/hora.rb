require "set"
require "forwardable"

require "mjai/shanten_analysis"
require "mjai/pai"
require "mjai/with_fields"


module Mjai

    class Hora
        
        Mentsu = Struct.new(:type, :visibility, :pais)
        
        FURO_TYPE_TO_MENTSU_TYPE = {
          :chi => :shuntsu,
          :pon => :kotsu,
          :daiminkan => :kantsu,
          :kakan => :kantsu,
          :ankan => :kantsu,
        }
        
        BASE_FU_MAP = {
          :shuntsu => 0,
          :kotsu => 2,
          :kantsu => 8,
        }
        
        GREEN_PAIS = Set.new(Pai.parse_pais("23468sF"))
        CHURENPOTON_NUMBERS = [1, 1, 1, 2, 3, 4, 5, 6, 7, 8, 9, 9, 9]
        YAKUMAN_FAN = 100
        
        class PointsDatum
            
            def initialize(fu, fan, oya, hora_type)
              
              @fu = fu
              @fan = fan
              if @fan >= YAKUMAN_FAN
                @base_points = 8000 * (@fan / YAKUMAN_FAN)
              elsif @fan >= 13
                @base_points = 8000
              elsif @fan >= 11
                @base_points = 6000
              elsif @fan >= 8
                @base_points = 4000
              elsif @fan >= 6
                @base_points = 3000
              elsif @fan >= 5 || (@fan >= 4 && @fu >= 40) || (@fan >= 3 && @fu >= 70)
                @base_points = 2000
              else
                @base_points = @fu * (2 ** (@fan + 2))
              end
              
              if hora_type == :ron
                @oya_payment = @ko_payment = @points =
                    ceil_points(@base_points * (oya ? 6 : 4))
              else
                if oya
                  @ko_payment = ceil_points(@base_points * 2)
                  @oya_payment = 0
                  @points = @ko_payment * 3
                else
                  @oya_payment = ceil_points(@base_points * 2)
                  @ko_payment = ceil_points(@base_points)
                  @points = @oya_payment + @ko_payment * 2
                end
              end
              
            end
            
            attr_reader(:yaku, :fu, :points, :oya_payment, :ko_payment)
            
            def ceil_points(points)
              return (points / 100.0).ceil * 100
            end
            
        end
        
        class Candidate
            
            def initialize(hora, combination, taken_index)
              
              @hora = hora
              @combination = combination
              @all_pais = hora.all_pais.map(){ |pai| pai.remove_red() }
              
              @mentsus = []
              @janto = nil
              total_taken = 0
              if combination == :chitoitsu
                @machi = :tanki
                for pai in @all_pais.uniq()
                  mentsu = Mentsu.new(:toitsu, :an, [pai, pai])
                  if pai.same_symbol?(hora.taken)
                    @janto = mentsu
                  else
                    @mentsus.push(mentsu)
                  end
                end
              elsif combination == :kokushimuso
                @machi = :tanki
              else
                for mentsu_type, mentsu_pais in combination
                  num_this_taken = mentsu_pais.select(){ |pai| pai.same_symbol?(hora.taken) }.size
                  has_taken = taken_index >= total_taken && taken_index < total_taken + num_this_taken
                  if mentsu_type == :toitsu
                    raise("should not happen") if @janto
                    @janto = Mentsu.new(:toitsu, nil, mentsu_pais)
                  else
                    @mentsus.push(Mentsu.new(
                        mentsu_type,
                        has_taken && hora.hora_type == :ron ? :min : :an,
                        mentsu_pais))
                  end
                  if has_taken
                    case mentsu_type
                      when :toitsu
                        @machi = :tanki
                      when :kotsu
                        @machi = :shanpon
                      when :shuntsu
                        if mentsu_pais[1].same_symbol?(@hora.taken)
                          @machi = :kanchan
                        elsif (mentsu_pais[0].number == 1 && @hora.taken.number == 3) ||
                            (mentsu_pais[0].number == 7 && @hora.taken.number == 7)
                          @machi = :penchan
                        else
                          @machi = :ryanmen
                        end
                    end
                  end
                  total_taken += num_this_taken
                end
              end
              for furo in hora.furos
                @mentsus.push(Mentsu.new(
                    FURO_TYPE_TO_MENTSU_TYPE[furo.type],
                    furo.type == :ankan ? :an : :min,
                    furo.pais.map(){ |pai| pai.remove_red() }.sort()))
              end
              #p @mentsus
              #p @janto
              #p @machi
              
              get_yakus()
              #p @yakus
              @fan = @yakus.map(){ |y, f| f }.inject(0, :+)
              #p [:fan, @fan]
              @fu = get_fu()
              #p [:fu, @fu]
              
              datum = PointsDatum.new(@fu, @fan, @hora.oya, @hora.hora_type)
              @points = datum.points
              @oya_payment = datum.oya_payment
              @ko_payment = datum.ko_payment
              #p [:points, @points, @oya_payment, @ko_payment]
              
            end
            
            attr_reader(:points, :oya_payment, :ko_payment, :yakus, :fan, :fu)
            
            def valid?
              return !@yakus.select(){ |n, f| ![:dora, :uradora, :akadora].include?(n) }.empty?
            end
            
            # http://ja.wikipedia.org/wiki/%E9%BA%BB%E9%9B%80%E3%81%AE%E5%BD%B9%E4%B8%80%E8%A6%A7
            def get_yakus()
              
              @yakus = []
              
              # 役満
              if @hora.first_turn && @hora.hora_type == :tsumo && @hora.oya
                add_yaku(:tenho, YAKUMAN_FAN, 0)
              end
              if @hora.first_turn && @hora.hora_type == :tsumo && !@hora.oya
                add_yaku(:chiho, YAKUMAN_FAN, 0)
              end
              if @combination == :kokushimuso
                add_yaku(:kokushimuso, YAKUMAN_FAN, 0)
                return
              end
              if self.num_sangenpais == 3
                add_yaku(:daisangen, YAKUMAN_FAN, YAKUMAN_FAN)
              end
              if self.n_anko?(4)
                add_yaku(:suanko, YAKUMAN_FAN, 0)
              end
              if @all_pais.all?(){ |pai| pai.type == "t" }
                add_yaku(:tsuiso, YAKUMAN_FAN, YAKUMAN_FAN)
              end
              if self.ryuiso?
                add_yaku(:ryuiso, YAKUMAN_FAN, YAKUMAN_FAN)
              end
              if self.chinroto?
                add_yaku(:chinroto, YAKUMAN_FAN, YAKUMAN_FAN)
              end
              if self.daisushi?
                add_yaku(:daisushi, YAKUMAN_FAN, YAKUMAN_FAN)
              end
              if self.shosushi?
                add_yaku(:shosushi, YAKUMAN_FAN, YAKUMAN_FAN)
              end
              if self.n_kantsu?(4)
                add_yaku(:sukantsu, YAKUMAN_FAN, YAKUMAN_FAN)
              end
              if self.churenpoton?
                add_yaku(:churenpoton, YAKUMAN_FAN, 0)
              end
              return if !@yakus.empty?
              
              # ドラ
              add_yaku(:dora, @hora.num_doras, @hora.num_doras)
              add_yaku(:uradora, @hora.num_uradoras, @hora.num_uradoras)
              add_yaku(:akadora, @hora.num_akadoras, @hora.num_akadoras)
              
              # 一飜
              if @hora.reach
                add_yaku(:reach, 1, 0)
              end
              if @hora.ippatsu
                add_yaku(:ippatsu, 1, 0)
              end
              if self.menzen? && @hora.hora_type == :tsumo
                add_yaku(:menzenchin_tsumoho, 1, 0)
              end
              if @all_pais.all?(){ |pai| !pai.yaochu? }
                add_yaku(:tanyaochu, 1, 1)
              end
              if self.pinfu?
                add_yaku(:pinfu, 1, 0)
              end
              if self.ipeko?
                add_yaku(:ipeko, 1, 0)
              end
              add_yaku(:sangenpai, self.num_sangenpais, self.num_sangenpais)
              if self.bakaze?
                add_yaku(:bakaze, 1, 1)
              end
              if self.jikaze?
                add_yaku(:jikaze, 1, 1)
              end
              if @hora.rinshan
                add_yaku(:rinshankaiho, 1, 1)
              end
              if @hora.chankan
                add_yaku(:chankan, 1, 1)
              end
              if @hora.haitei && @hora.hora_type == :tsumo
                add_yaku(:haiteiraoyue, 1, 1)
              end
              if @hora.haitei && @hora.hora_type == :ron
                add_yaku(:hoteiraoyui, 1, 1)
              end
              
              # 二飜
              if self.sanshoku?([:shuntsu])
                add_yaku(:sanshokudojun, 2, 1)
              end
              if self.ikkitsukan?
                add_yaku(:ikkitsukan, 2, 1)
              end
              if self.honchantaiyao?
                add_yaku(:honchantaiyao, 2, 1)
              end
              if @combination == :chitoitsu
                add_yaku(:chitoitsu, 2, 0)
              end
              if @mentsus.all?(){ |m| [:kotsu, :kantsu].include?(m.type) }
                add_yaku(:toitoiho, 2, 2)
              end
              if self.n_anko?(3)
                add_yaku(:sananko, 2, 2)
              end
              if @all_pais.all?(){ |pai| pai.yaochu? }
                add_yaku(:honroto, 2, 2)
                delete_yaku(:honchantaiyao)
              end
              if self.sanshoku?([:kotsu, :kantsu])
                add_yaku(:sanshokudoko, 2, 2)
              end
              if self.n_kantsu?(3)
                add_yaku(:sankantsu, 2, 2)
              end
              if self.shosangen?
                add_yaku(:shosangen, 2, 2)
              end
              if @hora.double_reach
                add_yaku(:double_reach, 2, 0)
                delete_yaku(:reach)
              end
              
              # 三飜
              if self.honiso?
                add_yaku(:honiso, 3, 2)
              end
              if self.junchantaiyao?
                add_yaku(:junchantaiyao, 3, 2)
                delete_yaku(:honchantaiyao)
              end
              if self.ryanpeko?
                add_yaku(:ryanpeko, 3, 0)
                delete_yaku(:ipeko)
              end
              
              # 六飜
              if self.chiniso?
                add_yaku(:chiniso, 6, 5)
                delete_yaku(:honiso)
              end
              
            end
            
            def add_yaku(name, menzen_fan, kui_fan)
              fan = self.menzen? ? menzen_fan : kui_fan
              @yakus.push([name, fan]) if fan > 0
            end
            
            def delete_yaku(name)
              @yakus.delete_if(){ |n, f| n == name }
            end
            
            def get_fu()
              case @combination
                when :chitoitsu
                  return 25
                when :kokushimuso
                  return 20
                else
                  fu = 20
                  fu += 10 if self.menzen? && @hora.hora_type == :ron
                  fu += 2 if @hora.hora_type == :tsumo && !pinfu?
                  for mentsu in @mentsus
                    mfu = BASE_FU_MAP[mentsu.type]
                    mfu *= 2 if mentsu.pais[0].yaochu?
                    mfu *= 2 if mentsu.visibility == :an
                    fu += mfu
                  end
                  fu += fanpai_fan(@janto.pais[0]) * 2
                  fu += 2 if [:kanchan, :penchan, :tanki].include?(@machi)
                  #p [:raw_fu, fu]
                  return (fu / 10.0).ceil * 10
              end
            end
            
            def menzen?
              return @hora.furos.select(){ |f| f.type != :ankan }.empty?
            end
            
            def ryuiso?
              return @all_pais.all?(){ |pai| GREEN_PAIS.include?(pai) }
            end
            
            def chinroto?
              return @all_pais.all?(){ |pai| pai.type != "t" && [1, 9].include?(pai.number) }
            end
            
            def daisushi?
              return @mentsus.all?(){ |m| [:kotsu, :kantsu].include?(m.type) && m.pais[0].fonpai? }
            end
            
            def shosushi?
              fonpai_kotsus = @mentsus.
                  select(){ |m| [:kotsu, :kantsu].include?(m.type) && m.pais[0].fonpai? }
              return fonpai_kotsus.size == 3 && @janto.pais[0].fonpai?
            end
            
            def churenpoton?
              return false if !self.chiniso?
              all_numbers = @all_pais.map(){ |pai| pai.number }.sort()
              return (1..9).any?() do |i|
                all_numbers == (CHURENPOTON_NUMBERS + [i]).sort()
              end
            end
            
            def pinfu?
              return @mentsus.all?(){ |m| m.type == :shuntsu } &&
                  @machi == :ryanmen &&
                  fanpai_fan(@janto.pais[0]) == 0
            end
            
            def ipeko?
              return @mentsus.any?() do |m1|
                m1.type == :shuntsu &&
                    @mentsus.any?() do |m2|
                      !m2.equal?(m1) && m2.type == :shuntsu && m2.pais[0].same_symbol?(m1.pais[0])
                    end
              end
            end
            
            def jikaze?
              @mentsus.any?(){ |m| [:kotsu, :kantsu].include?(m.type) && m.pais[0] == @hora.jikaze }
            end
            
            def bakaze?
              @mentsus.any?(){ |m| [:kotsu, :kantsu].include?(m.type) && m.pais[0] == @hora.bakaze }
            end
            
            def sanshoku?(types)
              return @mentsus.any?() do |m1|
                types.include?(m1.type) &&
                    ["m", "p", "s"].all?() do |t|
                      @mentsus.any?() do |m2|
                        types.include?(m2.type) && m2.pais[0].same_symbol?(Pai.new(t, m1.pais[0].number))
                      end
                    end
              end
            end
            
            def ikkitsukan?
              return ["m", "p", "s"].any?() do |t|
                [1, 4, 7].all?() do |n|
                  @mentsus.any?(){ |m| m.type == :shuntsu && m.pais[0].same_symbol?(Pai.new(t, n)) }
                end
              end
            end
            
            def honchantaiyao?
              return (@mentsus + [@janto]).all?(){ |m| m.pais.any?(){ |pai| pai.yaochu? } }
            end
            
            def n_anko?(n)
              ankos = @mentsus.select() do |m|
                [:kotsu, :kantsu].include?(m.type) && m.visibility == :an
              end
              return ankos.size == n
            end
            
            def n_kantsu?(n)
              return @mentsus.select(){ |m| m.type == :kantsu }.size == n
            end
            
            def shosangen?
              return self.num_sangenpais == 2 && @janto.pais[0].sangenpai?
            end
            
            def honiso?
              return ["m", "p", "s"].any?() do |t|
                @all_pais.all?(){ |pai| [t, "t"].include?(pai.type) }
              end
            end
            
            def junchantaiyao?
              return (@mentsus + [@janto]).all?() do |m|
                m.pais.any?(){ |pai| pai.type != "t" && [1, 9].include?(pai.number) }
              end
            end
            
            def ryanpeko?
              return @mentsus.all?() do |m1|
                m1.type == :shuntsu &&
                    @mentsus.any?() do |m2|
                      !m2.equal?(m1) && m2.type == :shuntsu && m2.pais[0].same_symbol?(m1.pais[0])
                    end
              end
            end
            
            def chiniso?
              return ["m", "p", "s"].any?() do |t|
                @all_pais.all?(){ |pai| pai.type == t }
              end
            end
            
            def num_sangenpais
              return @mentsus.
                  select(){ |m| m.pais[0].sangenpai? && [:kotsu, :kantsu].include?(m.type) }.
                  size
            end
            
            def fanpai_fan(pai)
              if pai.sangenpai?
                return 1
              else
                fan = 0
                fan += 1 if pai == @hora.bakaze
                fan += 1 if pai == @hora.jikaze
                return fan
              end
            end
            
        end
        
        extend(WithFields)
        extend(Forwardable)
        
        define_fields([
          :tehais, :furos, :taken, :hora_type,
          :oya, :bakaze, :jikaze, :doras, :uradoras,
          :reach, :double_reach, :ippatsu,
          :rinshan, :haitei, :first_turn, :chankan,
        ])
        
        def initialize(params)
          
          @fields = params
          raise("tehais is missing") if !self.tehais
          raise("taken is missing") if !self.taken
          
          @free_pais = self.tehais + [self.taken]
          @all_pais = @free_pais + self.furos.map(){ |f| f.pais }.flatten()
          
          @num_doras = count_doras(self.doras)
          @num_uradoras = count_doras(self.uradoras)
          @num_akadoras = @all_pais.select(){ |pai| pai.red? }.size
          
          num_same_as_taken = @free_pais.select(){ |pai| pai.same_symbol?(self.taken) }.size
          @shanten = ShantenAnalysis.new(@free_pais, -1)
          raise("not hora") if @shanten.shanten > -1
          unflatten_cands = @shanten.combinations.map() do |c|
            (0...num_same_as_taken).map(){ |i| Candidate.new(self, c, i) }
          end
          @candidates = unflatten_cands.flatten()
          @best_candidate = @candidates.max_by(){ |c| c.points }
          
        end
        
        attr_reader(:free_pais, :all_pais, :num_doras, :num_uradoras, :num_akadoras)
        def_delegators(:@best_candidate,
            :valid?, :points, :oya_payment, :ko_payment, :yakus, :fan, :fu)
        
        def count_doras(target_doras)
          return @all_pais.map(){ |pai| target_doras.select(){ |d| d.same_symbol?(pai) }.size }.
              inject(0, :+)
        end
        
    end
    
end
