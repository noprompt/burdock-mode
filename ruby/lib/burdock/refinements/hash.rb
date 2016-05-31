module Burdock
  module Refinements
    module Hash

      refine ::Hash do
        def fetch(*args)
          begin
            super *args
          rescue ::KeyError => e

          end
        end
      end

    end # Hash
  end # Refinements
end # Burdock
