$LOAD_PATH.unshift(File.dirname(__FILE__) + "/../lib")

require "optparse"

require "mjai/hora_probability_estimator"


include(Mjai)

opts = OptionParser.getopts("", "o:")
case ARGV.shift()
  when "estimate"
    if ARGV.empty?
      paths = Dir["mjlog/mjlog_pf4-20_n1/*.mjlog"].sort().reverse()[0, 100]
    else
      paths = ARGV
    end
    HoraProbabilityEstimator.estimate(paths, opts["o"])
  when "dump"
    estimator = HoraProbabilityEstimator.new(ARGV[0])
    estimator.dump_metrics_map()
  else
    raise("unknown action")
end
