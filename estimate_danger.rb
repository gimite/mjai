# coding: utf-8

require "set"
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

def n_chance_or_less?(board, me, other, pai, n)
  if pai.type == "t" || (4..6).include?(pai.number)
    return false
  else
    visible = []
    visible += board.doras
    visible += me.tehais
    for i in 0...4
      pl = board.players[i]
      visible += pl.ho + pl.furos.map(){ |f| f.pais }.flatten()
    end
    return (1..2).any?() do |i|
      kabe_pai = Pai.new(pai.type, pai.number + (pai.number < 5 ? i : -i))
      visible.select(){ |vp| vp.same_symbol?(kabe_pai) }.size >= 4 - n
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

features = {
  :all => proc() do |board, me, other, pai|
    true
  end,
  :tsupai => proc() do |board, me, other, pai|
    pai.type == "t"
  end,
  :suji => proc() do |board, me, other, pai|
    if pai.type == "t"
      false
    else
      [pai.number - 3, pai.number + 3].select(){ |n| (1..9).include?(n) }.all?() do |n|
        suji_pai = Pai.new(pai.type, n)
        other.sutehais.any?(){ |sutehai| sutehai.same_symbol?(suji_pai) }
      end
    end
  end,
  :musuji_supai => proc() do |board, me, other, pai|
    pai.type != "t" && !features[:suji].call(board, me, other, pai)
  end,
  :no_chance => proc() do |board, me, other, pai|
    n_chance_or_less?(board, me, other, pai, 0)
  end,
  :one_chance_or_less => proc() do |board, me, other, pai|
    n_chance_or_less?(board, me, other, pai, 1)
  end,
  :two_chance_or_less => proc() do |board, me, other, pai|
    n_chance_or_less?(board, me, other, pai, 2)
  end,
}

#p confidence_interval(0.091, 421, 0.90)
#exit

if ARGV.empty?
  paths = Dir["mjlog/mjlog_pf4-20_n2/*.mjlog"].sort().reverse()[0, 100]
else
  paths = ARGV
end

total = 0
num_reaches = 0
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
    #loader.board.dump_action(action)
    case action.type
      
      when :start_kyoku
        waited_map = {}
        scene_prob_sums = Hash.new(0.0)
        scene_counts = Hash.new(0)
        reacher = nil
        skip = false
      
      when :end_kyoku
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
        waited = ShantenCounter.new(action.actor.tehais).waited_pais
        num_reaches += 1
      
      when :dahai
        next if skip || !reacher || action.actor.reach?
        total += 1
        candidates = (action.actor.tehais + [action.pai]).
            select(){ |pai| reacher.anpais.all?(){ |sh| !sh.same_symbol?(pai) } }.
            uniq()
        #p [:candidates, action.actor, reacher, candidates.join(" ")]
        pai_freqs = {}
        for pai in candidates
          hit = waited.include?(pai)
          feature_vector = {}
          for name, pred in features
            value = pred.call(loader.board, action.actor, reacher, pai)
            feature_vector[name] = value
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

for name, pred in features
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
