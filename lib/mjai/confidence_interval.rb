module Mjai
    
    module ConfidenceInterval
        
      module_function

        # Uses bootstrap resampling.
        def calculate(samples, params = {})
          params = {:min => 0.0, :max => 1.0, :conf_level => 0.95}.merge(params)
          num_tries = 1000
          averages = []
          num_tries.times() do
            sum = 0.0
            (samples.size + 2).times() do
              idx = rand(samples.size + 2)
              case idx
                when samples.size
                  sum += params[:min]
                when samples.size + 1
                  sum += params[:max]
                else
                  sum += samples[idx]
              end
            end
            averages.push(sum / (samples.size + 2))
          end
          averages.sort!()
          margin = (1.0 - params[:conf_level]) / 2
          return [
            averages[(num_tries * margin).to_i()],
            averages[(num_tries * (1.0 - margin)).to_i()],
          ]
        end
        
    end
    
end
