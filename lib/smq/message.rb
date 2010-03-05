module SMQ

  class Message < ActiveRecord::Base
    set_table_name :smq_messages
    validates_presence_of :queue
    MAX_ATTEMPTS = 5

    def self.build(payload, queue = nil)
      msg = self.new
      msg.payload = SMQ.encode(payload)
      msg.queue = queue
      msg
    end

    def data
      SMQ.decode(payload)
    end
    def data=(object)
      self.payload = SMQ.encode(object)
    end

    def retry!
      self.locked_by = nil
      self.locked_at = nil
      fail if self.attempts >= MAX_ATTEMPTS
      save!
    end

    def lock!(worker)
      rows = self.class.update_all(
        ["updated_at = ?, locked_at = ?, locked_by = ?, attempts = (attempts+1)", SMQ.now, SMQ.now, worker.name],
        ["id = ? AND updated_at = ? AND locked_by IS NULL AND completed_at IS NULL", self.id, self.updated_at]
      )
      if rows == 1
        self.reload
        return self
      end
      nil
    end

    def complete
      self.completed_at = SMQ.now
    end
    def fail
      self.failed_at = SMQ.now
      complete
    end

    def ack!
      complete
      save!
    end

  end

end
