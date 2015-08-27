require "consul/lock/version"
require "consul/lock/semaphore"

require "logger"

module Consul
  module Lock
    @url ||= "http://localhost:8500"
    @logger ||= Logger.new($stdout)

    class << self
      attr_accessor :url, :logger
    end
  end
end
