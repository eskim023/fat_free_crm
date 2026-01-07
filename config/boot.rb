# frozen_string_literal: true

# Copyright (c) 2008-2013 Michael Dvorkin and contributors.
#
# Fat Free CRM is freely distributable under the terms of MIT license.
# See MIT-LICENSE file or http://www.opensource.org/licenses/mit-license.php
#------------------------------------------------------------------------------

ENV["BUNDLE_GEMFILE"] ||= File.expand_path("../Gemfile", __dir__)

require "bundler/setup" # Set up gems listed in the Gemfile.
require "bootsnap/setup" # Speed up boot time by caching expensive operations.

# Load local environment variables early enough for config/database.yml (ERB) to see them.
# We intentionally keep this dev/test-only and no-op if dotenv isn't available.
if %w[development test].include?(ENV.fetch("RAILS_ENV", "development"))
  begin
    require "dotenv"
    Dotenv.load(File.expand_path("../.env", __dir__))
  rescue LoadError
    # dotenv-rails is optional; if missing, rely on exported env vars.
  end
end
