# Simple Message Queue (SMQ)

SMQ is a database-backed, JSON-based message queue and worker platform.

## Description

SMQ uses ActiveRecord to provide a database-agnositc, JSON-based [message queue](http://en.wikipedia.org/wiki/Message_queue) and worker platform; this is not to be confused with [job queues](http://en.wikipedia.org/wiki/Job_queue) such as [Resque](http://github.com/defunkt/resque) or [Delayed::Job](http://github.com/tobi/delayed_job).

Other simple message queue systems exist, but these generally either use Marshal'd ruby objects which are not transferable to other platforms, or are run as a separate server daemon.  SMQ uses a simple database table for persisting message queues and JSON encoding for message payloads to enable use cross-platform.

## Installation

SMQ is provided as a gem courtesy of Gemcutter:

	gem install smq

Once you've established your ActiveRecord connection, you'll need to initialise the (single) database table:

	SMQ.load_schema!

## Queues

Creating a queue is as simple as:

	queue = SMQ::Queue.new("queue_name")

A "queue" doesn't exist as a persisted entity: it's effectively just a tag applied to a message; pushing a message onto a queue simply saves the Message with the queue name assigned.

## Adding Messages to a Queue

A message's payload can be any data structure that can be serialised to JSON.  There are three ways that a message can be added to a queue (here we're assuming that `msg_data` already exists):

	queue.enqueue(msg_data)

	# or

	queue.push(SMQ::Message.build(msg_data))

	# or

	SMQ::Message.build(msg_data, "queue_name").save

The first two methods are effectively simplified abstractions of the third.  Note that a single message can only be added to one queue; to push to multiple queues, additional instances of the message must be created.

### Non-Ruby Messages

Adding to a queue from outside a ruby environment is as simple as `INSERT`ing a JSON-encoded packet into the queue table:

	INSERT INTO smq_messages (queue, payload, created_at) VALUES (
		'queue_name',
		'{"json":"encoded stuff"}',
		NOW()
	)

## Workers

A worker is an instance of `SMQ::Worker` bound to a single named queue.  The `Worker#work` method takes care of reserving `Message`s and then passing them back to the given block:

	SMQ::Worker.new("queue_name").work do |msg|
	  puts msg.data.inspect
	  msg.ack!
	end

When a worker has finished with a `Message`, it should either call `Message#ack!` to acknowledge receipt of that message, or `Message#fail` followed by `Message#save` to mark the message as failed.  In addition, if a message should fail for a transient reason, it can be pushed back into the queue by calling `Message#retry!`.  A message will be retried up to 5 times before automatically being marked as failed.

`Worker#work` takes a single optional argument (in addition to the callback block): `until_empty`.  If `true`, the worker will stop when the queue is empty (but see detail on locking below); if `false` the worker will continue to look for new jobs indefinitely (or until `Worker#stop!` is called), waiting 1 second between queue polls.

### Locking Strategy

To facilitate the locking ("delivery") of individual messages, the following strategy is used:

1. Find the next 5 messages in the queue;
2. Randomise these messages;
3. Attempt to `UPDATE` each message based on the message ID, lock status and last updated stamp;
4. When the `UPDATE` returns a row change count of 1, that message has been locked and can be passed off to be processed;
5. If a lock isn't aquired for any of the 5 messages, either wait for 1 second and then start the process again or, if `until_empty` is `true`, end the processing loop and stop the worker.

The effect of this is that, although multiple workers can be employed on a single queue, the increase in throughput is not linear as may be expected.  In fact, if you increase the number of workers on queue past 5, throughput may actually diminish due to the extra time spent attempting to aquire a message lock.

This process, although heavy on `SELECT`s, results in a minimum of table locking which would actually slow the lock process down.  For example, by using an `UPDATE` with a `LIMIT` of `1` when the queue size is more than a couple of hundred results in a noticible slow down in lock acquisition.

These limitations are deemed acceptable due to the simple nature of this queueing system.

### Workaround to Locking Limitations

There is a workaround to the implicit limit of 5 workers per queue, which is to use the "batching" facility.  This works by splitting up the messages by the [modulo](http://en.wikipedia.org/wiki/Modulo_operation) of the ID; in effect this means you can then run up to 5 workers per batch:

	SMQ::Worker.new("queue_name", total_batches, this_batch).work do |msg|
	  puts msg.data.inspect
	  msg.ack!
	end

## Licensing and Attribution

SMQ is released under the MIT license as detailed in the LICENSE file that should be distributed with this library; the source code is [freely available](http://github.com/timblair/smq).

SMQ was developed by [Tim Blair](http://tim.bla.ir/) during work on [White Label Dating](http://www.whitelabeldating.com/), while employed by [Global Personals Ltd](http://www.globalpersonals.co.uk).  Global Personals Ltd have kindly agreed to the extraction and release of this software under the license terms above.
