$LOAD_PATH.unshift(File.dirname(__FILE__) + "/../lib")

require "optparse"

require "mjai/hora_probabilities"


include(Mjai)

opts = OptionParser.getopts("", "o:")
probs = HoraProbabilities.new()
case ARGV.shift()
  when "estimate"
    open(opts["o"], "wb") do |f|
      if ARGV.empty?
        paths = Dir["mjlog/mjlog_pf4-20_n1/*.mjlog"].sort().reverse()[0, 100]
      else
        paths = ARGV
      end
      metrics_map = probs.estimate(paths)
      Marshal.dump(metrics_map, f)
      probs.dump_metrics_map(metrics_map)
    end
  when "dump"
    open(ARGV[0], "rb") do |f|
      probs.dump_metrics_map(Marshal.load(f))
    end
  else
    raise("unknown action")
end
