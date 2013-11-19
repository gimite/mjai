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
          [:possible_actions, :actions],
          [:cannot_dahai, :pais],
          [:id, :number],
          [:bakaze, :pai],
          [:kyoku, :number],
          [:honba, :number],
          [:kyotaku, :number],
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
          [:tenpais, :booleans],
          [:deltas, :numbers],
          [:scores, :numbers],
          [:text, :string],
          [:message, :string],
          [:log, :string_or_null],
          [:logs, :strings_or_nulls],
        ])
        
    end
    
end
