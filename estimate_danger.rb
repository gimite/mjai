# coding: utf-8

require "set"
require "optparse"
require "with_progress"
require "./mahjong"


FEATURE_NAMES = [
  :all, :tsupai,
  :suji, :urasuji, :aida4ken, :reach_suji,
  :no_chance, :one_chance_or_less, :two_chance_or_less,
  :outer_early_sutehai,
  :num_19_or_outer, :num_28_or_outer, :num_37_or_outer, :num_46_or_outer,
  :visible_1_or_more, :visible_2_or_more, :visible_3_or_more,
]


class Scene
    
    URASUJI_INV_MAP = {
      1 => [5],
      2 => [1, 6],
      3 => [2, 7],
      4 => [3, 5, 8],
      5 => [1, 4, 6, 9],
      6 => [2, 5, 7],
      7 => [3, 8],
      8 => [4, 9],
      9 => [5],
    }
    
    def initialize(board, action, reacher, prereach_sutehais)
      
      @board = board
      @action = action
      @me = action.actor
      @reacher = reacher
      @prereach_sutehais = prereach_sutehais
      
      @anpai_set = to_pai_set(reacher.anpais)
      @prereach_sutehais_set = to_pai_set(@prereach_sutehais)
      @early_sutehais_set = to_pai_set(@prereach_sutehais[0, 6])
      
      visible = []
      visible += @board.doras
      visible += @me.tehais
      for player in @board.players
        visible += player.ho + player.furos.map(){ |f| f.pais }.flatten()
      end
      @visible_set = to_pai_set(visible)
      
      @candidates = (@me.tehais + [@action.pai]).
          map(){ |pai| pai.remove_red() }.
          uniq().
          select(){ |pai| !@anpai_set.has_key?(pai) }
      
    end
    
    attr_reader(:candidates)
    
    def to_pai_set(pais)
      pai_set = Hash.new(0)
      for pai in pais
        pai_set[pai.remove_red()] += 1
      end
      return pai_set
    end
    
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
        return get_suji_numbers(pai).all?(){ |n| @anpai_set.has_key?(Pai.new(pai.type, n)) }
      end
    end
    
    def reach_suji(pai)
      reach_pai = @prereach_sutehais[-1].remove_red()
      if pai.type == "t" || reach_pai.type != pai.type || pai.number == 1 || pai.number == 9
        return false
      else
        suji_numbers = get_suji_numbers(pai)
        return suji_numbers.all?(){ |n| @prereach_sutehais_set.include?(Pai.new(pai.type, n)) } &&
            suji_numbers.include?(reach_pai.number) &&
            @prereach_sutehais_set[reach_pai] == 1
      end
    end
    
    def get_suji_numbers(pai)
      return [pai.number - 3, pai.number + 3].select(){ |n| (1..9).include?(n) }
    end
    
    def urasuji(pai)
      if pai.type == "t"
        return false
      else
        urasuji_numbers = URASUJI_INV_MAP[pai.number]
        return urasuji_numbers.any?(){ |n| @prereach_sutehais_set.has_key?(Pai.new(pai.type, n)) }
      end
    end
    
    def aida4ken(pai)
      if pai.type == "t"
        return false
      else
        return ((2..5).include?(pai.number) &&
              @prereach_sutehais_set.has_key?(Pai.new(pai.type, pai.number - 1)) &&
              @prereach_sutehais_set.has_key?(Pai.new(pai.type, pai.number + 4))) ||
            ((5..8).include?(pai.number) &&
              @prereach_sutehais_set.has_key?(Pai.new(pai.type, pai.number - 4)) &&
              @prereach_sutehais_set.has_key?(Pai.new(pai.type, pai.number + 1)))
      end
    end
    
    def outer_early_sutehai(pai)
      if pai.type == "t" || pai.number == 5
        return false
      else
        inner_numbers = pai.number < 5 ? ((pai.number + 1)..5) : (5..(pai.number - 1))
        return inner_numbers.any?(){ |n| @early_sutehais_set.has_key?(Pai.new(pai.type, n)) }
      end
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
CriterionMetrics = Struct.new(:average_prob, :conf_interval, :num_samples)


class DangerEstimator
    
    attr_accessor(:verbose)
    
    def extract_features_from_files(input_paths, output_path)
      $stderr.puts("%d files." % input_paths.size)
      open(output_path, "wb") do |f|
        @stored_kyokus = []
        input_paths.enum_for(:each_with_progress).each_with_index() do |path, i|
          if i % 100 == 0 && i > 0
            Marshal.dump(@stored_kyokus, f)
            @stored_kyokus.clear()
          end
          extract_features_from_file(path)
        end
        Marshal.dump(@stored_kyokus, f)
      end
    end
    
    def extract_features_from_file(input_path)
      begin
        stored_kyoku = nil
        reacher = nil
        waited = nil
        prereach_sutehais = nil
        skip = false
        archive = Archive.new(input_path)
        archive.play_game() do |action|
          archive.dump_action(action) if self.verbose
          case action.type
            
            when :start_kyoku
              stored_kyoku = StoredKyoku.new([])
              reacher = nil
              skip = false
            
            when :end_kyoku
              next if skip
              raise("should not happen") if !stored_kyoku
              @stored_kyokus.push(stored_kyoku)
              stored_kyoku = nil
            
            when :reach_accepted
              if ["ASAPIN", "（≧▽≦）"].include?(action.actor.name) || reacher
                skip = true
              end
              next if skip
              reacher = action.actor
              waited = TenpaiInfo.new(action.actor.tehais).waited_pais
              prereach_sutehais = reacher.sutehais.dup()
            
            when :dahai
              next if skip || !reacher || action.actor.reach?
              scene = Scene.new(archive, action, reacher, prereach_sutehais)
              stored_scene = StoredScene.new([])
              #p [:candidates, action.actor, reacher, scene.candidates.join(" ")]
              puts("reacher: %d" % reacher.id) if self.verbose
              for pai in scene.candidates
                hit = waited.include?(pai)
                feature_vector = scene.feature_vector(pai)
                stored_scene.candidates.push([feature_vector, hit])
                if self.verbose
                  puts("candidate %s: hit=%d, %s" % [
                      pai, hit ? 1 : 0,
                      (0...feature_vector.size).select(){ |i| feature_vector[i] }.
                          map(){ |i| FEATURE_NAMES[i] }.join(" ")])
                end
              end
              stored_kyoku.scenes.push(stored_scene)
              
          end
        end
      rescue Exception
        $stderr.puts("at #{input_path}")
        raise()
      end
    end
    
    def calculate_single_probabilities(features_path)
      criteria = FEATURE_NAMES.map(){ |s| [{s => false}, {s => true}] }.flatten()
      calculate_probabilities(features_path, criteria)
    end
    
    def generate_decision_tree(features_path, base_criterion = {}, base_metrics = nil)
      p [:generate_decision_tree, base_criterion]
      targets = {}
      criteria = []
      for name in FEATURE_NAMES
        next if base_criterion.has_key?(name)
        negative_criterion = base_criterion.merge({name => false})
        positive_criterion = base_criterion.merge({name => true})
        targets[name] = [negative_criterion, positive_criterion]
        criteria.push(negative_criterion, positive_criterion)
      end
      metrics_map = calculate_probabilities(features_path, criteria)
      gaps = {}
      for name, (negative_criterion, positive_criterion) in targets
        negative = metrics_map[negative_criterion]
        positive = metrics_map[positive_criterion]
        next if !positive || !negative
        if positive.average_prob >= negative.average_prob
          gap = positive.conf_interval[0] - negative.conf_interval[1]
        else
          gap = negative.conf_interval[0] - positive.conf_interval[1]
        end
        p [name, gap]
        gaps[name] = gap if gap > 0.0
      end
      max_name = gaps.keys.max_by(){ |s| gaps[s] }
      p [:max_name, max_name]
      if max_name
        return targets[max_name].
            map(){ |c| generate_decision_tree(features_path, c, metrics_map[c]) }.
            inject(:+)
      else
        return [[base_criterion, base_metrics]]
      end
    end
    
    def calculate_probabilities(features_path, criteria)
      
      @kyoku_prob_sums = Hash.new(0.0)
      @kyoku_counts = Hash.new(0)
      
      open(features_path, "rb") do |f|
        f.with_progress() do
          begin
            while true
              stored_kyokus = Marshal.load(f)
              for stored_kyoku in stored_kyokus
                update_metrics_for_kyoku(stored_kyoku, criteria)
              end
            end
          rescue EOFError
          end
        end
      end
      
      result = {}
      for criterion in criteria
        count = @kyoku_counts[criterion]
        next if count == 0
        overall_prob = @kyoku_prob_sums[criterion] / count
        result[criterion] = metrics = CriterionMetrics.new(
            overall_prob,
            confidence_interval(overall_prob, count),
            count)
        puts("%p\n  %.2f [%.2f, %.2f] (%d samples)" %
            [criterion,
             metrics.average_prob * 100.0,
             metrics.conf_interval[0] * 100.0,
             metrics.conf_interval[1] * 100.0,
             metrics.num_samples])
      end
      return result
      
    end
    
    def update_metrics_for_kyoku(stored_kyoku, criteria)
      scene_prob_sums = Hash.new(0.0)
      scene_counts = Hash.new(0)
      for stored_scene in stored_kyoku.scenes
        pai_freqs = {}
        for feature_vector, hit in stored_scene.candidates
          for criterion in criteria
            if match?(feature_vector, criterion)
              pai_freqs[criterion] ||= Hash.new(0)
              pai_freqs[criterion][hit] += 1
            end
          end
          #p [pai, hit, feature_vector]
        end
        for criterion, freqs in pai_freqs
          scene_prob = freqs[true].to_f() / (freqs[false] + freqs[true])
          #p [:scene_prob, criterion, scene_prob]
          scene_prob_sums[criterion] += scene_prob
          scene_counts[criterion] += 1
        end
      end
      for criterion, count in scene_counts
        kyoku_prob = scene_prob_sums[criterion] / count
        #p [:kyoku_prob, criterion, kyoku_prob]
        @kyoku_prob_sums[criterion] += kyoku_prob
        @kyoku_counts[criterion] += 1
      end
    end
    
    def match?(feature_vector, criterion)
      return criterion.all?(){ |k, v| feature_vector[FEATURE_NAMES.index(k)] == v }
    end
    
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

end


@opts = OptionParser.getopts("v", "start:", "n:", "o:")

estimator = DangerEstimator.new()
estimator.verbose = @opts["v"]

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
    estimator.extract_features_from_files(paths, @opts["o"])

  when "single"
    estimator.calculate_single_probabilities(ARGV[0])
    
  when "interesting"
    criteria = [
      
      {:tsupai => false, :suji => false},
      {:tsupai => false, :suji => false, :urasuji => true},
      {:tsupai => false, :suji => false, :aida4ken => true},
      
      {:tsupai => false, :suji => false, :num_46_or_outer => true},
      {:tsupai => false, :suji => false, :outer_early_sutehai => true},
      
      {:tsupai => false, :suji => true},
      {:tsupai => false, :suji => true, :reach_suji => true},
      
    ]
    estimator.calculate_probabilities(ARGV[0], criteria)
    
  when "tree"
    result = estimator.generate_decision_tree(ARGV[0])
    for criterion, metrics in result.sort_by(){ |c, m| m.average_prob }
      puts("%p\n  %.2f [%.2f, %.2f] (%d samples)" %
          [criterion,
           metrics.average_prob * 100.0,
           metrics.conf_interval[0] * 100.0,
           metrics.conf_interval[1] * 100.0,
           metrics.num_samples])
    end
    
  else
    raise("unknown action")

end
