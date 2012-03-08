require "zlib"
require "uri"
require "nokogiri"
require "with_progress"
require "./mahjong"


class TenhouGame < Board
    
    module Util
        
        module_function
        
        def pid_to_pai(pid)
          return TenhouPai.new(pid ? get_pai(*decompose_pid(pid)) : nil, pid)
        end
        
        def decompose_pid(pid)
          pid = pid.to_i()
          return [
            (pid / 4) / 9,
            (pid / 4) % 9 + 1,
            pid % 4,
          ]
        end
        
        def get_pai(type_id, number, cid)
          type = ["m", "p", "s", "t"][type_id]
          # TODO only for games with red 5p
          red = type != "t" && number == 5 && cid == 0
          return Pai.new(type, number, red)
        end
        
    end
    
    TenhouPai = Struct.new(:pai, :pid)
    
    # http://p.tenhou.net/img/mentsu136.txt
    class FuroParser
        
        include(Util)
        
        def initialize(fid)
          @num = fid
          @target_dir = read_bits(2)
          if read_bits(1) == 1
            parse_chi()
            return
          end
          if read_bits(1) == 1
            parse_pon()
            return
          end
          if read_bits(1) == 1
            parse_kakan()
            return
          end
          if read_bits(1) == 1
            parse_nukidora()
            return
          end
          parse_kan()
        end
        
        attr_reader(:type, :target_dir, :taken, :consumed)
        
        def to_action(board, actor)
          params = {
            :type => @type,
            :actor => actor,
            :pai => @taken,
            :consumed => @consumed,
          }
          if ![:ankan, :kakan].include?(@type)
            params[:target] = board.players[(actor.id + @target_dir) % 4]
          end
          return Action.new(params)
        end
        
        def parse_chi()
          cids = (0...3).map(){ |i| read_bits(2) }
          read_bits(1)
          pattern = read_bits(6)
          seq_kind = pattern / 3
          taken_pos = pattern % 3
          pai_type = seq_kind / 7
          first_number = seq_kind % 7 + 1
          @type = :chi
          @consumed = []
          for i in 0...3
            pai = get_pai(pai_type, first_number + i, cids[i])
            if i == taken_pos
              @taken = pai
            else
              @consumed.push(pai)
            end
          end
        end
        
        def parse_pon()
          read_bits(1)
          unused_cid = read_bits(2)
          read_bits(2)
          pattern = read_bits(7)
          pai_kind = pattern / 3
          taken_pos = pattern % 3
          pai_type = pai_kind / 9
          pai_number = pai_kind % 9 + 1
          @type = :pon
          @consumed = []
          j = 0
          for i in 0...4
            next if i == unused_cid
            pai = get_pai(pai_type, pai_number, i)
            if j == taken_pos
              @taken = pai
            else
              @consumed.push(pai)
            end
            j += 1
          end
        end
        
        def parse_kan()
          read_bits(2)
          pid = read_bits(8)
          (pai_type, pai_number, key_cid) = decompose_pid(pid)
          @type = @target_dir == 0 ? :ankan : :daiminkan
          @consumed = []
          for i in 0...4
            pai = get_pai(pai_type, pai_number, i)
            if i == key_cid && @type != :ankan
              @taken = pai
            else
              @consumed.push(pai)
            end
          end
        end
        
        def parse_kakan()
          taken_cid = read_bits(2)
          read_bits(2)
          pattern = read_bits(7)
          pai_kind = pattern / 3
          taken_pos = pattern % 3
          pai_type = pai_kind / 9
          pai_number = pai_kind % 9 + 1
          @type = :kakan
          @target_dir = 0
          @consumed = []
          for i in 0...4
            pai = get_pai(pai_type, pai_number, i)
            if i == taken_cid
              @taken = pai
            else
              @consumed.push(pai)
            end
          end
        end
        
        def read_bits(num_bits)
          mask = (1 << num_bits) - 1
          result = @num & mask
          @num >>= num_bits
          return result
        end
        
    end
    
    include(Util)
    
    attr_reader(:tenhou_tehais)
    
    def on_tenhou_event(elem, next_elem = nil)
      case elem.name
        when "SHUFFLE", "GO", "BYE"
          # BYE: log out
          return nil
        when "UN"
          escaped_names = (0...4).map(){ |i| elem["n%d" % i] }
          return :broken if escaped_names.index(nil)  # Something is wrong.
          @names = escaped_names.map(){ |s| URI.decode(s) }
          return nil
        when "TAIKYOKU"
          uri = self.path ? "http://tenhou.net/0/?log=" + File.basename(self.path, ".mjlog") : nil
          return do_action({:type => :start_game, :uri => uri, :names => @names})
        when "INIT"
          oya = elem["oya"].to_i()
          do_action({
            :type => :start_kyoku,
            :oya => self.players[oya],
            :dora_marker => pid_to_pai(elem["seed"].split(/,/)[5]).pai,
          })
          for i in 0...4
            player_id = (oya + i) % 4
            if player_id == 0
              hai_str = elem["hai"] || elem["hai0"]
            else
              hai_str = elem["hai%d" % player_id]
            end
            if hai_str
              tenhou_pais = hai_str.split(/,/).map(){ |s| pid_to_pai(s) }
              pais = tenhou_pais.map(){ |tp| tp.pai }
              if player_id == 0
                @tenhou_tehais = tenhou_pais
              end
            else
              pais = [nil] * 13
            end
            do_action({:type => :haipai, :actor => self.players[player_id], :pais => pais})
          end
          return nil
        when /^([T-W])(\d+)?$/i
          player_id = ["T", "U", "V", "W"].index($1.upcase)
          pid = $2
          tenhou_pai = pid_to_pai(pid)
          if player_id == 0
            @tenhou_tehais.push(tenhou_pai)
          end
          return do_action({
              :type => :tsumo,
              :actor => self.players[player_id],
              :pai => tenhou_pai.pai,
          })
        when /^([D-G])(\d+)?$/i
          player_id = ["D", "E", "F", "G"].index($1.upcase)
          pid = $2
          if player_id == 0
            @tenhou_tehais.delete_if(){ |tp| tp.pid == pid }
          end
          return do_action({
              :type => :dahai,
              :actor => self.players[player_id],
              :pai => pid_to_pai(pid).pai,
          })
        when "REACH"
          actor = self.players[elem["who"].to_i()]
          case elem["step"]
            when "1"
              return do_action({:type => :reach, :actor => actor})
            when "2"
              return do_action({:type => :reach_accepted, :actor => actor})
            else
              raise("should not happen")
          end
        when "AGARI"
          do_action({
            :type => :hora,
            :actor => self.players[elem["who"].to_i()],
            :target => self.players[elem["fromWho"].to_i()],
            :pai => pid_to_pai(elem["machi"]).pai,
          })
          if !next_elem || next_elem.name != "AGARI"
            do_action({:type => :end_kyoku})
          end
          return nil
        when "RYUUKYOKU"
          reason_map = {
            "yao9" => :kyushukyuhai,
            "kaze4" => :sufonrenta,
            "reach4" => :suchareach,
            "ron3" => :sanchaho,
            "nm" => :nagashimangan,
            "kan4" => :sukaikan,
            nil => :fanpai,
          }
          reason = reason_map[elem["type"]]
          raise("unknown reason") if !reason
          # TODO add actor for some reasons
          do_action({:type => :ryukyoku, :reason => reason})
          do_action({:type => :end_kyoku})
          return nil
        when "N"
          actor = self.players[elem["who"].to_i()]
          return do_action(FuroParser.new(elem["m"].to_i()).to_action(self, actor))
        when "DORA"
          do_action({:type => :dora, :dora_marker => pid_to_pai(elem["hai"])})
          return nil
        else
          raise("unknown tag name: %s" % elem.name)
      end
    end
    
    def path
      return nil
    end
    
end


class TenhouArchive < TenhouGame
    
    def initialize(path)
      super((0...4).map(){ PuppetPlayer.new() })
      @path = path
      Zlib::GzipReader.open(path) do |f|
        @xml = f.read().force_encoding("utf-8")
      end
    end
    
    attr_reader(:path)
    
    def dump_xml()
      puts(@xml)
    end
    
    def play_game()
      @doc = Nokogiri.XML(@xml)
      elems = @doc.root.children
      elems.each_with_index() do |elem, j|
        #puts(elem)  # kari
        if on_tenhou_event(elem, elems[j + 1]) == :broken
          break  # Something is wrong.
        end
      end
      do_action({:type => :end_game})
    end
    
    def expect_response_from?(player)
      return false
    end
    
end


if $0 == __FILE__
  case ARGV[0]
    when "dump"
      loader = TenhouMjlogLoader.new(ARGV[1])
      loader.dump_xml()
    when "play"
      ARGV[1..-1].each_with_progress() do |path|
        puts("# Original file: %s" % path)
        archive = TenhouArchive.new(path)
        archive.on_action() do |action|
          archive.dump_action(action)
        end
        archive.play_game()
      end
    else
      raise("unknown")
  end
end
