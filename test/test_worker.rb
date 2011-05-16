require 'helper'

class WorkerTest < Test::Unit::TestCase

  def setup
    @worker = SMQ::Worker.new("test_queue")
  end

  def teardown
    SMQ.flush_all_queues!
  end

  def test_new_worker_should_have_correctly_named_queue
    assert_equal "test_queue", @worker.queue.name
  end

  def test_can_init_worker_with_queue_instance
    worker = SMQ::Worker.new(@worker.queue)
    assert_instance_of SMQ::Queue, worker.queue
    assert_equal @worker.queue.name, worker.queue.name
  end

  def test_working_should_yield_a_message_when_one_is_available
    SMQ::Message.build("string", @worker.queue.name).save!
    yielded_msg = nil
    @worker.work_one_message { |m| yielded_msg = m }
    assert_instance_of SMQ::Message, yielded_msg
  end

  def test_working_should_return_message_locked_to_correct_worker
    SMQ::Message.build("string", @worker.queue.name).save!
    assert_equal @worker.work_one_message.locked_by, @worker.name
  end

  def test_working_should_return_nil_when_none_are_available
    assert_nil @worker.work_one_message
  end

  def test_working_an_empty_queue_until_empty_should_do_nothing
    block_calls = 0
    @worker.work(true) { block_calls += 1 }
    assert_equal 0, block_calls
  end

  def test_working_a_populated_queue_until_empty_should_work_all_jobs
    populate_queue(@worker.queue.name, 5)
    block_calls = 0
    @worker.work(true) { block_calls += 1 }
    assert_equal 5, block_calls
  end

  def test_working_continues_until_told_to_stop
    t = Thread.new { @worker.work }
    assert @worker.is_working?, "Not working"
    @worker.stop!
    sleep 2
    assert !@worker.is_working?, "Working and should have stopped"
  end

  def test_working_a_populated_queue_in_batches_should_work_all_batch_jobs
    @worker.batches = 2
    populate_queue(@worker.queue.name, 5)
    block_calls = 0
    @worker.work(true) { block_calls += 1 }
    assert_equal 2, block_calls
  end

end
