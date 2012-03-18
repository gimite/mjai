module Mjai
    
    module WithFields
        
        def define_fields(names)
          @field_names = names
          @field_names.each() do |name|
            define_method(name) do
              return @fields[name]
            end
          end
        end
        
        attr_reader(:field_names)
        
    end
    
end
