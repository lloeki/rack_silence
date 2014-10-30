require 'rack_silence'
require 'rails'

RSpec.describe RackSilence::Logger do
  # Noop logger
  class NullLogger < Logger
    def initialize(*); end

    def add(*, &_); end
  end

  # TODO: stub in context
  Rails.logger = NullLogger.new

  # Mock logger that detects silencing
  class MockLogger
    def initialize
      @silenced = false
      @level = ::Logger::INFO
    end

    attr_reader :level

    def level=(level)
      # TODO: incomplete, should eval on actual call
      @silenced = true if level > self.level
      @level = level
    end

    def silenced?
      @silenced
    end
  end

  let(:app) { proc { [200, {}, ['Hello, world.']] } }

  let(:logger) { MockLogger.new }
  let(:stack) do
    RackSilence::Logger.new(app,
                            logger: logger,
                            header: :token,
                            silenced: [
                              RackSilence.token('deadbeef'),
                              '/ping',
                              %r{/assets/}
                            ])

  end
  let(:request) { Rack::MockRequest.new(stack) }

  context 'random, non-matching request' do
    let(:response) { request.get('/') }

    it do
      response
      expect(logger).not_to be_silenced
    end
  end

  context 'request with path matching a string' do
    let(:response) { request.get('/ping') }

    it do
      response
      expect(logger).to be_silenced
    end
  end

  context 'request with path matching a regex' do
    let(:response) { request.get('/assets/foo.js') }

    it do
      response
      expect(logger).to be_silenced
    end
  end

  context 'request with header' do
    let(:stack) do
      RackSilence::Logger.new(app,
                              header: true,
                              logger: logger)

    end
    let(:response) { request.get('/', 'HTTP_X_SILENCE_LOGGER' => '') }

    it do
      response
      expect(logger).to be_silenced
    end
  end

  context 'request with matching token' do
    let(:response) { request.get('/', 'HTTP_X_SILENCE_LOGGER' => 'deadbeef') }

    it do
      response
      expect(logger).to be_silenced
    end
  end

  context 'request with non-matching token' do
    let(:response) { request.get('/', 'HTTP_X_SILENCE_LOGGER' => 'foo') }

    it do
      response
      expect(logger).not_to be_silenced
    end
  end

  context 'with new relic' do
    let(:response) { request.get('/', 'HTTP_X_SILENCE_LOGGER' => 'deadbeef') }
    let(:newrelic_agent) { double }

    it 'should ignore the transaction' do
      stub_const('NewRelic::Agent', newrelic_agent)
      expect(newrelic_agent).to receive(:ignore_transaction)
      response
      expect(logger).to be_silenced
    end
  end
end
