require "mjai/player"
require "mjai/archive"


module Mjai
    
    class ArchivePlayer < Player
        
        def initialize(archive_path)
          super()
          @archive = Archive.load(archive_path)
          @action_index = 0
        end
        
        def update_state(action)
          super(action)
          expected_action = @archive.actions[@action_index]
          if action.type == :start_game
            action = action.merge({:id => nil})
            expected_action = expected_action.merge({:id => nil})
          end
          if action.to_json() != expected_action.to_json()
            raise((
                "live action doesn't match one in archive\n" +
                "actual: %s\n" +
                "expected: %s\n") %
                [action, expected_action])
          end
          @action_index += 1
        end
        
        def respond_to_action(action)
          next_action = @archive.actions[@action_index]
          if next_action &&
              next_action.actor &&
              next_action.actor.id == 0 &&
              [:dahai, :chi, :pon, :daiminkan, :kakan, :ankan, :reach, :hora].include?(
                  next_action.type)
            return Action.from_json(next_action.to_json(), self.game)
          else
            return nil
          end
        end
        
    end
    
end
