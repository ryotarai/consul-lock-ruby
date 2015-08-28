require "faraday"
require "json"
require "base64"

require "consul/lock/client"

module Consul
  module Lock
    class Semaphore
      def initialize(key, limit)
        @prefix = "consul-lock-ruby/#{key}/lock"
        @limit = limit
      end

      def reset
        client.delete_kv(@prefix, recurse: true)
      end

      def lock
        raise "already locked" if @session_id

        @session_id = client.create_session("Name" => "consul-lock-ruby")["ID"]
        debug "new session"

        unless client.put_kv("#{@prefix}/#{@session_id}", nil, acquire: @session_id)
          raise "failed to put kv"
        end

        while true
          kvs = client.get_kv(@prefix, recurse: true)
          lock_kv = kvs.find {|kv| kv["Key"].end_with?("/.lock") }
          alive_holders = kvs.map {|kv| kv["Session"] }.compact

          if lock_kv
            lock = JSON.parse(Base64.decode64(lock_kv['Value']))
            unless lock["Limit"] == @limit
              raise "semaphore limit conflict (lock: #{lock["Limit"]}, local: #{@limit})"
            end

            lock["Holders"].select! do |holder|
              alive_holders.include?(holder)
            end

            modify_index = lock_kv['ModifyIndex']
            if lock["Holders"].size < lock["Limit"]
              lock["Holders"] << @session_id

              debug lock
              if client.put_kv("#{@prefix}/.lock", lock.to_json, {cas: modify_index})
                debug "locked"
                return
              end

              sleep(rand * 0.1) # to avoid conflict
            else
              debug "blocking"
              res = client.get_kv("#{@prefix}/.lock", index: modify_index)
              debug "changed"
            end
          else
            debug "no lock found. create new one"
            lock = {
              "Limit" => @limit,
              "Holders" => [@session_id],
            }
            debug lock
            if client.put_kv("#{@prefix}/.lock", lock.to_json, cas: 0)
              debug "locked"
              return
            end

            sleep(rand * 0.1) # to avoid conflict
          end

          debug "retrying"
        end
      end

      def unlock
        debug "unlock start"

        raise "no session" unless @session_id

        # update .lock
        while true
          kv = client.get_kv("#{@prefix}/.lock").first
          lock = JSON.parse(Base64.decode64(kv['Value']))
          lock["Holders"].delete(@session_id)

          debug lock
          if client.put_kv("#{@prefix}/.lock", lock.to_json, {cas: kv['ModifyIndex']})
            break
          end

          debug "retrying"
          sleep rand
        end

        # remove key
        client.delete_kv "#{@prefix}/#{@session_id}"

        # destroy session
        client.destroy_session @session_id
        debug "unlock done"
        @session_id = nil
      end

      def with_lock
        lock
        yield
      ensure
        unlock
      end

      private

      def client
        @client ||= Client.new(Consul::Lock.url)
      end

      def debug(msg)
        Consul::Lock.logger.debug "#{@session_id}: #{msg}"
      end
    end
  end
end
