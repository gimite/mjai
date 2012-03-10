$LOAD_PATH.unshift(File.dirname(__FILE__) + "/../lib")

require "optparse"

require "mjai/archive"


opts = OptionParser.getopts("", "format:human")
for path in ARGV
  puts("# Original file: %s" % path)
  archive = Mjai::Archive.load(path)
  case opts["format"]
    when "human", "mjson"
      archive.on_action() do |action|
        if opts["format"] == "human"
          archive.dump_action(action)
        else
          puts(action.to_json())
        end
      end
      archive.play()
    when "xml"
      puts(archive.xml)
    else
      raise("unknown --format")
  end
end
