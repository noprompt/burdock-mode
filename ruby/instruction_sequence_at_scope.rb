module InstructionSequenceAtScope
  def self.call(message)
    response = Burdock::Actions::ScopeAtLine.call(message)
    source = response[:params][:source]
    instruction_sequence = RubyVM::InstructionSequence.compile(source)
    response[:params][:source] = instruction_sequence.disasm
    response
  end
end
