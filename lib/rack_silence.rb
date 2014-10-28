require 'rack'

# Rack middleware that allows silencing select requests
# by path or header. Token can be set to prevent arbitrary
# people from silencing logs.
#
# Example `config/initializers/rack_silence.rb` for Rails:
#
#     # inject rack logger in Application class:
#     Rails.application.config
#     .middleware.insert_before(Rails::Rack::Logger, RackSilence::Logger,
#                               silenced: [RackSilence.token("decafbad"),
#                                          '/noisy/action.json',
#                                          %r{^/uninteresting/[0-9]+}])
module RackSilence
  # Impose silence on the app's logger
  class Logger
    # @param app Rack app
    # @param logger set logger to control. Make it lazy in a `proc`
    #   Defaults to a lazy `Rails.logger`
    # @param header check header `X-SILENCE-LOGGER` before silencing
    #   Can be true, false, or `:token`
    # @param silenced array of criterias to silence
    #   Can be `String` or `Regexp` to match a path, or `Token` objects
    def initialize(app, opts = {})
      @app = app
      @opts = opts
      @opts[:silenced] ||= []
      @opts[:logger]   ||= -> { Rails.logger }
      @opts[:level]    ||= ::Logger::ERROR
    end

    def call(env)
      return @app.call(env) unless silence?(env)

      silence_new_relic
      silence(logger) { @app.call(env) }
    end

    protected

    def silence_new_relic
      NewRelic::Agent.ignore_transaction
    rescue NameError
      nil
    end

    def silence(logger, temporary_level = @opts[:level])
      previous_level, logger.level = logger.level, temporary_level
      yield
    ensure
      logger.level = previous_level
    end

    def logger
      @opts[:logger].respond_to?(:call) ? @opts[:logger].call : @opts[:logger]
    end

    def silence?(env)
      header_silence?(env) || path_silence?(env)
    end

    def header_silence?(env)
      return unless @opts.key?(:header)

      if @opts[:header] == :token
        return @opts[:silenced].reduce(false) do |acc, rule|
          acc || rule.is_a?(Token) && rule == env['HTTP_X_SILENCE_LOGGER']
        end
      end

      env.key?('HTTP_X_SILENCE_LOGGER') if @opts[:header]
    end

    def path_silence?(env)
      @opts[:silenced].reduce(false) do |acc, rule|
        acc || case rule
               when String then rule == env['PATH_INFO']
               when Regexp then rule.match(env['PATH_INFO'])
               else false
               end
      end
    end
  end

  # Token value to match against in header
  class Token < String; end

  # Convenience function to create a token
  def self.token(value)
    Token.new(value)
  end
end
