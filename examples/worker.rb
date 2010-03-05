require 'rubygems'
require 'smq'

ActiveRecord::Base.configurations = YAML.load_file(File.dirname(__FILE__) + '/database.yml')
ActiveRecord::Base.establish_connection 'development'

SMQ::load_schema!

worker = SMQ::Worker.new("queue_name")
100.times { |i| worker.queue.enqueue(i+1) }

count = 0
worker.work(true) do |msg|
  count += 1
  puts msg.inspect
  msg.ack!
end

puts "Handled: #{count}"
