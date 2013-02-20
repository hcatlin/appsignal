require 'socket'
require 'appsignal/transaction/transaction_formatter'

module Appsignal
  class Transaction
    def self.create(key, env)
      Thread.current[:appsignal_transaction_id] = key
      Appsignal.transactions[key] = Appsignal::Transaction.new(key, env)
    end

    def self.current
      Appsignal.transactions[Thread.current[:appsignal_transaction_id]]
    end

    attr_reader :id, :events, :process_action_event, :action, :exception, :env

    def initialize(id, env)
      @id = id
      @events = []
      @process_action_event = nil
      @exception = nil
      @env = env
    end

    def request
      ActionDispatch::Request.new(@env)
    end

    def set_process_action_event(event)
      # TODO simplify these conditions once we refactor the tracer
      @process_action_event = event
      if @process_action_event &&
         @process_action_event.respond_to?(:payload) &&
         @process_action_event.payload
        @action = "#{process_action_event.payload[:controller]}#"\
                  "#{process_action_event.payload[:action]}"
      end
    end

    def add_event(event)
      @events << event
    end

    def add_exception(ex)
      @exception = ex
    end

    def exception?
      !!exception
    end

    def slow_request?
      return false unless process_action_event && process_action_event.payload
      Appsignal.config[:slow_request_threshold] <= process_action_event.duration
    end

    def clear_payload_and_events!
      @process_action_event.payload.clear
      @events.clear
    end

    def to_hash
      if exception?
        TransactionFormatter.faulty(self)
      elsif slow_request?
        TransactionFormatter.slow(self)
      else
        TransactionFormatter.regular(self)
      end.to_hash
    end

    def complete!
      Thread.current[:appsignal_transaction_id] = nil
      current_transaction = Appsignal.transactions.delete(@id)
      if process_action_event || exception?
        Appsignal.agent.add_to_queue(current_transaction)
      end
    end

    def complete_trace!
      Thread.current[:appsignal_transaction_id] = nil
      hash = {:process_action_event => process_action_event, :exception => exception}
      Appsignal.agent.add_to_queue(hash)
    end
  end
end
