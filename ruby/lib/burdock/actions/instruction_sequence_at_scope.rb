require "burdock/actions/registry"
require "burdock/actions/scope_at_line"

module Burdock
  module Actions
    module InstructionSequenceAtScope
      def self.call(message)
        response = Burdock::Actions::ScopeAtLine.call(message)
        source = response[:params][:source]
        instruction_sequence = RubyVM::InstructionSequence.compile(source)
        response[:params][:source] = instruction_sequence.disasm
        response
      end
    end
  end
end

Burdock::Actions::Registry.put("burdock/instruction-sequence-at-scope", Burdock::Actions::InstructionSequenceAtScope)
