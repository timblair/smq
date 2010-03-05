require "socket"

module SMQ

  class Worker

    attr_accessor :name
    attr_accessor :queue

    @working = false
    @stopping = false

    def initialize(queue)
      self.name = "#{Socket.gethostname}:#{Process.pid}" rescue "pid:#{Process.pid}"
      self.queue = SMQ::Queue.new(queue)
    end

    def to_s
      self.name
    end

    def work(until_empty = false, &block)
      @working = true
      empty = false
      empty_for = 0
      while(!empty && !@stopping) do
        if work_one_message(&block).nil?
          empty = true if until_empty
          sleep 1 unless (empty && (empty_for += 1) >= 10)
        else
          empty_for = 0
        end
      end
      @stopping = false
      @working = false
    end

    def work_one_message
      msg = self.queue.reserve(self)
      yield msg if !msg.nil? && block_given?
      msg
    end

    def stop!
      @stopping = true
    end

    def is_working?
      @working
    end

    def is_stopping?
      @stopping
    end

  end

end