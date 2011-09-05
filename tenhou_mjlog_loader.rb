require "zlib"
require "uri"
require "nokogiri"
require "with_progress"
require "./mahjong"


class TenhouMjlogLoader
    
    module Util
        
        module_function
        
        def pid_to_pai(pid)
          return get_pai(*decompose_pid(pid))
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
    
    def initialize(path, board)
      @path = path
      @board = board
      Zlib::GzipReader.open(path) do |f|
        @xml = f.read().force_encoding("utf-8")
      end
    end
    
    attr_reader(:board)
    
    def dump_xml()
      puts(@xml)
    end
    
    def play_game()
      @doc = Nokogiri.XML(@xml)
      elems = @doc.root.children
      elems.each_with_index() do |elem, j|
        #puts(elem)
        case elem.name
          when "SHUFFLE", "GO", "BYE"
            # BYE: log out
          when "UN"
            escaped_names = (0...4).map(){ |i| elem["n%d" % i] }
            break if escaped_names.index(nil)  # Something is wrong.
            @names = escaped_names.map(){ |s| URI.decode(s) }
          when "TAIKYOKU"
            uri = "http://tenhou.net/0/?log=" + File.basename(@path, ".mjlog")
            do_action({:type => :start_game, :uri => uri, :names => @names})
          when "INIT"
            oya = elem["oya"].to_i()
            do_action({
              :type => :start_kyoku,
              :oya => @board.players[oya],
              :dora => pid_to_pai(elem["seed"].split(/,/)[5]),
            })
            for i in 0...4
              player_id = (oya + i) % 4
              pais = elem["hai%d" % player_id].split(/,/).map(){ |s| pid_to_pai(s) }
              do_action({:type => :haipai, :actor => @board.players[player_id], :pais => pais})
            end
          when /^([T-W])(\d+)$/
            player_id = ["T", "U", "V", "W"].index($1)
            pid = $2
            do_action({:type => :tsumo, :actor => @board.players[player_id], :pai => pid_to_pai(pid)})
          when /^([D-G])(\d+)$/
            player_id = ["D", "E", "F", "G"].index($1)
            pid = $2
            do_action({:type => :dahai, :actor => @board.players[player_id], :pai => pid_to_pai(pid)})
          when "REACH"
            actor = @board.players[elem["who"].to_i()]
            case elem["step"]
              when "1"
                do_action({:type => :reach, :actor => actor})
              when "2"
                do_action({:type => :reach_accepted, :actor => actor})
              else
                raise("should not happen")
            end
          when "AGARI"
            do_action({
              :type => :hora,
              :actor => @board.players[elem["who"].to_i()],
              :target => @board.players[elem["fromWho"].to_i()],
              :pai => pid_to_pai(elem["machi"]),
            })
            if !elems[j + 1] || elems[j + 1].name != "AGARI"
              do_action({:type => :end_kyoku})
            end
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
          when "N"
            actor = @board.players[elem["who"].to_i()]
            do_action(FuroParser.new(elem["m"].to_i()).to_action(@board, actor))
          when "DORA"
            do_action({:type => :dora, :pai => pid_to_pai(elem["hai"])})
          else
            raise("unknown tag name: %s" % elem.name)
        end
      end
      do_action({:type => :end_game})
    end
    
    def do_action(action)
      if action.is_a?(Hash)
        action = Action.new(action)
      end
      @board.do_action(action)
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
        loader = TenhouMjlogLoader.new(path)
        loader.play()
      end
    else
      raise("unknown")
  end
end
