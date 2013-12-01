require "erb"
require "fileutils"

require "mjai/archive"


module Mjai
    
    class FileConverter
        
        include(ERB::Util)
        
        def convert(src_path, dest_path)
          src_ext = File.extname(src_path)
          dest_ext = File.extname(dest_path)
          case [src_ext, dest_ext]
            when [".mjson", ".html"]
              mjson_to_html(src_path, dest_path)
            when [".mjlog", ".xml"]
              archive = Archive.load(src_path)
              open(dest_path, "w"){ |f| f.write(archive.xml) }
            when [".mjson", ".human"], [".mjlog", ".human"]
              dump_archive(src_path, dest_path, :human)
            when [".mjlog", ".mjson"]
              dump_archive(src_path, dest_path, :mjson)
            else
              raise("unsupported ext pair: #{src_ext}, #{dest_ext}")
          end
        end
        
        def dump_archive(archive_path, output_path, output_format)
          archive = Archive.load(archive_path)
          open(output_path, "w") do |f|
            archive.on_action() do |action|
              if output_format == :human
                archive.dump_action(action, f)
              else
                f.puts(action.to_json())
              end
            end
            archive.play()
          end
        end
        
        def mjson_to_html(mjson_path, html_path)
          
          res_dir = File.dirname(__FILE__) + "/../../share/html"
          make("#{res_dir}/js/archive_player.coffee",
              "#{res_dir}/js/archive_player.js",
              "coffee -cb #{res_dir}/js/archive_player.coffee")
          make("#{res_dir}/js/dytem.coffee",
              "#{res_dir}/js/dytem.js",
              "coffee -cb #{res_dir}/js/dytem.coffee")
          make("#{res_dir}/css/style.scss",
              "#{res_dir}/css/style.css",
              "sass #{res_dir}/css/style.scss #{res_dir}/css/style.css")
          
          # Variants used in template.
          action_jsons = File.readlines(mjson_path).map(){ |s| s.chomp().gsub(/\//){ "\\/" } }
          actions_json = "[%s]" % action_jsons.join(",\n")
          base_name = File.basename(html_path)
          
          html = ERB.new(File.read("#{res_dir}/views/archive_player.erb"), nil, "<>").
              result(binding)
          open(html_path, "w"){ |f| f.write(html) }
          for src_path in Dir["#{res_dir}/css/*.css"] + Dir["#{res_dir}/js/*.js"]
            exp = Regexp.new("^%s\\/" % Regexp.escape(res_dir))
            dest_path = src_path.gsub(exp){ "#{html_path}.files/" }
            FileUtils.mkdir_p(File.dirname(dest_path))
            FileUtils.cp(src_path, dest_path)
          end
          
        end
        
        def make(src_path, dest_path, command)
          if !File.exist?(dest_path) || File.mtime(src_path) > File.mtime(dest_path)
            puts(command)
            if !system(command)
              exit(1)
            end
          end
        end
        
    end
    
end
