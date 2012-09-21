module Mjai

    class Pai
        
        include(Comparable)
        
        TSUPAI_STRS = " ESWNPFC".split(//)
        
        def self.parse_pais(str)
          type = nil
          pais = []
          red = false
          str.gsub(/\s+/, "").split(//).reverse_each() do |ch|
            next if ch =~ /^\s$/
            if ch =~ /^[mps]$/
              type = ch
            elsif ch =~ /^[1-9]$/
              raise(ArgumentError, "type required after number") if !type
              pais.push(Pai.new(type, ch.to_i(), red))
              red = false
            elsif TSUPAI_STRS.include?(ch)
              pais.push(Pai.new(ch))
            elsif ch == "r"
              red = true
            else
              raise(ArgumentError, "unexpected character: %s", ch)
            end
          end
          return pais.reverse()
        end
        
        def self.dump_pais(pais)
          return pais.map(){ |pai| "%-3s" % pai }.join("")
        end
        
        def initialize(*args)
          case args.size
            when 1
              str = args[0]
              if str == "?"
                @type = @number = nil
                @red = false
              elsif str =~ /\A([1-9])([mps])(r)?\z/
                @type = $2
                @number = $1.to_i()
                @red = $3 != nil
              elsif number = TSUPAI_STRS.index(str)
                @type = "t"
                @number = number
                @red = false
              else
                raise(ArgumentError, "Unknown pai string: %s" % str)
              end
            when 2, 3
              (@type, @number, @red) = args
              @red = false if @red == nil
            else
              raise(ArgumentError, "Wrong number of args.")
          end
          if @type != nil || @number != nil
            if !["m", "p", "s", "t"].include?(@type)
              raise("Bad type: %p" % @type)
            end
            if !@number.is_a?(Integer)
              raise("number must be Integer: %p" % @number)
            end
            if @red != true && @red != false
              raise("red must be boolean: %p" % @red)
            end
          end
        end
        
        def to_s()
          if !@type
            return "?"
          elsif @type == "t"
            return TSUPAI_STRS[@number]
          else
            return "%d%s%s" % [@number, @type, @red ? "r" : ""]
          end
        end
        
        def inspect
          return "Pai[%s]" % self.to_s()
        end
        
        attr_reader(:type, :number)
        
        def valid?
          if @type == nil && @number == nil
            return true
          elsif @type == "t"
            return (1..7).include?(@number)
          else
            return (1..9).include?(@number)
          end
        end
        
        def red?
          return @red
        end
        
        def yaochu?
          return @type == "t" || @number == 1 || @number == 9
        end
        
        def fonpai?
          return @type == "t" && (1..4).include?(@number)
        end
        
        def sangenpai?
          return @type == "t" && (5..7).include?(@number)
        end
        
        def next(n)
          return Pai.new(@type, @number + n)
        end
        
        def data
          return [@type || "", @number || -1, @red ? 1 : 0]
        end
        
        def ==(other)
          return self.class == other.class && self.data == other.data
        end
        
        alias eql? ==
        
        def hash()
          return self.data.hash()
        end
        
        def <=>(other)
          if self.class == other.class
            return self.data <=> other.data
          else
            raise(ArgumentError, "invalid comparison")
          end
        end
        
        def remove_red()
          return Pai.new(@type, @number)
        end
        
        def same_symbol?(other)
          return @type == other.type && @number == other.number
        end
        
        # Next pai in terms of dora derivation.
        def succ
          if (@type == "t" && @number == 4) || (@type != "t" && @number == 9)
            number = 1
          elsif @type == "t" && @number == 7
            number = 5
          else
            number = @number + 1
          end
          return Pai.new(@type, number)
        end
        
        UNKNOWN = Pai.new(nil, nil)
        
    end

end
