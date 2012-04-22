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
            next if plain == nil
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
              when :pais_list
                obj = plain.map(){ |o| o.map(){ |s| Pai.new(s) } }
              when :yakus
                obj = plain.map(){ |s, n| [s.intern(), n] }
              when :number, :numbers, :string, :strings, :boolean, :booleans
                obj = plain
              else
                raise("unknown type")
            end
            fields[name] = obj
          end
          return new(fields)
        end
        
        def initialize(fields)
          for name, value in fields
            if !@@field_specs.any?(){ |n, t| n == name }
              raise(ArgumentError, "unknown field: %p" % name)
            end
          end
          @fields = fields
        end
        
        attr_reader(:fields)
        
        def to_json()
          hash = {}
          for name, type in @@field_specs
            obj = @fields[name]
            next if obj == nil
            case type
              when :symbol, :pai
                plain = obj.to_s()
              when :player
                plain = obj.id
              when :symbols, :pais
                plain = obj.map(){ |a| a.to_s() }
              when :pais_list
                plain = obj.map(){ |o| o.map(){ |a| a.to_s() } }
              when :yakus
                plain = obj.map(){ |s, n| [s.to_s(), n] }
              when :number, :numbers, :string, :strings, :boolean, :booleans
                plain = obj
              else
                raise("unknown type")
            end
            hash[name.to_s()] = plain
          end
          return JSON.dump(hash)
        end
        
        alias to_s to_json
        
        def merge(hash)
          fields = @fields.dup()
          for name, value in hash
            if !@@field_specs.any?(){ |n, t| n == name }
              raise(ArgumentError, "unknown field: %p" % k)
            end
            if value == nil
              fields.delete(name)
            else
              fields[name] = value
            end
          end
          return self.class.new(fields)
        end
        
        def ==(other)
          return self.class == other.class && @fields == other.fields
        end
        
        alias eql? ==
        
        def hash
          return @fields.hash
        end
        
    end
    
end
