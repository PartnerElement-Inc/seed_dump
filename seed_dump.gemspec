# -*- encoding: utf-8 -*-
# stub: seed_dump 3.3.2 ruby lib

Gem::Specification.new do |s|
  s.name = "seed_dump".freeze
  s.version = "3.3.2"

  s.required_rubygems_version = Gem::Requirement.new(">= 0".freeze) if s.respond_to? :required_rubygems_version=
  s.require_paths = ["lib".freeze]
  s.authors = ["Rob Halff".freeze, "Ryan Oblak".freeze]
  s.date = "2018-05-08"
  s.description = "Dump (parts) of your database to db/seeds.rb to get a headstart creating a meaningful seeds.rb file".freeze
  s.email = "rroblak@gmail.com".freeze
  s.extra_rdoc_files = ["README.md".freeze]
  s.files = [".rspec".freeze, "Gemfile".freeze, "MIT-LICENSE".freeze, "README.md".freeze, "Rakefile".freeze, "VERSION".freeze, "lib/seed_dump.rb".freeze, "lib/seed_dump/dump_methods.rb".freeze, "lib/seed_dump/dump_methods/enumeration.rb".freeze, "lib/seed_dump/environment.rb".freeze, "lib/seed_dump/railtie.rb".freeze, "lib/tasks/seed_dump.rake".freeze, "seed_dump.gemspec".freeze, "spec/dump_methods_spec.rb".freeze, "spec/environment_spec.rb".freeze, "spec/factories/another_samples.rb".freeze, "spec/factories/samples.rb".freeze, "spec/factories/yet_another_samples.rb".freeze, "spec/helpers.rb".freeze, "spec/spec_helper.rb".freeze]
  s.homepage = "https://github.com/rroblak/seed_dump".freeze
  s.licenses = ["MIT".freeze]
  s.rubygems_version = "3.4.6".freeze
  s.summary = "{Seed Dumper for Rails}".freeze

  s.installed_by_version = "3.4.6" if s.respond_to? :installed_by_version

  s.specification_version = 4

  s.add_runtime_dependency(%q<activesupport>.freeze, [">= 4"])
  s.add_runtime_dependency(%q<activerecord>.freeze, [">= 4"])
  s.add_development_dependency(%q<byebug>.freeze, ["~> 2.0"])
  s.add_development_dependency(%q<factory_bot>.freeze, ["~> 4.8.2"])
  s.add_development_dependency(%q<activerecord-import>.freeze, ["~> 0.4"])
  s.add_development_dependency(%q<jeweler>.freeze, ["~> 2.0"])
end
