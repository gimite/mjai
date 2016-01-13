require "mjai/shanten_analysis"
require "mjai/pai"


module Mjai
    
    class TenpaiAnalysis
        
        ALL_YAOCHUS = Pai.parse_pais("19m19s19pESWNPFC")
        
        def initialize(pais)
          @pais = pais
          @shanten = ShantenAnalysis.new(@pais, 0)
        end
        
        def tenpai?
          return @shanten.shanten == 0 &&
              # 打牌選択可能な手牌で待ちを使いきっている場合を除外
              ( @pais.size % 3 != 1 || self.waited_pais.any?{ |w| @pais.select{ |t| t.remove_red == w }.size < 4 } )
        end
        
        def waited_pais
          raise(ArgumentError, "invalid number of pais") if @pais.size % 3 != 1
          raise("not tenpai") if @shanten.shanten != 0
          pai_set = Hash.new(0)
          for pai in @pais
            pai_set[pai.remove_red()] += 1
          end
          result = []
          for mentsus in @shanten.combinations
            case mentsus
              when :chitoitsu
                result.push(pai_set.find(){ |pai, n| n == 1 }[0])
              when :kokushimuso
                missing = ALL_YAOCHUS - pai_set.keys
                if missing.empty?
                  result += ALL_YAOCHUS
                else
                  result.push(missing[0])
                end
              else
                case mentsus.select(){ |t, ps| t == :toitsu }.size
                  when 0  # 単騎
                    (type, pais) = mentsus.find(){ |t, ps| t == :single }
                    result.push(pais[0])
                  when 1  # 両面、辺張、嵌張
                    (type, pais) = mentsus.find(){ |t, ps| [:ryanpen, :kanta].include?(t) }
                    relative_numbers = type == :ryanpen ? [-1, 2] : [1]
                    result += relative_numbers.map(){ |r| pais[0].number + r }.
                        select(){ |n| (1..9).include?(n) }.
                        map(){ |n| Pai.new(pais[0].type, n) }
                  when 2  # 双碰
                    result += mentsus.select(){ |t, ps| t == :toitsu }.map(){ |t, ps| ps[0] }
                  else
                    raise("should not happen")
                end
            end
          end
          return result.sort().uniq()
        end
        
    end
    
end
