require "json"


class Pai
    
    include(Comparable)
    
    TSUPAI_STRS = " ESWNPFC".split(//)
    
    def self.parse_pais(str)
      type = nil
      pais = []
      red = false
      str.split(//).reverse_each() do |ch|
        if ch =~ /^[mps]$/
          type = ch
        elsif ch =~ /^[1-9]$/
          raise(ArgumentError, "type required after number") if !type
          pais.push(Pai.new(type, ch.to_i(), red))
          red = false
        elsif TSUPAI_STRS.include?(ch)
          pais.push(Pai.new(ch))
        elsif ch == "r"
          red = true
        else
          raise(ArgumentError, "unexpected character: %s", ch)
        end
      end
      return pais.reverse()
    end
    
    def self.dump_pais(pais)
      return pais.map(){ |pai| "%-2s" % pai }.join(" ")
    end
    
    def initialize(*args)
      case args.size
        when 1
          str = args[0]
          if str == "?"
            @type = @number = nil
            @red = false
          elsif str =~ /^([1-9])([mps])(r)?$/
            @type = $2
            @number = $1.to_i()
            @red = $3 != nil
          elsif number = TSUPAI_STRS.index(str)
            @type = "t"
            @number = number
            @red = false
          else
            raise(ArgumentError, "unknown pai string: %s" % str)
          end
        when 2, 3
          (@type, @number, @red) = args
          @red = false if @red == nil
        else
          raise(ArgumentError, "wrong number of args")
      end
    end
    
    def to_s()
      if !@type
        return "?"
      elsif @type == "t"
        return TSUPAI_STRS[@number]
      else
        return "%d%s%s" % [@number, @type, @red ? "r" : ""]
      end
    end
    
    def inspect
      return "Pai[%s]" % self.to_s()
    end
    
    attr_reader(:type, :number)
    
    def red?
      return @red
    end
    
    def data
      return [@type, @number, @red]
    end
    
    def ==(other)
      return self.class == other.class && self.data == other.data
    end
    
    alias eql? ==
    
    def hash()
      return self.data.hash()
    end
    
    def <=>(other)
      if self.class == other.class
        return self.data <=> other.data
      else
        raise(ArgumentError, "invalid comparison")
      end
    end
    
    def remove_red()
      return Pai.new(@type, @number)
    end
    
    UNKNOWN = Pai.new(nil, nil)
    
end


# 副露
class Furo
    
    PARAM_NAMES = [:type, :taken, :consumed, :target]
    
    PARAM_NAMES.each() do |name|
      define_method(name) do
        return @params[name]
      end
    end
    
    def initialize(params)
      @params = params
    end
    
    def to_s()
      if self.type == :ankan
        return '[# %s %s #]' % self.consumed[0, 2]
      else
        return "[%s(%d)/%s]" % [self.taken, self.target.id, self.consumed.join(" ")]
      end
    end
    
end


#pais = Pai.parse_pais("123m4p5pr6p789sESWNPFC")
#p pais
#p pais.map(){ |h| [h.type, h.number, h.red?] }


class Action
    
    PARAM_NAMES = [:type, :actor, :target, :pai, :consumed, :pais, :id]
    
    def self.from_json(json, board)
      hash = JSON.parse(json)
      params = {}
      params[:type] = hash["type"].intern()
      params[:actor] = board.players[hash["actor"]] if hash["actor"]
      params[:target] = board.players[hash["target"]] if hash["target"]
      params[:pai] = Pai.new(hash["pai"]) if hash["pai"]
      params[:consumed] = hash["consumed"].map(){ |s| Pai.new(s) } if hash["consumed"]
      params[:pais] = hash["pais"].map(){ |s| Pai.new(s) } if hash["pais"]
      params[:id] = hash["id"] if hash["id"]
      return new(params)
    end
    
    PARAM_NAMES.each() do |name|
      define_method(name) do
        return @params[name]
      end
    end
    
    def initialize(params)
      for k, v in params
        if !PARAM_NAMES.include?(k)
          raise(ArgumentError, "unknown param: %p" % k)
        end
      end
      @params = params
    end
    
    def to_json()
      hash = {}
      hash["type"] = self.type.to_s()
      hash["actor"] = self.actor.id if self.actor
      hash["target"] = self.target.id if self.target
      hash["pai"] = self.pai.to_s() if self.pai
      hash["consumed"] = self.consumed.map(){ |a| a.to_s() } if self.consumed
      hash["pais"] = self.pais.map(){ |a| a.to_s() } if self.pais
      hash["id"] = self.id if self.id
      return JSON.dump(hash)
    end
    
end


class Player
    
    def initialize()
      @points = 25000
    end
    
    attr_reader(:id)
    attr_reader(:tehais)  # 手牌
    attr_reader(:furos)  # 副露
    attr_reader(:ho)  # 河
    attr_accessor(:board)
    
    def process_action(action)
      case action.type
        when :start_game
          @id = action.id
        when :start_kyoku
          @tehais = []
          @furos = []
          @ho = []
        when :haipai
          if action.actor == self
            @tehais = action.pais.sort()
          end
        when :tsumo
          if action.actor == self
            @tehais.push(action.pai)
          end
        when :dahai
          if action.actor == self
            delete_tehai(action.pai)
            @tehais.sort!()
            @ho.push(action.pai)
          end
        when :chi, :pon, :daiminkan, :ankan
          if action.actor == self
            for pai in action.consumed
              delete_tehai(pai)
            end
            @furos.push(Furo.new({
              :type => action.type,
              :taken => action.pai,
              :consumed => action.consumed,
              :target => action.target,
            }))
          elsif action.target == self
            pai = @ho.pop()
            raise("should not happen") if pai != action.pai
          end
        when :kakan
          if action.actor == self
            delete_tehai(action.pai)
            pon_index = @furos.index(){ |f| f.type == :pon && f.taken == action.pai }
            raise("should not happen") if !pon_index
            @furos[pon_index] = Furo.new({
              :type => :kakan,
              :taken => @furos[pon_index].taken,
              :consumed => @furos[pon_index].consumed + [action.pai],
              :target => @furos[pon_index].target,
            })
          end
      end
    end
    
    def delete_tehai(pai)
      pai_index = @tehais.index(pai)
      raise("should not happen") if !pai_index
      @tehais.delete_at(pai_index)
    end
    
    def create_action(params = {})
      return Action.new({:actor => self}.merge(params))
    end
    
    def inspect
      return "\#<%p:%d>" % [self.class, self.id]
    end
    
end


class TsumogiriPlayer < Player
    
    def respond_to_action(action)
      case action.type
        when :tsumo, :chi, :pon
          if action.actor == self
            return create_action({:type => :dahai, :pai => self.tehais[-1]})
          end
      end
      return nil
    end
    
end


class ShantenPlayer < Player
    
    def respond_to_action(action)
      case action.type
        
        when :tsumo, :chi, :pon
          if action.actor == self
            if action.type == :tsumo
              for pai in self.tehais
                if self.tehais.select(){ |tp| tp == pai }.size >= 4
                  #@board.last = true
                  return create_action({:type => :ankan, :consumed => [pai] * 4})
                end
              end
              pon = self.furos.find(){ |f| f.type == :pon && f.taken == action.pai }
              if pon
                #@board.last = true
                return create_action(
                    {:type => :kakan, :pai => action.pai, :consumed => [action.pai] * 3})
              end
            end
            shanten = ShantenCounter.count(self.tehais)
            if shanten == -1
              return create_action({:type => :hora, :target => action.actor})
            end
            sutehai = self.tehais[-1]
            (self.tehais.size - 1).downto(0) do |i|
              remains = self.tehais.dup()
              remains.delete_at(i)
              if ShantenCounter.count(remains) == shanten
                sutehai = self.tehais[i]
                break
              end
            end
            p [:shanten, @id, shanten]
            return create_action({:type => :dahai, :pai => sutehai})
          end
          
        when :dahai
          if action.actor != self
            if ShantenCounter.count(self.tehais + [action.pai]) == -1
              return create_action({:type => :hora, :target => action.actor})
            elsif self.tehais.select(){ |pai| pai == action.pai }.size >= 3
              #@board.last = true
              return create_action({
                :type => :daiminkan,
                :pai => action.pai,
                :consumed => [action.pai] * 3,
                :target => action.actor
              })
            elsif self.tehais.select(){ |pai| pai == action.pai }.size >= 2
              return create_action({
                :type => :pon,
                :pai => action.pai,
                :consumed => [action.pai] * 2,
                :target => action.actor
              })
            elsif (action.actor.id + 1) % 4 == self.id && action.pai.type != "t"
              for i in 0...3
                consumed = (((-i)...(-i + 3)).to_a() - [0]).map() do |j|
                  Pai.new(action.pai.type, action.pai.number + j)
                end
                if consumed.all?(){ |pai| self.tehais.index(pai) }
                  return create_action({
                    :type => :chi,
                    :pai => action.pai,
                    :consumed => consumed,
                    :target => action.actor,
                  })
                end
              end
            end
          end
          
      end
      
      return nil
    end
    
end


class PipePlayer < Player
    
    def initialize(command)
      super()
      @io = IO.popen(command, "r+")
      @io.sync = true
    end
    
    def respond_to_action(action)
      @io.puts(action.to_json())
      response = Action.from_json(@io.gets().chomp(), self.board)
      return response.type == :none ? nil : response
    end
    
end


class Board
    
    def initialize(players)
      @players = players
      for player in @players
        player.board = self
      end
    end
    
    attr_reader(:players)
    attr_accessor(:last) # kari
    
    def play_game()
      do_action(Action.new({:type => :start_game}))
      @dealer = @players[0]  # TODO fix this
      while !self.game_finished?
        play_kyoku()
      end
    end
    
    def play_kyoku()
      $stderr.puts("play_kyoku")
      catch(:end_kyoku) do
        @pipais = (
            ["m", "p", "s"].map(){ |t| (1..9).map(){ |n| Pai.new(t, n) } }.flatten() +
            (1..7).map(){ |n| Pai.new("t", n) }
        ) * 4
        @pipais.shuffle!()
        @wanpais = @pipais.pop(14)
        do_action(Action.new({:type => :start_kyoku}))
        for player in @players
          do_action(Action.new(
              {:type => :haipai, :actor => player, :pais => @pipais.pop(13) }))
        end
        @actor = @dealer
        while !@pipais.empty?
          action = Action.new({:type => :tsumo, :actor => @actor, :pai => @pipais.pop()})
          while action
            action = do_action(action)
          end
          @actor = @players[(@actor.id + 1) % 4]
        end
        process_ryukyoku()
      end
    end
    
    def do_action(action)
      
      actions = (0...4).map(){ |i| action_in_view(action, i) }
      
      for i in 0...4
        @players[i].process_action(actions[i])
      end
      
      puts action.to_json()
      #p Action.from_json(action.to_json(), self)
      dump()
      
      responses = (0...4).map(){ |i| @players[i].respond_to_action(actions[i]) }
      
      puts("-" * 80)
      #gets()
      
      case action.type
        when :hora
          process_hora(action)
          throw(:end_kyoku)
        when :daiminkan, :kakan, :ankan
          return Action.new({:type => :tsumo, :actor => action.actor, :pai => @wanpais.pop()})
          # TODO 王牌の補充、ドラの追加
      end
      
      id = choose_action(responses)
      if id
        @actor = @players[id]
        return responses[id]
      else
        return nil
      end
      
    end
    
    def choose_action(actions)
      return (0...4).find(){ |i| actions[i] }  # TODO fix this
    end
    
    def action_in_view(action, player_id)
      player = @players[player_id]
      case action.type
        when :start_game
          return Action.new({:type => :start_game, :id => player_id})
        when :haipai
          pais = action.actor == player ? action.pais : [Pai::UNKNOWN] * action.pais.size
          return Action.new({:type => :haipai, :actor => action.actor, :pais => pais})
        when :tsumo
          pai = action.actor == player ? action.pai : Pai::UNKNOWN
          return Action.new({:type => :tsumo, :actor => action.actor, :pai => pai})
        else
          return action
      end
    end
    
    def process_hora(action)
      if action.actor == action.target
        p :tsumo
      else
        p :ron
      end
    end
    
    def process_ryukyoku()
      p :ryukyoku
    end
    
    def game_finished?
      # TODO fix this
      if @last
        return true
      else
        @last = true
        return false
      end
    end
    
    def dump()
      puts("pipai: %d" % @pipais.size) if @pipais
      @players.each_with_index() do |player, i|
        if player.tehais
          puts("%s[%d] tehai: %s %s" %
               [@actor == player ? "*" : " ",
                i,
                Pai.dump_pais(player.tehais),
                player.furos.join(" ")])
          puts("     ho:    %s" % Pai.dump_pais(player.ho))
        end
      end
    end
    
end


class ShantenCounter
    
    # ryanpen = 両面 or 辺搭
    MENTSU_TYPES = [:kotsu, :shuntsu, :toitsu, :ryanpen, :kanta, :single]
    
    MENTSU_CATEGORIES = {
      :kotsu => :complete,
      :shuntsu => :complete,
      :toitsu => :toitsu,
      :ryanpen => :tatsu,
      :kanta => :tatsu,
      :single => :single,
    }
    
    MENTSU_COSTS = {
      :complete => 0,
      :toitsu => 1,
      :tatsu => 1,
      :single => 2,
    }
    
    def self.count(pais)
      pai_set = Hash.new(0)
      for pai in pais
        pai_set[pai.remove_red()] += 1
      end
      return count_recurse(pai_set, [], {})
    end
    
    def self.count_recurse(pai_set, mentsus, cache)
      key = [pai_set, mentsus.sort()]
      if !cache[key]
        if pai_set.empty?
          # TODO support kokushi
          #p mentsus
          chitoi_shanten = -1 + [(7 - mentsus.select(){ |m| m == :toitsu }.size), 0].max
          mentsus = mentsus.dup()
          if index = mentsus.index(:toitsu)
            mentsus.delete_at(index)
            normal_shanten = -1
          elsif index = mentsus.index(:single)
            mentsus.delete_at(index)
            normal_shanten = 0
          else
            return 1.0/0.0
          end
          costs = mentsus.map(){ |m| MENTSU_COSTS[m] }.sort()
          normal_shanten += costs[0...4].inject(0, :+)
          min_shanten = [normal_shanten, chitoi_shanten].min
          #p min_shanten
        else
          min_shanten = 1.0/0.0
          first_pai = pai_set.keys.sort()[0]
          for type in MENTSU_TYPES
            remains_set = remove(pai_set, type, first_pai)
            if remains_set
              shanten = count_recurse(remains_set, mentsus + [MENTSU_CATEGORIES[type]], cache)
              min_shanten = [min_shanten, shanten].min
            end
          end
        end
        cache[key] = min_shanten
      end
      return cache[key]
    end
    
    def self.remove(pai_set, type, first_pai)
      case type
        when :kotsu
          removed_pais = [first_pai] * 3
        when :shuntsu
          return if first_pai.type == "t"
          removed_pais = shuntsu_piece(first_pai, [0, 1, 2])
        when :toitsu
          removed_pais = [first_pai] * 2
        when :ryanpen
          removed_pais = shuntsu_piece(first_pai, [0, 1])
        when :kanta
          removed_pais = shuntsu_piece(first_pai, [0, 2])
        when :single
          removed_pais = [first_pai]
        else
          raise("should not happen")
      end
      return nil if !removed_pais
      result_set = pai_set.dup()
      for pai in removed_pais
        if result_set[pai] > 0
          result_set[pai] -= 1
          result_set.delete(pai) if result_set[pai] == 0
        else
          return nil
        end
      end
      return result_set
    end
    
    def self.shuntsu_piece(first_pai, relative_numbers)
      if first_pai.type == "t"
        return nil
      else
        return relative_numbers.map(){ |i| Pai.new(first_pai.type, first_pai.number + i) }
      end
    end
    
end

def assert_equal(a, b)
  if a != b
    raise("%p != %p" % [a, b])
  end
end

def shanten_counter_test()
  assert_equal(ShantenCounter.count(Pai.parse_pais("123m456p789sNNNFF")), -1)
  assert_equal(ShantenCounter.count(Pai.parse_pais("123m456p789sNNNFP")), 0)
  assert_equal(ShantenCounter.count(Pai.parse_pais("12m456p789sNNNFFP")), 0)
  assert_equal(ShantenCounter.count(Pai.parse_pais("12m45p789sNNNFFPC")), 1)
  assert_equal(ShantenCounter.count(Pai.parse_pais("1112345678999mN")), 0)
  assert_equal(ShantenCounter.count(Pai.parse_pais("114477m114477sCC")), -1)
  assert_equal(ShantenCounter.count(Pai.parse_pais("114477m114477sPC")), 0)
  assert_equal(ShantenCounter.count(Pai.parse_pais("114477m114477sP")), 0)
  p :pass
end

def shanten_counter_benchmark()
  all_pais = (["m", "p", "s"].map(){ |t| (1..9).map(){ |n| Pai.new(t, n) } }.flatten() +
      (1..7).map(){ |n| Pai.new("t", n) }) * 4
  start_time = Time.now.to_f
  100.times() do
    pais = all_pais.sample(14).sort()
    p pais.join(" ")
    shanten = ShantenCounter.count(pais)
    p shanten
=begin
    for i in 0...pais.size
      remains_pais = pais.dup()
      remains_pais.delete_at(i)
      if ShantenCounter.count(remains_pais) == shanten
        p pais[i]
      end
    end
=end
    #gets()
  end
  p Time.now.to_f - start_time
end


#shanten_counter_test()
#shanten_counter_benchmark()

#board = Board.new([PipePlayer.new("ruby1.9 tsumogiri_player.rb"),
#    ShantenPlayer.new(), ShantenPlayer.new(), ShantenPlayer.new()])
board = Board.new((0...4).map(){ ShantenPlayer.new() })
board.play_game()
