require 'rubygems'
require 'test/unit'
begin; require 'redgreen'; rescue; end

$LOAD_PATH.unshift(File.dirname(__FILE__))
$LOAD_PATH.unshift(File.join(File.dirname(__FILE__), '..', 'lib'))
require 'smq'

ActiveRecord::Base.configurations = YAML.load_file(File.dirname(__FILE__) + '/database.yml')
ActiveRecord::Base.establish_connection 'test'

SMQ::load_schema!       # will check if table already exists
SMQ::flush_all_queues!  # clear out old test data

class Test::Unit::TestCase

  def populate_queue(queue, msgs = 5)
    msgs.times { |i| SMQ::Message.build(i, queue.to_s).save! }
  end

end
