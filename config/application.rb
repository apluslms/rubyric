require_relative 'boot'

require 'rails/all'

# Require the gems listed in Gemfile, including any gems
# you've limited to :test, :development, or :production.
Bundler.require(*Rails.groups)

module Rubyric
  class Application < Rails::Application
    # Initialize configuration defaults for originally generated Rails version.
    config.load_defaults 7.0
    
    # Settings in config/environments/* take precedence over those specified here.
    # Application configuration should go into files in config/initializers
    # -- all .rb files in that directory are automatically loaded.
    config.autoload_paths += Dir[Rails.root.join('app', 'models', '{*/}')]

    # Custom configuration whether or not to ask agree terms in create course instance
    config.ask_agree_terms = true

    config.after_initialize do
		Delayed::Backend::ActiveRecord::Job.table_name='delayed_jobs'
    end
  end
end
