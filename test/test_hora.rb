$LOAD_PATH.unshift(File.dirname(__FILE__) + "/../lib")

require "test/unit"

require "mjai/hora"
require "mjai/furo"


class TC_Hora < Test::Unit::TestCase
    
    include(Mjai)
    
    DEFAULT_PARAMS = {
      :furos => [],
      :bakaze => Pai.new("E"),
      :jikaze => Pai.new("S"),
      :doras => Pai.parse_pais("2m"),
      :uradoras => Pai.parse_pais("2s"),
      :reach => false,
      :double_reach => false,
      :ippatsu => false,
      :rinshan => false,
      :haitei => false,
      :first_turn => false,
      :chankan => false,
      :oya => false,
    }
    
    def new_hora(params)
      return Hora.new(DEFAULT_PARAMS.merge(params))
    end
    
    def has_yaku?(yaku, params)
      return new_hora(params).yakus.include?(yaku)
    end
    
    def test_yaku()
      
      assert(has_yaku?([:dora, 1], {
        :tehais => Pai.parse_pais("234678m345p3477s"),
        :taken => Pai.new("5s"),
        :hora_type => :ron,
      }))
      
      assert(has_yaku?([:uradora, 1], {
        :tehais => Pai.parse_pais("234678m345p3477s"),
        :taken => Pai.new("2s"),
        :hora_type => :ron,
      }))
      
      assert(has_yaku?([:akadora, 1], {
        :tehais => Pai.parse_pais("234678m34p5pr3477s"),
        :taken => Pai.new("5s"),
        :hora_type => :ron,
      }))
      
      assert(has_yaku?([:reach, 1], {
        :tehais => Pai.parse_pais("234678m345p3477s"),
        :taken => Pai.new("5s"),
        :hora_type => :ron,
        :reach => true,
      }))
      
      assert(has_yaku?([:ippatsu, 1], {
        :tehais => Pai.parse_pais("234678m345p3477s"),
        :taken => Pai.new("5s"),
        :hora_type => :ron,
        :reach => true,
        :ippatsu => true,
      }))
      
      assert(has_yaku?([:menzenchin_tsumoho, 1], {
        :tehais => Pai.parse_pais("234678m345p3477s"),
        :taken => Pai.new("5s"),
        :hora_type => :tsumo,
      }))
      
      assert(has_yaku?([:tanyaochu, 1], {
        :tehais => Pai.parse_pais("234678m345p3477s"),
        :taken => Pai.new("5s"),
        :hora_type => :ron,
      }))

      assert(has_yaku?([:pinfu, 1], {
        :tehais => Pai.parse_pais("234678m345p3477s"),
        :taken => Pai.new("5s"),
        :hora_type => :ron,
      }))
      
      assert(has_yaku?([:ipeko, 1], {
        :tehais => Pai.parse_pais("223344m345p3477s"),
        :taken => Pai.new("5s"),
        :hora_type => :ron,
      }))
      
      assert(has_yaku?([:sangenpai, 1], {
        :tehais => Pai.parse_pais("234678m3477sPPP"),
        :taken => Pai.new("5s"),
        :hora_type => :ron,
      }))
      
      assert(has_yaku?([:bakaze, 1], {
        :tehais => Pai.parse_pais("123m456p777sP"),
        :furos =>
            [Furo.new({:type => :pon, :taken => Pai.new("E"), :consumed => Pai.parse_pais("EE")})],
        :taken => Pai.new("P"),
        :hora_type => :ron,
      }))
      
      assert(has_yaku?([:jikaze, 1], {
        :tehais => Pai.parse_pais("123m456p777sP"),
        :furos =>
            [Furo.new({:type => :pon, :taken => Pai.new("S"), :consumed => Pai.parse_pais("SS")})],
        :taken => Pai.new("P"),
        :hora_type => :ron,
      }))
      
      assert(has_yaku?([:rinshankaiho, 1], {
        :tehais => Pai.parse_pais("234678m345p3477s"),
        :taken => Pai.new("5s"),
        :hora_type => :tsumo,
        :rinshan => true,
      }))
      
      assert(has_yaku?([:chankan, 1], {
        :tehais => Pai.parse_pais("234678m345p3477s"),
        :taken => Pai.new("5s"),
        :hora_type => :ron,
        :chankan => true,
      }))
      
      assert(has_yaku?([:haiteiraoyue, 1], {
        :tehais => Pai.parse_pais("234678m345p3477s"),
        :taken => Pai.new("5s"),
        :hora_type => :tsumo,
        :haitei => true,
      }))
      
      assert(has_yaku?([:hoteiraoyui, 1], {
        :tehais => Pai.parse_pais("234678m345p3477s"),
        :taken => Pai.new("5s"),
        :hora_type => :ron,
        :haitei => true,
      }))
      
      assert(has_yaku?([:sanshokudojun, 2], {
        :tehais => Pai.parse_pais("234m234p23478sWW"),
        :taken => Pai.new("9s"),
        :hora_type => :ron,
      }))
      
      assert(has_yaku?([:sanshokudojun, 1], {
        :tehais => Pai.parse_pais("234m23478sWW"),
        :furos => 
            [Furo.new({:type => :chi, :taken => Pai.new("2p"), :consumed => Pai.parse_pais("34p")})],
        :taken => Pai.new("9s"),
        :hora_type => :ron,
      }))
      
      assert(has_yaku?([:ikkitsukan, 2], {
        :tehais => Pai.parse_pais("123456789m78sWW"),
        :taken => Pai.new("9s"),
        :hora_type => :ron,
      }))
      
      assert(has_yaku?([:honchantaiyao, 2], {
        :tehais => Pai.parse_pais("123789m12389sWW"),
        :taken => Pai.new("7s"),
        :hora_type => :ron,
      }))
      
      assert(has_yaku?([:chitoitsu, 2], {
        :tehais => Pai.parse_pais("114477m225588p3s"),
        :taken => Pai.new("3s"),
        :hora_type => :ron,
      }))
      
      assert(has_yaku?([:toitoiho, 2], {
        :tehais => Pai.parse_pais("111999m33sSS"),
        :furos => [
          Furo.new({:type => :pon, :taken => Pai.new("E"), :consumed => Pai.parse_pais("EE")}),
        ],
        :taken => Pai.new("3s"),
        :hora_type => :ron,
      }))
      
      assert(has_yaku?([:sananko, 2], {
        :tehais => Pai.parse_pais("111999m333s23pSS"),
        :taken => Pai.new("1p"),
        :hora_type => :ron,
      }))
      
      assert(has_yaku?([:honroto, 2], {
        :tehais => Pai.parse_pais("111999m11199pEE"),
        :taken => Pai.new("9p"),
        :hora_type => :ron,
      }))
      
      assert(has_yaku?([:sanshokudoko, 2], {
        :tehais => Pai.parse_pais("333m333p33567sSS"),
        :taken => Pai.new("3s"),
        :hora_type => :ron,
      }))
      
      assert(has_yaku?([:sankantsu, 2], {
        :tehais => Pai.parse_pais("23pSS"),
        :furos => [
          Furo.new({:type => :daiminkan,
              :taken => Pai.new("2m"), :consumed => Pai.parse_pais("222m")}),
          Furo.new({:type => :daiminkan,
              :taken => Pai.new("4m"), :consumed => Pai.parse_pais("444m")}),
          Furo.new({:type => :kakan,
              :taken => Pai.new("6m"), :consumed => Pai.parse_pais("666m")}),
        ],
        :taken => Pai.new("1p"),
        :hora_type => :ron,
      }))
      
      assert(has_yaku?([:shosangen, 2], {
        :tehais => Pai.parse_pais("23m456pFFFPPPCC"),
        :taken => Pai.new("1m"),
        :hora_type => :ron,
      }))
      
      assert(has_yaku?([:double_reach, 2], {
        :tehais => Pai.parse_pais("234678m345p3477s"),
        :taken => Pai.new("5s"),
        :hora_type => :ron,
        :reach => true,
        :double_reach => true,
      }))
      
      assert(has_yaku?([:honiso, 3], {
        :tehais => Pai.parse_pais("1112334459mFFF"),
        :taken => Pai.new("9m"),
        :hora_type => :ron,
      }))
      
      assert(has_yaku?([:junchantaiyao, 3], {
        :tehais => Pai.parse_pais("123789m12389s99p"),
        :taken => Pai.new("7s"),
        :hora_type => :ron,
      }))
      
      assert(has_yaku?([:ryanpeko, 3], {
        :tehais => Pai.parse_pais("112233m66778pSS"),
        :taken => Pai.new("8p"),
        :hora_type => :ron,
      }))
      
      assert(has_yaku?([:chiniso, 6], {
        :tehais => Pai.parse_pais("1112334457779m"),
        :taken => Pai.new("9m"),
        :hora_type => :ron,
      }))
      
      assert(has_yaku?([:tenho, Hora::YAKUMAN_FAN], {
        :tehais => Pai.parse_pais("234678m345p3477s"),
        :taken => Pai.new("5s"),
        :hora_type => :tsumo,
        :oya => true,
        :first_turn => true,
      }))
      
      assert(has_yaku?([:chiho, Hora::YAKUMAN_FAN], {
        :tehais => Pai.parse_pais("234678m345p3477s"),
        :taken => Pai.new("5s"),
        :hora_type => :tsumo,
        :oya => false,
        :first_turn => true,
      }))
      
      assert(has_yaku?([:kokushimuso, Hora::YAKUMAN_FAN], {
        :tehais => Pai.parse_pais("119m19p19sESWNFP"),
        :taken => Pai.new("C"),
        :hora_type => :ron,
      }))
      
      assert(has_yaku?([:daisangen, Hora::YAKUMAN_FAN], {
        :tehais => Pai.parse_pais("23m44pPPPFFFCCC"),
        :taken => Pai.new("1m"),
        :hora_type => :ron,
      }))
      
      assert(has_yaku?([:suanko, Hora::YAKUMAN_FAN], {
        :tehais => Pai.parse_pais("111999m333s33pSS"),
        :taken => Pai.new("3p"),
        :hora_type => :tsumo,
      }))
      
      assert(has_yaku?([:tsuiso, Hora::YAKUMAN_FAN], {
        :tehais => Pai.parse_pais("EEESSSNNNPPCC"),
        :taken => Pai.new("P"),
        :hora_type => :ron,
      }))
      
      assert(has_yaku?([:ryuiso, Hora::YAKUMAN_FAN], {
        :tehais => Pai.parse_pais("22334466888FFs"),
        :taken => Pai.new("F"),
        :hora_type => :ron,
      }))
      
      assert(has_yaku?([:chinroto, Hora::YAKUMAN_FAN], {
        :tehais => Pai.parse_pais("111999m11199p11s"),
        :taken => Pai.new("9p"),
        :hora_type => :ron,
      }))
      
      assert(has_yaku?([:daisushi, Hora::YAKUMAN_FAN], {
        :tehais => Pai.parse_pais("11mEEESSSWWWNN"),
        :taken => Pai.new("N"),
        :hora_type => :ron,
      }))
      
      assert(has_yaku?([:shosushi, Hora::YAKUMAN_FAN], {
        :tehais => Pai.parse_pais("11mEEESSSWWWNN"),
        :taken => Pai.new("1m"),
        :hora_type => :ron,
      }))
      
      assert(has_yaku?([:sukantsu, Hora::YAKUMAN_FAN], {
        :tehais => Pai.parse_pais("S"),
        :furos => [
          Furo.new({:type => :daiminkan,
              :taken => Pai.new("2m"), :consumed => Pai.parse_pais("222m")}),
          Furo.new({:type => :daiminkan,
              :taken => Pai.new("4m"), :consumed => Pai.parse_pais("444m")}),
          Furo.new({:type => :kakan,
              :taken => Pai.new("6m"), :consumed => Pai.parse_pais("666m")}),
          Furo.new({:type => :ankan, :consumed => Pai.parse_pais("8888m")}),
        ],
        :taken => Pai.new("S"),
        :hora_type => :ron,
      }))
      
      assert(has_yaku?([:churenpoton, Hora::YAKUMAN_FAN], {
        :tehais => Pai.parse_pais("1111235678999m"),
        :taken => Pai.new("4m"),
        :hora_type => :ron,
      }))
      
      assert(has_yaku?([:churenpoton, Hora::YAKUMAN_FAN], {
        :tehais => Pai.parse_pais("1112345678999m"),
        :taken => Pai.new("1m"),
        :hora_type => :ron,
      }))
      
    end
    
    def test_valid()
      
      assert(new_hora({
        :tehais => Pai.parse_pais("56799m11134678s"),
        :taken => Pai.new("5s"),
        :hora_type => :ron,
        :reach => true,
      }).valid?)
      
      assert(!new_hora({
        :tehais => Pai.parse_pais("56799m11134678s"),
        :taken => Pai.new("5s"),
        :hora_type => :ron,
        :reach => false,
      }).valid?)
      
    end
    
    def test_fu()

      assert_equal(30, new_hora({
        :tehais => Pai.parse_pais("234678m345p3477s"),
        :taken => Pai.new("5s"),
        :hora_type => :ron,
      }).fu)

      assert_equal(20, new_hora({
        :tehais => Pai.parse_pais("234678m345p3477s"),
        :taken => Pai.new("5s"),
        :hora_type => :tsumo,
      }).fu)

      assert_equal(30, new_hora({
        :tehais => Pai.parse_pais("234678m3477s"),
        :furos => [
          Furo.new({:type => :chi, :taken => Pai.new("2p"), :consumed => Pai.parse_pais("34p")})
        ],
        :taken => Pai.new("5s"),
        :hora_type => :ron,
      }).fu)

      assert_equal(30, new_hora({
        :tehais => Pai.parse_pais("234678m3477s"),
        :furos => [
          Furo.new({:type => :chi, :taken => Pai.new("2p"), :consumed => Pai.parse_pais("34p")})
        ],
        :taken => Pai.new("5s"),
        :hora_type => :tsumo,
      }).fu)

    end
    
    def test_points()
      # TODO
    end
    
end
