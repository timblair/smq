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
      find_available.each do |msg|
        m = msg.lock!(worker)
        return m unless m == nil
      end
      nil
    end

    def find_available
      SMQ::Message.find(:all, :select => 'id, updated_at', :conditions => ["queue = ? AND completed_at IS NULL AND locked_by IS NULL", @name], :order => "id ASC", :limit => @batch_size).sort_by { rand() }
    end

    def length
      SMQ::Message.count(:conditions => ["queue = ? AND completed_at IS NULL", @name])
    end

    def flush!
      delete_queue_items
    end

    def clear_completed!
      delete_queue_items "completed_at IS NOT NULL"
    end
    def clear_successful!
      delete_queue_items "completed_at IS NOT NULL AND failed_at IS NULL"
    end
    def clear_failed!
      delete_queue_items "completed_at IS NOT NULL AND failed_at IS NOT NULL"
    end

    private

    def delete_queue_items(where = nil)
      SMQ::Message.delete_all(["queue = ? #{where ? 'AND ' + where : ''}", @name])
    end

  end

end
