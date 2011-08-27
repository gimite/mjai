require "fileutils"
require "test/unit"
require "./tenhou_mjlog_loader"


class TC_Mahjong < Test::Unit::TestCase
    
    def test_regression()
      FileUtils.mkdir_p("tmp")
      if !system("ruby1.9 tenhou_mjlog_loader.rb play test/test.mjlog > tmp/test.mjlog.log")
        raise("execution failed")
      end
      assert(File.read("tmp/test.mjlog.log") == File.read("test/test.mjlog.golden.log"))
    end
    
end
