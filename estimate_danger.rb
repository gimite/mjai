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

features = {
  :all => proc() do |board, player, pai|
    true
  end,
  :tsupai => proc() do |board, player, pai|
    pai.type == "t"
  end,
  :suji => proc() do |board, player, pai|
    if pai.type == "t"
      false
    else
      [pai.number - 3, pai.number + 3].select(){ |n| (1..9).include?(n) }.all?() do |n|
        suji_pai = Pai.new(pai.type, n)
        player.sutehais.any?(){ |sutehai| sutehai.same_symbol?(suji_pai) }
      end
    end
  end,
  :musuji_supai => proc() do |board, player, pai|
    pai.type != "t" && !features[:suji].call(board, player, pai)
  end,
  :no_chance => proc() do |board, player, pai|
    if pai.type == "t" || (4..6).include?(pai.number)
      false
    else
      visible = []
      visible += board.doras
      for i in 0...4
        pl = board.players[i]
        visible += pl.ho + pl.furos.map(){ |f| f.pais }.flatten()
      end
      (1..2).any?() do |i|
        kabe_pai = Pai.new(pai.type, pai.number + (pai.number < 5 ? i : -i))
        visible.select(){ |vp| vp.same_symbol?(kabe_pai) }.size == 4
      end
    end
  end,
}

if ARGV.empty?
  paths = Dir["mjlog/mjlog_pf4-20_n2/*.mjlog"].sort().reverse()[0, 10]
else
  paths = ARGV
end

total = 0
freqs = Hash.new(0)
paths.each_with_progress() do |path|
#for path in paths
  p path
  loader = TenhouMjlogLoader.new(path)
  reached = false
  loader.play() do |action|
    #p action
    #p action.actor.name if action.actor
    case action.type
      when :reach
        reached = true
      when :dahai
        if reached && action.actor.name != "（≧▽≦）"
          #p action.actor.tehais
          waited_pais = ShantenCounter.new(action.actor.tehais).waited_pais
          p [:waited, waited_pais]
          visible = []
          visible += action.actor.tehais + loader.board.doras
          for i in 0...4
            player = loader.board.players[i]
            visible += player.ho + player.furos.map(){ |f| f.pais }.flatten()
          end
          #p visible.join(" ")
          invisible = remove_from_array(loader.board.all_pais, visible).
              map(){ |pai| pai.remove_red() }
          anpais = Set.new(action.actor.sutehais.map(){ |pai| pai.remove_red() })
          candidates = invisible.select(){ |pai| !anpais.include?(pai.remove_red()) }
          #p [:candidates, candidates.join(" ")]
          for pai in candidates
            hit = waited_pais.include?(pai)
            for name, pred in features
              value = pred.call(loader.board, action.actor, pai)
              if value && name == :no_chance
                p [:suji, hit, pai]
              end
              freqs[[name, value, hit]] += 1.0 / candidates.size
            end
          end
          total += 1
        end
        reached = false
    end
  end
end

p freqs
p [:total, total]
for name, pred in features
  for value in [false, true]
    positive = freqs[[name, value, true]]
    negative = freqs[[name, value, false]]
    next if positive + negative == 0
    p [name, value, 100.0 * positive / (positive + negative), 100.0 * (positive + negative) / total]
  end
end
