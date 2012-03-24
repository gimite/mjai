$LOAD_PATH.unshift(File.dirname(__FILE__) + "/../lib")

require "optparse"

require "mjai/hora_points_estimate"


include(Mjai)

@context = Context.new({
    :oya => false,
    :bakaze => Pai.new("E"),
    :jikaze => Pai.new("S"),
    :doras => Pai.parse_pais("2m"),
})

def dump(pais_str, verbose = false)
  p pais_str
  hp_est = HoraPointsEstimate.new({
      :shanten_analysis => ShantenAnalysis.new(Pai.parse_pais(pais_str), nil, [:normal]),
      :furos => [],
      :context => @context,
  })
  if verbose
    p [:shanten, hp_est.shanten_analysis.shanten]
    p :orig
    for combi in hp_est.shanten_analysis.combinations
      pp combi
    end
    p :detailed
    for combi in hp_est.shanten_analysis.detailed_combinations
      pp combi
    end
    p :expanded
    for combi in hp_est.expanded_combinations
      pp combi
    end
    p [:used, hp_est.used_combinations.size]
    for combi in hp_est.used_combinations
      pp combi
    end
    p [:hora, hp_est.hora_combinations.size]
    for hcombi in hp_est.hora_combinations
      p [:current_janto, hcombi.used_combination.janto.pais.join(" ")]
      for mentsu in hcombi.used_combination.mentsus
        p [:current_mentsu, mentsu.pais.join(" ")]
      end
      pp hcombi
    end
  end
  for yaku, pfan in hp_est.yaku_pfans
    p [yaku, pfan.probs.reject(){ |k, v| k == 0 }.sort()] if pfan.probs[0] < 0.999
  end
  p [:avg_pts, hp_est.average_points]
end

case ARGV.shift()
  when "random"
    pais = (0...4).map() do |i|
      ["m", "p", "s"].map(){ |t| (1..9).map(){ |n| Pai.new(t, n, n == 5 && i == 0) } } +
          (1..7).map(){ |n| Pai.new("t", n) }
    end
    all_pais = pais.flatten().sort()
    while true
      pais = all_pais.sample(13).sort()
      start_time = Time.now
      dump(pais.join(" "))
      p [:time, Time.now - start_time]
      gets()
    end
  else
    raise("hoge")
end
