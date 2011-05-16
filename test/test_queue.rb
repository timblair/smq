require 'helper'

class QueueTest < Test::Unit::TestCase

  def setup
    @queue = SMQ::Queue.new("test_queue")
    @worker = SMQ::Worker.new(@queue.name)
  end

  def teardown
    SMQ.flush_all_queues!
  end

  def test_pushing_a_message_should_add_it_to_the_queue
    msg = SMQ::Message.build("payload")
    @queue.push(msg)
    assert_equal 1, @queue.length
  end

  def test_enqueueing_a_payload_should_create_a_message_and_add_it_to_the_queue
    msg = @queue.enqueue("payload")
    assert_instance_of SMQ::Message, msg
    assert_equal 1, @queue.length
  end

  def test_should_reserve_a_message_when_one_is_available
    populate_queue(@queue, 1)
    assert_instance_of SMQ::Message, @queue.reserve(@worker)
  end

  def test_reserve_should_return_nil_when_no_message_to_reserve
    assert_nil @queue.reserve(@worker)
  end

  def test_find_available_should_return_up_to_batch_size_queued_messages
    populate_queue(@queue, 10)
    @queue.batch_size = 3
    assert_equal @queue.batch_size, @queue.find_available.length
  end

  def test_flush_should_clear_all_messages_from_the_queue
    populate_queue(@queue, 5)
    @queue.flush!
    assert_equal 0, @queue.length
  end

  def test_clearing_completed_should_not_touch_incomplete_messages
    populate_queue(@queue, 5)
    SMQ::Message.find(:first).ack!
    @queue.clear_completed!
    assert_equal 4, @queue.length
  end

  def test_clearing_successful_should_not_touch_failed_messages
    populate_and_ack_all_but_fail_one
    @queue.clear_successful!
    assert_equal 1, SMQ::Message.count(:conditions => ["queue = ?", @queue.name])
  end

  def test_clearing_completed_should_limit_correctly
    populate_and_ack_all_but_fail_one
    @queue.clear_completed! 1
    assert_equal 4, SMQ::Message.count(:conditions => ["queue = ?", @queue.name])
  end

  def test_clearing_completed_should_limit_correctly_with_more_than_one_queue
    populate_and_ack_all_but_fail_one SMQ::Queue.new("another_queue")
    populate_and_ack_all_but_fail_one
    @queue.clear_completed! 2
    assert_equal 3, SMQ::Message.count(:conditions => ["queue = ?", @queue.name])
  end

  def test_clearing_failures_should_not_touch_successful_messages
    populate_and_ack_all_but_fail_one
    @queue.clear_failed!
    assert_equal 4, SMQ::Message.count(:conditions => ["queue = ?", @queue.name])
  end

  def test_clearing_one_queue_should_not_affect_another
    @other_queue = SMQ::Queue.new("other_queue")
    populate_queue(@queue, 5)
    populate_queue(@other_queue, 5)
    @queue.flush!
    assert_equal 5, @other_queue.length
  end

  def test_should_return_correct_queue_size
    populate_queue(@queue, 5)
    assert_equal 5, @queue.length
  end

  private

  def populate_and_ack_all_but_fail_one(queue = nil)
    queue ||= @queue
    populate_queue(queue, 5)
    SMQ::Message.find(:all, :conditions => ["queue = ?", queue.name]).each do |msg|
      msg.ack!
    end
    failure = SMQ::Message.find(:first)
    failure.fail
    failure.save!
  end

end
