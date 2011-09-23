require "./mahjong"


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
    
    class Candidate
        
        def initialize(hora, combination, taken_index)
          
          @hora = hora
          @combination = combination
          @mentsus = []
          @janto = nil
          total_taken = 0
          if combination == :chitoitsu
            raise("not implemented")
          else
            for mentsu_type, mentsu_pais in combination
              num_this_taken = mentsu_pais.select(){ |pai| pai.same_symbol?(hora.taken) }.size
              has_taken = taken_index >= total_taken && taken_index < total_taken + num_this_taken
              if mentsu_type == :toitsu
                raise("should not happen") if @janto
                @janto = Mentsu.new(:toitsu, nil, mentsu_pais)
              else
                @mentsus.push(Mentsu.new(mentsu_type, has_taken ? :min : :an, mentsu_pais))
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
                (furo.consumed + [furo.taken]).sort()))
          end
          p @mentsus
          p @janto
          p @machi
          get_yakus()
          p @yakus
          @fans = @yakus.map(){ |y, f| f }.inject(0, :+)
          p [:fans, @fans]
          @fu = get_fu()
          p [:fu, @fu]
          
          if @fans >= 13
            @base_points = 8000
          elsif @fans >= 11
            @base_points = 6000
          elsif @fans >= 8
            @base_points = 4000
          elsif @fans >= 6
            @base_points = 3000
          elsif @fans >= 5 || (@fans >= 4 && @fu >= 40) || (@fans >= 3 && @fu >= 70)
            @base_points = 2000
          else
            @base_points = @fu * (2 ** (@fans + 2))
          end
          
          if @hora.hora_type == :ron
            @oya_payment = @ko_payment = @points =
                ceil_points(@base_points * (@hora.oya ? 6 : 4))
          else
            if @hora.oya
              @ko_payment = ceil_points(@base_points * 2)
              @oya_payment = 0
              @points = @ko_payment * 3
            else
              @oya_payment = ceil_points(@base_points * 2)
              @ko_payment = ceil_points(@base_points)
              @points = @oya_payment + @ko_payment * 2
            end
          end
          p [:points, @points, @oya_payment, @ko_payment]
          
        end
        
        attr_reader(:points, :oya_payment, :ko_payment)
        
        def ceil_points(points)
          return (points / 100.0).ceil * 100
        end
        
        # http://ja.wikipedia.org/wiki/%E9%BA%BB%E9%9B%80%E3%81%AE%E5%BD%B9%E4%B8%80%E8%A6%A7
        def get_yakus()
          
          @yakus = []
          
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
          if @hora.pais.all?(){ |pai| !pai.yaochu? }
            add_yaku(:tanyaochu, 1, 1)
          end
          if self.pinfu?
            add_yaku(:pinfu, 1, 0)
          end
          if self.ipeko?
            add_yaku(:ipeko, 1, 0)
          end
          add_yaku(:sangenpai, self.num_sangenpais, self.num_sangenpais)
          if @mentsus.any?(){ |m| m.pais[0] == @hora.jikaze }
            add_yaku(:jikaze, 1, 1)
          end
          if @mentsus.any?(){ |m| m.pais[0] == @hora.bakaze }
            add_yaku(:bakaze, 1, 1)
          end
          if @hora.rinshan
            add_yaku(:rinshan, 1, 1)
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
          if @mentsus.all?(){ |m| [:kotsu, :kantsu].include?(m.type) }
            add_yaku(:toitoiho, 2, 2)
          end
          if self.n_anko?(3)
            add_yaku(:sananko, 2, 2)
          end
          if @hora.pais.all?(){ |pai| pai.yaochu? }
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
          
          # TODO 役満
          
        end
        
        def add_yaku(name, menzen_fans, kui_fans)
          fans = self.menzen? ? menzen_fans : kui_fans
          @yakus.push([name, fans]) if fans > 0
        end
        
        def delete_yaku(name)
          @yakus.delete_if(){ |n, f| n == name }
        end
        
        def get_fu()
          fu = 20
          fu += 10 if self.menzen? && @hora.hora_type == :ron
          fu += 2 if @hora.hora_type == :tsumo
          for mentsu in @mentsus
            mfu = BASE_FU_MAP[mentsu.type]
            mfu *= 2 if mentsu.pais[0].yaochu?
            mfu *= 2 if mentsu.visibility == :an
            p [:mfu, mfu]
            fu += mfu
          end
          fu += fanpai_fans(@janto.pais[0]) * 2
          fu += 2 if [:kanchan, :penchan, :tanki].include?(@machi)
          p [:raw_fu, fu]
          return (fu / 10.0).ceil * 10
        end
        
        def menzen?
          return @hora.furos.empty?
        end
        
        def pinfu?
          return @mentsus.all?(){ |m| m.type == :shuntsu } &&
              @machi == :ryanmen &&
              fanpai_fans(@janto.pais[0]) == 0
        end
        
        def ipeko?
          return @mentsus.any?() do |m1|
            m1.type == :shuntsu &&
                @mentsus.any?() do |m2|
                  !m2.equal?(m1) && m2.type == :shuntsu && m2.pais[0].same_symbol?(m1.pais[0])
                end
          end
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
            (@mentsus + [@janto]).all?(){ |m| [t, "t"].include?(m.pais[0].type) }
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
            (@mentsus + [@janto]).all?(){ |m| m.pais[0].type == t }
          end
        end
        
        def num_sangenpais
          return @mentsus.select(){ |m| m.pais[0].sangenpai? }.size
        end
        
        def fanpai_fans(pai)
          if pai.sangenpai?
            return 1
          else
            fans = 0
            fans += 1 if pai == @hora.bakaze
            fans += 1 if pai == @hora.jikaze
            return fans
          end
        end
        
    end
    
    extend(WithFields)
    
    define_fields([
      :tehais, :furos, :taken, :hora_type, :bakaze, :jikaze, :reach, :double_reach, :ippatsu,
      :rinshan, :haitei,
      :chankan,
      :oya,
    ])
    
    def initialize(params)
      
      @fields = params
      @pais = self.tehais + [self.taken]
      num_same_as_taken = @pais.select(){ |pai| pai.same_symbol?(self.taken) }.size
      @shanten = ShantenCounter.new(@pais, -1)
      raise("not hora") if @shanten.shanten > -1
      unflatten_cands = @shanten.combinations.map() do |c|
        (0...num_same_as_taken).map(){ |i| Candidate.new(self, c, i) }
      end
      @candidates = unflatten_cands.flatten()
      @best_candidate = @candidates.max_by(){ |c| c.points }
      
    end
    
    attr_reader(:pais)
    
end

p 1
Hora.new({
  :tehais => Pai.parse_pais("123m456p777sP"),
  :furos => [Furo.new({:type => :pon, :taken => Pai.new("E"), :consumed => Pai.parse_pais("EE")})],
  :taken => Pai.new("P"),
  :hora_type => :ron,
  :jikaze => Pai.new("S"),
  :bakaze => Pai.new("E"),
  :oya => false,
})
puts

p 2
Hora.new({
  :tehais => Pai.parse_pais("234678m345p3477s"),
  :furos => [],
  :taken => Pai.new("5s"),
  :hora_type => :ron,
  :oya => false,
})
puts

p 2.1
Hora.new({
  :tehais => Pai.parse_pais("234678m345p3477s"),
  :furos => [],
  :taken => Pai.new("5s"),
  :hora_type => :tsumo,
  :oya => false,
})
puts

p 3
Hora.new({
  :tehais => Pai.parse_pais("111999m33sSS"),
  :furos => [
    Furo.new({:type => :pon, :taken => Pai.new("E"), :consumed => Pai.parse_pais("EE")}),
  ],
  :taken => Pai.new("3s"),
  :hora_type => :ron,
  :jikaze => Pai.new("S"),
  :bakaze => Pai.new("S"),
  :oya => true,
})
puts

p 4
Hora.new({
  :tehais => Pai.parse_pais("11144m55sPPP"),
  :furos => [
    Furo.new({:type => :pon, :taken => Pai.new("E"), :consumed => Pai.parse_pais("EE")}),
  ],
  :taken => Pai.new("4m"),
  :hora_type => :ron,
  :jikaze => Pai.new("E"),
  :bakaze => Pai.new("S"),
  :oya => false,
})
puts

p 5
Hora.new({
  :tehais => Pai.parse_pais("2233444556688m"),
  :furos => [],
  :taken => Pai.new("7m"),
  :hora_type => :ron,
  :oya => false,
})
puts
