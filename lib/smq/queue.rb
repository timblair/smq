module SMQ

  class Queue

    attr_accessor :name
    attr_accessor :batch_size

    def initialize(name, batch_size = 5)
      @name = name
      @batch_size = batch_size
    end

    def to_s
      @name
    end

    def push(msg)
      msg.queue = @name
      msg.save!
      msg
    end

    def enqueue(payload)
      push SMQ::Message.build(payload)
    end

    def reserve(worker)
      find_available(worker.batches, worker.batch).each do |msg|
        m = msg.lock!(worker)
        return m unless m == nil
      end
      nil
    end

    def find_available(batches=1, batch=1)
      SMQ::Message.find(
        :all,
        :select => 'id, updated_at',
        :conditions => [
          "queue = ? AND (id % ?) = ? AND completed_at IS NULL AND locked_by IS NULL",
          @name, batches, batch-1
        ],
        :order => "id ASC", :limit => @batch_size
      ).sort_by { rand() }
    end

    def length
      SMQ::Message.count(:conditions => ["queue = ? AND completed_at IS NULL", @name])
    end

    def flush!
      delete_queue_items
    end

    def clear_completed!(limit = nil)
      delete_queue_items "completed_at IS NOT NULL", limit
    end
    def clear_successful!(limit = nil)
      delete_queue_items "completed_at IS NOT NULL AND failed_at IS NULL", limit
    end
    def clear_failed!(limit = nil)
      delete_queue_items "completed_at IS NOT NULL AND failed_at IS NOT NULL", limit
    end

    private

    def delete_queue_items(where = nil, limit = nil)
      if (limit.nil?)
        SMQ::Message.delete_all(["queue = ? #{where ? 'AND ' + where : ''}", @name])
      else
        # delete_all doesn't support a :limit clause, so we have to fake it
        msg = SMQ::Message.find(
          :first, :select => 'id',
          :conditions => ["queue = ? #{where ? 'AND ' + where : ''}", @name],
          :order => "id ASC", :offset => limit
        )
        SMQ::Message.delete_all(["queue = ? AND id < ? #{where ? 'AND ' + where : ''}", @name, msg.id]) unless msg.nil?
      end
    end

  end

end
