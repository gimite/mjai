# Reference: http://tenhou.net/1/script/tenhou.js

require "zlib"
require "uri"
require "nokogiri"

require "mjai/archive"
require "mjai/pai"
require "mjai/action"
require "mjai/puppet_player"


module Mjai

    class TenhouArchive < Archive
        
        module Util
            
            YAKU_ID_TO_NAME = [
              :menzenchin_tsumoho, :reach, :ippatsu, :chankan, :rinshankaiho,
              :haiteiraoyue, :hoteiraoyui, :pinfu, :tanyaochu, :ipeko,
              :jikaze, :jikaze, :jikaze, :jikaze,
              :bakaze, :bakaze, :bakaze, :bakaze,
              :sangenpai, :sangenpai, :sangenpai,
              :double_reach, :chitoitsu, :honchantaiyao, :ikkitsukan, :sanshokudojun,
              :sanshokudoko, :sankantsu, :toitoiho, :sananko, :shosangen, :honroto,
              :ryanpeko, :junchantaiyao, :honiso,
              :chiniso,
              :renho,
              :tenho, :chiho, :daisangen, :suanko, :suanko, :tsuiso,
              :ryuiso, :chinroto, :churenpoton, :churenpoton, :kokushimuso,
              :kokushimuso, :daisushi, :shosushi, :sukantsu,
              :dora, :uradora, :akadora,
            ]

            def on_tenhou_event(elem, next_elem = nil)
              verify_tenhou_tehais() if @first_kyoku_started
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
                  oya = elem["oya"].to_i()
                  log_name = elem["log"] || File.basename(self.path, ".mjlog")
                  uri = "http://tenhou.net/0/?log=%s&tw=%d" % [log_name, (4 - oya) % 4]
                  @first_kyoku_started = false
                  return do_action({:type => :start_game, :uri => uri, :names => @names})
                when "INIT"
                  if @first_kyoku_started
                    # Ends the previous kyoku. This is here because there can be multiple AGARIs in
                    # case of daburon, so we cannot detect the end of kyoku in AGARI.
                    do_action({:type => :end_kyoku})
                  end
                  (kyoku_id, honba, _, _, _, dora_marker_pid) = elem["seed"].split(/,/).map(&:to_i)
                  bakaze = Pai.new("t", kyoku_id / 4 + 1)
                  kyoku_num = kyoku_id % 4 + 1
                  oya = elem["oya"].to_i()
                  @first_kyoku_started = true
                  tehais_list = []
                  for i in 0...4
                    if i == 0
                      hai_str = elem["hai"] || elem["hai0"]
                    else
                      hai_str = elem["hai%d" % i]
                    end
                    pids = hai_str ? hai_str.split(/,/) : [nil] * 13
                    self.players[i].attributes.tenhou_tehai_pids = pids
                    tehais_list.push(pids.map(){ |s| pid_to_pai(s) })
                  end
                  do_action({
                    :type => :start_kyoku,
                    :bakaze => bakaze,
                    :kyoku => kyoku_num,
                    :honba => honba,
                    :oya => self.players[oya],
                    :dora_marker => pid_to_pai(dora_marker_pid.to_s()),
                    :tehais => tehais_list,
                  })
                  return nil
                when /^([T-W])(\d+)?$/i
                  player_id = ["T", "U", "V", "W"].index($1.upcase)
                  pid = $2
                  self.players[player_id].attributes.tenhou_tehai_pids.push(pid)
                  return do_action({
                      :type => :tsumo,
                      :actor => self.players[player_id],
                      :pai => pid_to_pai(pid),
                  })
                when /^([D-G])(\d+)?$/i
                  prefix = $1
                  pid = $2
                  player_id = ["D", "E", "F", "G"].index(prefix.upcase)
                  if pid && pid == self.players[player_id].attributes.tenhou_tehai_pids[-1]
                    tsumogiri = true
                  elsif prefix != prefix.upcase
                    tsumogiri = true
                  else
                    tsumogiri = false
                  end
                  delete_tehai_by_pid(self.players[player_id], pid)
                  return do_action({
                      :type => :dahai,
                      :actor => self.players[player_id],
                      :pai => pid_to_pai(pid),
                      :tsumogiri => tsumogiri,
                  })
                when "REACH"
                  actor = self.players[elem["who"].to_i()]
                  case elem["step"]
                    when "1"
                      return do_action({:type => :reach, :actor => actor})
                    when "2"
                      deltas = [0, 0, 0, 0]
                      deltas[actor.id] = -1000
                      # Old Tenhou archive doesn't have "ten" attribute. Calculates it manually.
                      scores = (0...4).map() do |i|
                        self.players[i].score + deltas[i]
                      end
                      return do_action({
                          :type => :reach_accepted,
                          :actor => actor,
                          :deltas => deltas,
                          :scores => scores,
                      })
                    else
                      raise("should not happen")
                  end
                when "AGARI"
                  tehais = (elem["hai"].split(/,/) - [elem["machi"]]).map(){ |pid| pid_to_pai(pid) }
                  points_params = get_points_params(elem["sc"])
                  (fu, hora_points, _) = elem["ten"].split(/,/).map(&:to_i)
                  if elem["yakuman"]
                    fan = Hora::YAKUMAN_FAN
                  else
                    fan = elem["yaku"].split(/,/).each_slice(2).map(){ |y, f| f.to_i() }.inject(0, :+)
                  end
                  uradora_markers = (elem["doraHaiUra"] || "").
                      split(/,/).map(){ |pid| pid_to_pai(pid) }

                  if elem["yakuman"]
                    yakus = elem["yakuman"].
                        split(/,/).
                        map(){ |y| [YAKU_ID_TO_NAME[y.to_i()], Hora::YAKUMAN_FAN] }
                  else
                    yakus = elem["yaku"].
                        split(/,/).
                        enum_for(:each_slice, 2).
                        map(){ |y, f| [YAKU_ID_TO_NAME[y.to_i()], f.to_i()] }.
                        select(){ |y, f| f != 0 }
                  end

                  do_action({
                    :type => :hora,
                    :actor => self.players[elem["who"].to_i()],
                    :target => self.players[elem["fromWho"].to_i()],
                    :pai => pid_to_pai(elem["machi"]),
                    :hora_tehais => tehais,
                    :uradora_markers => uradora_markers,
                    :fu => fu,
                    :fan => fan,
                    :yakus => yakus,
                    :hora_points => hora_points,
                    :deltas => points_params[:deltas],
                    :scores => points_params[:scores],
                  })
                  if elem["owari"]
                    do_action({:type => :end_kyoku})
                    do_action({:type => :end_game, :scores => points_params[:scores]})
                  end
                  return nil
                when "RYUUKYOKU"
                  points_params = get_points_params(elem["sc"])
                  tenpais = []
                  tehais = []
                  for i in 0...4
                    name = "hai%d" % i
                    if elem[name]
                      tenpais.push(true)
                      tehais.push(elem[name].split(/,/).map(){ |pid| pid_to_pai(pid) })
                    else
                      tenpais.push(false)
                      tehais.push([Pai::UNKNOWN] * self.players[i].tehais.size)
                    end
                  end
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
                  do_action({
                      :type => :ryukyoku,
                      :reason => reason,
                      :tenpais => tenpais,
                      :tehais => tehais,
                      :deltas => points_params[:deltas],
                      :scores => points_params[:scores],
                  })
                  if elem["owari"]
                    do_action({:type => :end_kyoku})
                    do_action({:type => :end_game, :scores => points_params[:scores]})
                  end
                  return nil
                when "N"
                  actor = self.players[elem["who"].to_i()]
                  furo = TenhouFuro.new(elem["m"].to_i())
                  consumed_pids = furo.type == :kakan ? [furo.taken_pid] : furo.consumed_pids
                  for pid in consumed_pids
                    delete_tehai_by_pid(actor, pid)
                  end
                  return do_action(furo.to_action(self, actor))
                when "DORA"
                  do_action({:type => :dora, :dora_marker => pid_to_pai(elem["hai"])})
                  return nil
                when "FURITEN"
                  return nil
                else
                  raise("unknown tag name: %s" % elem.name)
              end
            end
            
            def path
              return nil
            end
            
            def get_points_params(sc_str)
              sc_nums = sc_str.split(/,/).map(&:to_i)
              result = {}
              result[:deltas] = (0...4).map(){ |i| sc_nums[2 * i + 1] * 100 }
              result[:scores] =
                  (0...4).map(){ |i| sc_nums[2 * i] * 100 + result[:deltas][i] }
              return result
            end
            
            def delete_tehai_by_pid(player, pid)
              idx = player.attributes.tenhou_tehai_pids.index(){ |tp| !tp || tp == pid }
              if !idx
                raise("%d not found in %p" % [pid, player.attributes.tenhou_tehai_pids])
              end
              player.attributes.tenhou_tehai_pids.delete_at(idx)
            end
            
            def verify_tenhou_tehais()
              for player in self.players
                next if !player.tehais
                tenhou_tehais =
                    player.attributes.tenhou_tehai_pids.map(){ |pid| pid_to_pai(pid) }.sort()
                tehais = player.tehais.sort()
                if tenhou_tehais != tehais
                  raise("tenhou_tehais != tehais: %p != %p" % [tenhou_tehais, tehais])
                end
              end
            end
            
          module_function
            
            def pid_to_pai(pid)
              return pid ? get_pai(*decompose_pid(pid)) : Pai::UNKNOWN
            end
            
            def decompose_pid(pid)
              pid = pid.to_i()
              return [
                (pid / 4) / 9,
                (pid / 4) % 9 + 1,
                pid % 4,
              ]
            end
            
            def compose_pid(type_id, number, cid)
              return ((type_id * 9 + (number - 1)) * 4 + cid).to_s()
            end
            
            def get_pai(type_id, number, cid)
              type = ["m", "p", "s", "t"][type_id]
              # TODO only for games with red 5p
              red = type != "t" && number == 5 && cid == 0
              return Pai.new(type, number, red)
            end
            
        end
        
        # http://p.tenhou.net/img/mentsu136.txt
        class TenhouFuro
            
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
            
            attr_reader(:type, :target_dir, :taken_pid, :consumed_pids)
            
            def to_action(game, actor)
              params = {
                :type => @type,
                :actor => actor,
                :pai => pid_to_pai(@taken_pid),
                :consumed => @consumed_pids.map(){ |pid| pid_to_pai(pid) },
              }
              if ![:ankan, :kakan].include?(@type)
                params[:target] = game.players[(actor.id + @target_dir) % 4]
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
              @consumed_pids = []
              for i in 0...3
                pid = compose_pid(pai_type, first_number + i, cids[i])
                if i == taken_pos
                  @taken_pid = pid
                else
                  @consumed_pids.push(pid)
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
              @consumed_pids = []
              j = 0
              for i in 0...4
                next if i == unused_cid
                pid = compose_pid(pai_type, pai_number, i)
                if j == taken_pos
                  @taken_pid = pid
                else
                  @consumed_pids.push(pid)
                end
                j += 1
              end
            end
            
            def parse_kan()
              read_bits(2)
              pid = read_bits(8)
              (pai_type, pai_number, key_cid) = decompose_pid(pid)
              @type = @target_dir == 0 ? :ankan : :daiminkan
              @consumed_pids = []
              for i in 0...4
                pid = compose_pid(pai_type, pai_number, i)
                if i == key_cid && @type != :ankan
                  @taken_pid = pid
                else
                  @consumed_pids.push(pid)
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
              @consumed_pids = []
              for i in 0...4
                pid = compose_pid(pai_type, pai_number, i)
                if i == taken_cid
                  @taken_pid = pid
                else
                  @consumed_pids.push(pid)
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
        
        def initialize(path)
          super()
          @path = path
          Zlib::GzipReader.open(path) do |f|
            @xml = f.read().force_encoding("utf-8")
          end
        end
        
        attr_reader(:path)
        attr_reader(:xml)
        
        def play()
          @doc = Nokogiri.XML(@xml)
          elems = @doc.root.children
          elems.each_with_index() do |elem, j|
            begin
              if on_tenhou_event(elem, elems[j + 1]) == :broken
                break  # Something is wrong.
              end
            rescue
              $stderr.puts("While interpreting element: %s" % elem)
              raise
            end
          end
        end
        
    end

end
