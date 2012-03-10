require "json"

require "mjai/pai"


module Mjai
    
    class JSONizable
        
        def self.define_fields(specs)
          @@field_specs = specs
          @@field_specs.each() do |name, type|
            define_method(name) do
              return @fields[name]
            end
          end
        end
        
        def self.from_json(json, game)
          hash = JSON.parse(json)
          fields = {}
          for name, type in @@field_specs
            plain = hash[name.to_s()]
            next if !plain
            case type
              when :symbol
                obj = plain.intern()
              when :symbols
                obj = plain.map(){ |s| s.intern() }
              when :player
                obj = game.players[plain]
              when :pai
                obj = Pai.new(plain)
              when :pais
                obj = plain.map(){ |s| Pai.new(s) }
              when :number, :numbers, :string, :strings
                obj = plain
              else
                raise("unknown type")
            end
            fields[name] = obj
          end
          return new(fields)
        end
        
        def initialize(fields)
          for k, v in fields
            if !@@field_specs.any?(){ |n, t| n == k }
              raise(ArgumentError, "unknown field: %p" % k)
            end
          end
          @fields = fields
        end
        
        def to_json()
          hash = {}
          for name, type in @@field_specs
            obj = @fields[name]
            next if !obj
            case type
              when :symbol, :pai
                plain = obj.to_s()
              when :player
                plain = obj.id
              when :symbols, :pais
                plain = obj.map(){ |a| a.to_s() }
              when :number, :numbers, :string, :strings
                plain = obj
              else
                raise("unknown type")
            end
            hash[name.to_s()] = plain
          end
          return JSON.dump(hash)
        end
        
    end
    
end
