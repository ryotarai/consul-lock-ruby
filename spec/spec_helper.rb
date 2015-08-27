$LOAD_PATH.unshift File.expand_path('../../lib', __FILE__)
require 'consul/lock'
Consul::Lock.logger.level = Logger::ERROR
