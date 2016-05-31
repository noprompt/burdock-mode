module Burdock
  module Environment

    def self.inside_emacs?
      ENV.has_key?("INSIDE_EMACS")
    end

    def self.emacs_version
      if inside_emacs?
        ENV["EMACS"]
      else
        ""
      end
    end

  end # Environment
end # Burdock
