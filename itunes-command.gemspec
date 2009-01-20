# -*- encoding: utf-8 -*-

Gem::Specification.new do |s|
  s.name = %q{itunes-command}
  s.version = "1.6.2"
  s.platform = %q{x86-darwin-9}

  s.required_rubygems_version = Gem::Requirement.new(">= 0") if s.respond_to? :required_rubygems_version=
  s.authors = ["Daniel Choi"]
  s.date = %q{2009-01-20}
  s.default_executable = %q{itunes-command}
  s.description = %q{Search, queue, and play iTunes tracks from the command line.}
  s.email = %q{dhchoi@gmail.com}
  s.executables = ["itunes-command"]
  s.files = ["lib/itunes_command.rb", "bin/itunes-command"]
  s.has_rdoc = true
  s.homepage = %q{http://danielchoi.com/software/itunes-command}
  s.rdoc_options = ["--inline-source", "--charset=UTF-8"]
  s.require_paths = ["lib"]
  s.rubygems_version = %q{1.3.1}
  s.summary = %q{Search and play iTunes tracks from the command line}

  if s.respond_to? :specification_version then
    current_version = Gem::Specification::CURRENT_SPECIFICATION_VERSION
    s.specification_version = 2

    if Gem::Version.new(Gem::RubyGemsVersion) >= Gem::Version.new('1.2.0') then
    else
    end
  else
  end
end
