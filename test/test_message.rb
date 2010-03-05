require 'helper'

class MessageTest < Test::Unit::TestCase

  def setup
    @simple_value  = "string"
    @complex_value = SMQ::decode(SMQ::encode({ :a => 1, :b => 2, :c => [1,2,3] })) # JSON-ifying muddles things around
    @msg = SMQ::Message.build(@simple_value, "test_queue")
    @worker = SMQ::Worker.new("test_queue")
  end

  def teardown
    SMQ.flush_all_queues!
  end

  def test_builing_message_returns_instance_of_message
    assert_instance_of SMQ::Message, @msg
  end

  def test_building_message_correctly_encodes_payload_for_simple_value
    assert_equal @msg.payload, SMQ::encode(@simple_value)
  end

  def test_building_message_correctly_encodes_payload_for_complex_value
    msg = SMQ::Message.build(@complex_value)
    assert_equal msg.payload, SMQ::encode(@complex_value)
  end

  def test_data_is_decoded_payload_for_simple_value
    assert_equal @msg.data, @simple_value
  end

  def test_data_is_decoded_payload_for_complex_value
    msg = SMQ::Message.build(@complex_value)
    assert_equal msg.data, @complex_value
  end

  def test_setting_data_correctly_serialises_to_payload
    @msg.data = @complex_value
    assert_equal @msg.data, @complex_value
    assert_equal @msg.payload, SMQ::encode(@complex_value)
  end

  def test_complete_sets_completed_at_timestamp
    @msg.complete
    assert_not_nil @msg.completed_at
  end

  def test_fail_sets_completed_and_fail_at_timestamps
    @msg.fail
    assert_not_nil @msg.completed_at
    assert_not_nil @msg.failed_at
  end

  def test_message_should_not_save_without_a_queue_name
    @msg.queue = nil
    assert_raise ActiveRecord::RecordInvalid do
      @msg.save!
    end
  end

  def test_ack_marks_message_as_complete_and_saves
    @msg.ack!
    assert_not_nil @msg.completed_at
    assert_not_nil @msg.id
  end

  def test_should_lock_an_unlocked_message
    @msg.save!
    msg = @msg.lock!(@worker)
    assert_equal msg.id, @msg.id
    assert_not_nil @msg.locked_at
    assert_equal @msg.locked_by, @worker.name
  end

  def test_should_return_nil_when_locking_a_completed_message
    @msg.ack!
    assert_nil @msg.lock!(@worker)
  end

  def test_should_return_nil_when_locking_a_locked_message_locked_by_someone_else
    @msg.locked_by = 'random_worker'
    @msg.save!
    assert_nil @msg.lock!(@worker)
  end

  def test_locking_a_message_increments_the_attempts_count
    @msg.save!
    assert_equal @msg.attempts + 1, @msg.lock!(SMQ::Worker.new("test_queue")).attempts
  end

end
