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
    
    def feature_vector(pai)
      vec = {}
      for name in FEATURE_NAMES
        vec[name] = __send__(name, pai)
      end
      return vec
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
    
end


def confidence_interval(ratio, num_samples, conf_level = 0.95)
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

@opts = OptionParser.getopts("v")

if ARGV.empty?
  paths = Dir["mjlog/mjlog_pf4-20_n2/*.mjlog"].sort().reverse()#[0, 100]
else
  paths = ARGV
end

scene_prob_sums = nil
scene_counts = nil
reacher = nil
waited = nil
skip = false
kyoku_prob_sums = Hash.new(0.0)
kyoku_counts = Hash.new(0)
paths.each_with_progress() do |path|
#for path in paths
  p path
  loader = TenhouMjlogLoader.new(path)
  loader.play() do |action|
    loader.board.dump_action(action) if @opts["v"]
    case action.type
      
      when :start_kyoku
        waited_map = {}
        scene_prob_sums = Hash.new(0.0)
        scene_counts = Hash.new(0)
        reacher = nil
        skip = false
      
      when :end_kyoku
        next if skip
        for feature, count in scene_counts
          kyoku_prob = scene_prob_sums[feature] / count
          #p [:kyoku_prob, feature, kyoku_prob]
          kyoku_prob_sums[feature] += kyoku_prob
          kyoku_counts[feature] += 1
        end
        #exit()
      
      when :reach_accepted
        if action.actor.name == "（≧▽≦）" || reacher
          skip = true
        end
        next if skip
        reacher = action.actor
        waited = TenpaiInfo.new(action.actor.tehais).waited_pais
      
      when :dahai
        next if skip || !reacher || action.actor.reach?
        scene = Scene.new(loader.board, action, reacher)
        #p [:candidates, action.actor, reacher, scene.candidates.join(" ")]
        pai_freqs = {}
        for pai in scene.candidates
          hit = waited.include?(pai)
          feature_vector = scene.feature_vector(pai)
          for name, value in feature_vector
            #if value && name == :suji
            #  p [:suji, hit, pai]
            #end
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
