# coding: utf-8

require "set"
require "optparse"
require "with_progress"
require "./tenhou_mjlog_loader"


def remove_from_array(a, b)
  result = a.dup()
  for item in b
    idx = result.index(item)
    result.delete_at(idx) if idx
  end
  return result
end


FEATURE_NAMES = [
  :all, :tsupai, :suji, :musuji_supai,
  :no_chance, :one_chance_or_less, :two_chance_or_less,
  :num_19_or_outer, :num_28_or_outer, :num_37_or_outer, :num_46_or_outer,
  :visible_1_or_more, :visible_2_or_more, :visible_3_or_more,
]


class Scene
    
    def initialize(board, action, reacher)
      
      @board = board
      @action = action
      @me = action.actor
      @reacher = reacher
      
      @anpai_set = Set.new()
      for pai in reacher.anpais
        @anpai_set.add(pai.remove_red())
      end
      
      visible = []
      visible += @board.doras
      visible += @me.tehais
      for player in @board.players
        visible += player.ho + player.furos.map(){ |f| f.pais }.flatten()
      end
      @visible_set = Hash.new(0)
      for pai in visible
        @visible_set[pai.remove_red()] += 1
      end
      
      @candidates = (@me.tehais + [@action.pai]).
          map(){ |pai| pai.remove_red() }.
          uniq().
          select(){ |pai| !@anpai_set.include?(pai) }
      
    end
    
    attr_reader(:candidates)
    
    # pai is without red.
    def feature_vector(pai)
      return FEATURE_NAMES.map(){ |s| __send__(s, pai) }
    end
    
    def all(pai)
      return true
    end
    
    def tsupai(pai)
      return pai.type == "t"
    end
    
    def suji(pai)
      if pai.type == "t"
        return false
      else
        suji_numbers = [pai.number - 3, pai.number + 3].select(){ |n| (1..9).include?(n) }
        return suji_numbers.all?(){ |n| @anpai_set.include?(Pai.new(pai.type, n)) }
      end
    end
    
    def musuji_supai(pai)
      return pai.type != "t" && !suji(pai)
    end
    
    def no_chance(pai)
      return n_chance_or_less(pai, 0)
    end
    
    def one_chance_or_less(pai)
      return n_chance_or_less(pai, 1)
    end
    
    def two_chance_or_less(pai)
      return n_chance_or_less(pai, 2)
    end
    
    (1..4).each() do |i|
      define_method("num_%d%d_or_outer" % [i, 10 - i]) do |pai|
        num_n_or_outer(pai, i)
      end
    end
    (1..3).each() do |i|
      define_method("visible_%d_or_more" % i) do |pai|
        visible_n_or_more(pai, i)
      end
    end
    
    def n_chance_or_less(pai, n)
      if pai.type == "t" || (4..6).include?(pai.number)
        return false
      else
        return (1..2).any?() do |i|
          kabe_pai = Pai.new(pai.type, pai.number + (pai.number < 5 ? i : -i))
          @visible_set[kabe_pai] >= 4 - n
        end
      end
    end
    
    def num_n_or_outer(pai, n)
      return pai.type != "t" && (pai.number <= n || pai.number >= 10 - n)
    end
    
    def visible_n_or_more(pai, n)
      # n doesn't include itself.
      return @visible_set[pai] >= n + 1
    end
    
end


StoredKyoku = Struct.new(:scenes)
StoredScene = Struct.new(:candidates)


def confidence_interval(ratio, num_samples, conf_level = 0.90)
  mod_ratio = (num_samples * ratio + 1.0) / (num_samples + 2.0)
  num_tries = 1000
  probs = []
  num_tries.times() do
    positive = 0
    num_samples.times() do
      positive += 1 if rand() < mod_ratio
    end
    probs.push(positive.to_f() / num_samples)
  end
  probs.sort!()
  margin = (1.0 - conf_level) / 2
  return [
    probs[(num_tries * margin).to_i()],
    probs[(num_tries * (1.0 - margin)).to_i()],
  ]
end

#p confidence_interval(0.091, 421, 0.90)
#exit

@opts = OptionParser.getopts("v", "start:", "n:", "o:")

action = ARGV.shift()
case action
  
  when "extract"
    
    raise("-o is missing") if !@opts["o"]
    if ARGV.empty?
      paths = Dir["mjlog/mjlog_pf4-20_n?/*.mjlog"].sort().reverse()
    else
      paths = ARGV
    end
    paths = paths[paths.index(@opts["start"])..-1] if @opts["start"]
    paths = paths[0, @opts["n"].to_i()] if @opts["n"]
    $stderr.puts("%d files." % paths.size)

    open(@opts["o"], "wb") do |f|
      
      reacher = nil
      waited = nil
      skip = false
      stored_kyokus = []
      stored_kyoku = nil
      paths.enum_for(:each_with_progress).each_with_index() do |path, i|
      #for path in paths
        if i % 100 == 0 && i > 0
          Marshal.dump(stored_kyokus, f)
          stored_kyokus.clear()
        end
        begin
          loader = TenhouMjlogLoader.new(path)
          loader.play() do |action|
            loader.board.dump_action(action) if @opts["v"]
            case action.type
              
              when :start_kyoku
                stored_kyoku = StoredKyoku.new([])
                reacher = nil
                skip = false
              
              when :end_kyoku
                next if skip
                raise("should not happen") if !stored_kyoku
                stored_kyokus.push(stored_kyoku)
                stored_kyoku = nil
              
              when :reach_accepted
                if ["ASAPIN", "（≧▽≦）"].include?(action.actor.name) || reacher
                  skip = true
                end
                next if skip
                reacher = action.actor
                waited = TenpaiInfo.new(action.actor.tehais).waited_pais
              
              when :dahai
                next if skip || !reacher || action.actor.reach?
                scene = Scene.new(loader.board, action, reacher)
                stored_scene = StoredScene.new([])
                #p [:candidates, action.actor, reacher, scene.candidates.join(" ")]
                for pai in scene.candidates
                  hit = waited.include?(pai)
                  feature_vector = scene.feature_vector(pai)
                  stored_scene.candidates.push([feature_vector, hit])
                  if @opts["v"]
                    puts("candidate %s: %s" % [
                        pai, (0...feature_vector.size).select(){ |i| feature_vector[i] }.
                            map(){ |i| FEATURE_NAMES[i] }.join(" ")])
                  end
                end
                stored_kyoku.scenes.push(stored_scene)
                
            end
          end
        rescue Exception
          $stderr.puts("at #{path}")
          raise()
        end
      end
      
      Marshal.dump(stored_kyokus, f)
    end

  when "calculate"
    
    kyoku_prob_sums = Hash.new(0.0)
    kyoku_counts = Hash.new(0)
    
    open(ARGV[0], "rb") do |f|
      
      f.with_progress() do
        begin
          while true
            stored_kyokus = Marshal.load(f)
            for stored_kyoku in stored_kyokus
              scene_prob_sums = Hash.new(0.0)
              scene_counts = Hash.new(0)
              for stored_scene in stored_kyoku.scenes
                pai_freqs = {}
                for feature_vector, hit in stored_scene.candidates
                  for i in 0...feature_vector.size
                    name = FEATURE_NAMES[i]
                    value= feature_vector[i]
                    pai_freqs[[name, value]] ||= Hash.new(0)
                    pai_freqs[[name, value]][hit] += 1
                  end
                  #p [pai, hit, feature_vector]
                end
                for feature, freqs in pai_freqs
                  scene_prob = freqs[true].to_f() / (freqs[false] + freqs[true])
                  #p [:scene_prob, feature, scene_prob]
                  scene_prob_sums[feature] += scene_prob
                  scene_counts[feature] += 1
                end
              end
              for feature, count in scene_counts
                kyoku_prob = scene_prob_sums[feature] / count
                #p [:kyoku_prob, feature, kyoku_prob]
                kyoku_prob_sums[feature] += kyoku_prob
                kyoku_counts[feature] += 1
              end
            end
          end
        rescue EOFError
        end
      end
      
    end

    for name in FEATURE_NAMES
      for value in [false, true]
        feature = [name, value]
        count = kyoku_counts[feature]
        next if count == 0
        overall_prob = kyoku_prob_sums[feature] / count
        conf_interval = confidence_interval(overall_prob, count)
        puts("%p: %.4f [%.4f, %.4f] (%d samples)" %
            [feature, overall_prob, *conf_interval, kyoku_counts[feature]])
      end
    end
    
  else
    raise("unknown action")

end
