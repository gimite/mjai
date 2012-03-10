# coding: utf-8

$LOAD_PATH.unshift(File.dirname(__FILE__) + "/../lib")

require "mjai/danger_estimator"


INTERESTING_CRITERIA = [
  
  {"tsupai" => false, "suji" => false},
  {"tsupai" => false, "suji" => false, "urasuji" => true},
  {"tsupai" => false, "suji" => false, "aida4ken" => true},
  
  {"tsupai" => false, "suji" => false, "5<=n<=5" => false},
  {"tsupai" => false, "suji" => false, "outer_early_sutehai" => true},
  
  {"tsupai" => false, "suji" => true},
  {"tsupai" => false, "suji" => true, "reach_suji" => true},
  
]

@opts = OptionParser.getopts("v", "start:", "n:", "o:", "min_gap:")

estimator = Mjai::DangerEstimator.new()
estimator.verbose = @opts["v"]
estimator.min_gap = @opts["min_gap"].to_f() / 100.0

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
    estimator.calculate_probabilities(ARGV[0], INTERESTING_CRITERIA)
    
  when "benchmark"
    estimator.create_kyoku_probs_map(ARGV[0], INTERESTING_CRITERIA)
    
  when "tree"
    root = estimator.generate_decision_tree(ARGV[0])
    estimator.render_decision_tree(root, "all")
    if @opts["o"]
      open(@opts["o"], "wb"){ |f| Marshal.dump(root, f) }
    end
    
  when "dump_tree"
    root = open(ARGV[0], "rb"){ |f| Marshal.load(f) }
    estimator.render_decision_tree(root, "all")
    
  else
    raise("unknown action")

end
