require "mjai/pai"
require "mjai/mentsu"


module Mjai
    
    class YmatsuxShantenAnalysis
        
        NUM_PIDS = 9 * 3 + 7
        TYPES = ["m", "p", "s", "t"]
        TYPE_TO_TYPE_ID = {"m" => 0, "p" => 1, "s" => 2, "t" => 3}

        def self.create_mentsus()
          mentsus = []
          for i in 0...NUM_PIDS
            mentsus.push([i] * 3)
          end
          for t in 0...3
            for n in 0...7
              pid = t * 9 + n
              mentsus.push([pid, pid + 1, pid + 2])
            end
          end
          return mentsus
        end

        MENTSUS = create_mentsus()

        def initialize(pais)
          @pais = pais
          count_vector = YmatsuxShantenAnalysis.pais_to_count_vector(pais)
          @shanten = YmatsuxShantenAnalysis.calculate_shantensu_internal(count_vector, [0] * NUM_PIDS, 4, 0, 1.0/0.0)
        end
        
        attr_reader(:pais, :shanten)

        def self.pais_to_count_vector(pais)
          count_vector = [0] * NUM_PIDS
          for pai in pais
            count_vector[pai_to_pid(pai)] += 1
          end
          return count_vector
        end

        def self.pai_to_pid(pai)
          return TYPE_TO_TYPE_ID[pai.type] * 9 + (pai.number - 1)
        end

        def self.pid_to_pai(pid)
          return Pai.new(TYPES[pid / 9], pid % 9 + 1)
        end

        def self.calculate_shantensu_internal(
            current_vector, target_vector, left_mentsu, min_mentsu_id, found_min_shantensu)
          min_shantensu = found_min_shantensu
          if left_mentsu == 0
            for pid in 0...NUM_PIDS
              target_vector[pid] += 2
              if valid_target_vector?(target_vector)
                shantensu = calculate_shantensu_lowerbound(current_vector, target_vector)
                min_shantensu = [shantensu, min_shantensu].min
              end
              target_vector[pid] -= 2
            end
          else
            for mentsu_id in min_mentsu_id...MENTSUS.size
              add_mentsu(target_vector, mentsu_id)
              lower_bound = calculate_shantensu_lowerbound(current_vector, target_vector)
              if valid_target_vector?(target_vector) && lower_bound < found_min_shantensu
                shantensu = calculate_shantensu_internal(
                    current_vector, target_vector, left_mentsu - 1, mentsu_id, min_shantensu)
                min_shantensu = [shantensu, min_shantensu].min
              end
              remove_mentsu(target_vector, mentsu_id)
            end
          end
          return min_shantensu
        end

        def self.calculate_shantensu_lowerbound(current_vector, target_vector)
          count = (0...NUM_PIDS).inject(0) do |c, pid|
            c + (target_vector[pid] > current_vector[pid] ? target_vector[pid] - current_vector[pid] : 0)
          end
          return count - 1
        end

        def self.valid_target_vector?(target_vector)
          return target_vector.all?(){ |c| c <= 4 }
        end

        def self.add_mentsu(target_vector, mentsu_id)
          for pid in MENTSUS[mentsu_id]
            target_vector[pid] += 1
          end
        end

        def self.remove_mentsu(target_vector, mentsu_id)
          for pid in MENTSUS[mentsu_id]
            target_vector[pid] -= 1
          end
        end

    end
        
end
