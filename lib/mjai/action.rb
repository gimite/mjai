require "mjai/jsonizable"


module Mjai
    
    class Action < JSONizable
        
        define_fields([
          [:type, :symbol],
          [:reason, :symbol],
          [:actor, :player],
          [:target, :player],
          [:pai, :pai],
          [:consumed, :pais],
          [:pais, :pais],
          [:id, :number],
          [:oya, :player],
          [:dora_marker, :pai],
          [:tehais, :pais_list],
          [:uri, :string],
          [:names, :strings],
          [:fu, :number],
          [:fan, :number],
          [:hora_points, :number],
          [:deltas, :numbers],
          [:player_points, :numbers],
          [:text, :string],
        ])
        
    end
    
end
