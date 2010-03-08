require 'rubygems'
require 'active_record'
require 'yajl'

require File.dirname(__FILE__) + '/smq/worker'
require File.dirname(__FILE__) + '/smq/message'
require File.dirname(__FILE__) + '/smq/queue'

module SMQ

  def self.now
    (ActiveRecord::Base.default_timezone == :utc) ? Time.now.utc : Time.now
  end

  def self.encode(object)
    Yajl::Encoder.encode(object)
  end

  def self.decode(object)
    return unless object
    Yajl::Parser.parse(object, :check_utf8 => false)
  end

  def self.load_schema!(force = false)
    return if !force && ActiveRecord::Base.connection.tables.include?(SMQ::Message.table_name)
    ActiveRecord::Schema.define do
      create_table :smq_messages, :force => force do |t|
        t.string     :queue, :limit => 30, :null => false
        t.text       :payload
        t.datetime   :locked_at
        t.string     :locked_by, :limit => 50
        t.integer    :attempts, :limit => 2, :default => 0
        t.datetime   :failed_at
        t.datetime   :completed_at
        t.timestamps
      end
      add_index "smq_messages", ["queue", "completed_at", "locked_by"], :name => "idx_smq_available"
      add_index "smq_messages", ["id", "updated_at", "locked_by", "completed_at"], :name => "idx_smq_unlocked"
    end
  end

  def self.flush_all_queues!
    # yes, not the most efficient, but *should* only be called during testing
    # so it's not that much of a concern
    SMQ::Message.delete_all
  end

end
