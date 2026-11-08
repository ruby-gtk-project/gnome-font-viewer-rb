# frozen_string_literal: true

# kettle-jem:freeze
# To retain chunks of comments & code during kettle-jem templating:
# Wrap custom sections with freeze markers (e.g., as above and below this comment chunk).
# kettle-jem will then preserve content between those markers across template runs.
# kettle-jem:unfreeze

# gnome-font-viewer-rb Rakefile v7.1.28 - 2026-10-11
# Ruby 2.3 (Safe Navigation) or higher required
#
# See LICENSE.md for license information.
#
# Copyright (c) 2026 ruby-gtk-project (github.com)
#
# Expected to work in any project that uses Bundler.
#
# Sets up tasks for appraisal2, floss_funding, kettle-jem, kettle-dev, rspec, minitest, rubocop_gradual, reek, yard, and stone_checksums.
#
# rake appraisal:install                      # Install Appraisal gemfiles (initial setup...
# rake appraisal:reset                        # Delete Appraisal lockfiles (gemfiles/*.gemfile.lock)
# rake appraisal:generate                     # Generate Appraisal gemfiles without resolving...
# rake appraisal:update                       # Generate and update Appraisal gemfiles
# rake bench                                  # Run all benchmarks (alias for bench:run)
# rake bench:list                             # List available benchmark scripts
# rake bench:run                              # Run all benchmark scripts (skips on CI)
# rake build:generate_checksums               # Generate both SHA256 & SHA512 checksums i...
# rake bundle:audit:check                     # Checks the Gemfile.lock for insecure depe...
# rake bundle:audit:update                    # Updates the bundler-audit vulnerability d...
# rake ci:act[opt]                            # Run 'act' with a selected workflow
# rake coverage                               # Run specs w/ coverage and open results in...
# rake default                                # Default tasks aggregator
# rake install                                # Build and install gnome-font-viewer-rb-1.0.0.gem in...
# rake install:local                          # Build and install gnome-font-viewer-rb-1.0.0.gem in...
# rake kettle:jem:install                     # Internal target used by `kettle-jem install`
# rake kettle:jem:selftest                    # Self-test: template gnome-font-viewer-rb against itse...
# rake kettle:jem:template                    # Internal target used by scoped `kettle-jem template --only`
# rake reek                                   # Check for code smells
# rake reek:update                            # Run reek and store the output into the RE...
# rake release[remote]                        # Create tag v1.0.0 and build and push kett...
# rake rubocop_gradual                        # Run RuboCop Gradual
# rake rubocop_gradual:autocorrect            # Run RuboCop Gradual with autocorrect (onl...
# rake rubocop_gradual:autocorrect_all        # Run RuboCop Gradual with autocorrect (saf...
# rake rubocop_gradual:check                  # Run RuboCop Gradual to check the lock file
# rake rubocop_gradual:force_update           # Run RuboCop Gradual to force update the l...
# rake rubocop_gradual_debug                  # Run RuboCop Gradual
# rake rubocop_gradual_debug:autocorrect      # Run RuboCop Gradual with autocorrect (onl...
# rake rubocop_gradual_debug:autocorrect_all  # Run RuboCop Gradual with autocorrect (saf...
# rake rubocop_gradual_debug:check            # Run RuboCop Gradual to check the lock file
# rake rubocop_gradual_debug:force_update     # Run RuboCop Gradual to force update the l...
# rake spec                                   # Run RSpec code examples
# rake test                                   # Run tests
# rake yard                                   # Generate YARD Documentation
# rake yard:lint                              # Lint YARD Documentation
#

# simplecov:disable
require "bundler/gem_tasks" if !Dir[File.join(__dir__, "*.gemspec")].empty?
# simplecov:enable

# Define a base default task early so other files can enhance it.
desc "Default tasks aggregator"
task :default do
  puts "Default task complete."
end

# Without this, a generated docs/ directory makes Rake resolve the bare
# name `docs` as an up-to-date file task, so `rake docs` exits 0 having
# regenerated nothing.
desc "Generate YARD documentation"
task docs: "yard"

# simplecov:disable
### MONOREPO FAMILY TASKS
if Dir.exist?(File.join(__dir__, "gems"))
  def family_gem_dirs
    Dir.glob(File.join(__dir__, "gems", "*", "*.gemspec"))
      .map { |path| File.dirname(path) }
      .uniq
      .sort_by { |path| File.basename(path) }
  end

  def run_kettle_family(*args)
    sh("bundle", "exec", "kettle-family", *args)
  end

  namespace :family do
    desc "List released Ruby subgems"
    task :list do
      family_gem_dirs.each { |path| puts File.basename(path) }
    end

    desc "Run release readiness checks for the Ruby gem family"
    task :readiness do
      run_kettle_family("check")
    end

    desc "Run tests for the Ruby gem family"
    task :test do
      run_kettle_family("test", "--execute")
    end

    desc "Run lint for the Ruby gem family"
    task :lint do
      run_kettle_family("lint", "--execute")
    end

    desc "Generate YARD docs for the Ruby gem family"
    task :docs do
      run_kettle_family("docs", "--execute")
    end

    desc "Report release state for the Ruby gem family"
    task :release_state do
      run_kettle_family("release-state")
    end

    desc "Run the Ruby gem family release planner"
    task :release do
      run_kettle_family("release")
    end

    desc "Execute the Ruby gem family release"
    task :release_execute do
      run_kettle_family("release", "--execute")
    end
  end
end
# simplecov:enable

# External gems that define tasks - add here!
begin
  require "kettle/dev"
  Kettle::Dev.install_tasks unless Kettle::Dev::RUNNING_AS == "rake"
rescue LoadError
  warn("NOTE: kettle-dev isn't installed, or is disabled for #{RUBY_VERSION} in the current environment")
end

### TEMPLATING TASKS
# These tasks are installed for the `kettle-jem` executable. Run full templating
# through `kettle-jem install`; use `kettle-jem template --only PATH` only for
# scoped file updates. The executable prepares the environment and then
# delegates here when rake orchestration is needed.
kettle_jem_selftest_unavailable_note = nil
begin
  require "kettle/jem"
  if Kettle::Jem.respond_to?(:install_tasks)
    Kettle::Jem.install_tasks
  else
    kettle_jem_selftest_unavailable_note = "NOTE: kettle-jem #{Kettle::Jem::Version::VERSION} does not provide rake tasks in this environment"
  end
rescue LoadError
  kettle_jem_selftest_unavailable_note = "NOTE: kettle-jem isn't installed, or is disabled for #{RUBY_VERSION} in the current environment"
end

if kettle_jem_selftest_unavailable_note
  desc("(stub) kettle:jem:selftest is unavailable")
  task("kettle:jem:selftest") do
    warn(kettle_jem_selftest_unavailable_note)
  end
end

### RELEASE TASKS
# Setup stone_checksums
begin
  require "stone_checksums"
rescue LoadError
  desc("(stub) build:generate_checksums is unavailable")
  task("build:generate_checksums") do
    warn("NOTE: stone_checksums isn't installed, or is disabled for #{RUBY_VERSION} in the current environment")
  end
end

# kettle-jem:freeze
### I18N TASKS
# Ruby equivalents of the Meson i18n module's targets, driven by
# po/POTFILES.in and po/LINGUAS. Needs the dev shell (pkgs.gettext for
# msgmerge/msgfmt, pkgs.rubyPackages_3_4.gettext for rxgettext).
namespace :i18n do
  POT_FILE = File.join(__dir__, "po", "gnome-font-viewer-rb.pot")
  POTFILES = File.readlines(File.join(__dir__, "po", "POTFILES.in"))
    .map(&:strip)
    .reject { |line| line.empty? || line.start_with?("#") }
  # rxgettext only understands Ruby source; data/*.desktop.in.in and
  # data/*.metainfo.xml.in need plain xgettext, which (like upstream's own
  # xgettext) recognises the Desktop Entry and AppStream metainfo formats on
  # its own. The two extractions are combined with msgcat, in POTFILES.in's
  # order, into one .pot.
  RUBY_POTFILES = POTFILES.grep(/\.rb\z/)
  DATA_POTFILES = POTFILES - RUBY_POTFILES
  LINGUAS = File.readlines(File.join(__dir__, "po", "LINGUAS"))
    .map(&:strip)
    .reject { |line| line.empty? || line.start_with?("#") }

  desc "Extract translatable strings from POTFILES.in into the .pot template"
  task :pot do
    # Both tools record each "#:" source-location comment relative to the
    # directory of their own --output file, not the process's cwd, so the
    # intermediate .pot files have to live in po/ alongside the real one —
    # writing them to a tmpdir would turn every "../lib/foo.rb:N" comment
    # into a useless "../../../home/.../lib/foo.rb:N".
    data_pot = File.join(__dir__, "po", ".data.pot")
    ruby_pot = File.join(__dir__, "po", ".ruby.pot")

    # rxgettext's bin stub resolves itself through Gem.activate_bin_path,
    # which Bundler's runtime restricts to gems the Gemfile locked; gettext
    # (and so rxgettext) is a devshell tool, not a bundled dependency, so the
    # lookup needs Bundler's own process environment, not the one Bundler
    # narrowed this process to.
    Bundler.with_unbundled_env do
      sh(
        "xgettext",
        "--output", data_pot,
        "--from-code", "UTF-8",
        "--package-name", "gnome-font-viewer-rb",
        *DATA_POTFILES,
      )
      sh(
        "rxgettext",
        "--output", ruby_pot,
        "--package-name", "gnome-font-viewer-rb",
        *RUBY_POTFILES,
      )
      sh("msgcat", "--use-first", "--output", POT_FILE, data_pot, ruby_pot)
    end
  ensure
    FileUtils.rm_f([data_pot, ruby_pot])
  end

  desc "Merge the .pot template's new/changed strings into every po/*.po"
  task update: :pot do
    LINGUAS.each do |lang|
      po_file = File.join(__dir__, "po", "#{lang}.po")
      if File.exist?(po_file)
        sh("msgmerge", "--update", "--backup=none", po_file, POT_FILE)
      end
    end
  end

  desc "Compile po/*.po into locale/<lang>/LC_MESSAGES/gnome-font-viewer-rb.mo"
  task :mo do
    LINGUAS.each do |lang|
      po_file = File.join(__dir__, "po", "#{lang}.po")
      next unless File.exist?(po_file)

      mo_dir = File.join(__dir__, "locale", lang, "LC_MESSAGES")
      FileUtils.mkdir_p(mo_dir)
      sh("msgfmt", "--output-file", File.join(mo_dir, "gnome-font-viewer-rb.mo"), po_file)
    end
  end
end
# kettle-jem:unfreeze
