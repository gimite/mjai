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
          [:tsumogiri, :boolean],
          [:id, :number],
          [:oya, :player],
          [:dora_marker, :pai],
          [:uradora_markers, :pais],
          [:tehais, :pais_list],
          [:uri, :string],
          [:names, :strings],
          [:hora_tehais, :pais],
          [:yakus, :yakus],
          [:fu, :number],
          [:fan, :number],
          [:hora_points, :number],
          [:deltas, :numbers],
          [:scores, :numbers],
          [:text, :string],
        ])
        
    end
    
end
