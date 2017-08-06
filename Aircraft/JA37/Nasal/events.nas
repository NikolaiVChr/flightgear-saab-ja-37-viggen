# events.nas - Generic objects for managing events
#
# Copyright (C) 2014 Anton Gomez Alvedro
#
# This program is free software; you can redistribute it and/or
# modify it under the terms of the GNU General Public License as
# published by the Free Software Foundation; either version 2 of the
# License, or (at your option) any later version.
#
# This program is distributed in the hope that it will be useful, but
# WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
# General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with this program; if not, write to the Free Software
# Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston, MA 02110-1301, USA.


##
# The EventDispatcher is a simple helper object that keeps a list of listeners
# and allows a calling entity to send an "event" object to all subscribers.
#
# It is intended to be used internally by modules that want to offer a
# subscription interface so other modules can receive notifications.
# For an example of how to use it this way, check Nasal/FailureMgr

var EventDispatcher = (func {

	var global_id = 0;
	var getid = func { global_id += 1 };

	return {
		new: func {
			var m = { parents: [EventDispatcher] };
			m._subscribers = {};
			return m;
		},

		notify: func(event) {
			foreach(var id; keys(me._subscribers))
				me._subscribers[id](event);
		},

		subscribe: func(callback) {
			assert(typeof(callback) == "func");

			var id = getid();
			me._subscribers[id] = callback;
			return id;
		},

		unsubscribe: func(id) {
			delete(me._subscribers, id);
		}
	};
})();


##
# Stores messages in a circular buffer that then can be retrieved at any point.
# Messages are time stamped when pushed into the buffer, and the time stamp is
# kept by the message.

var LogBuffer = {

	new: func (max_messages = 128, echo = 0) {
		assert(max_messages > 1, "come on, lets be serious..");

		var m = { parents: [LogBuffer] };
		m.echo = echo;
		m.max_messages = max_messages;
		m.buffer = setsize([], max_messages);
		m.full = m.wp = 0;

		return m;
	},

	push: func(message) {
		var stamp = getprop("/sim/time/gmt-string");
		if (me.echo) print(stamp, " ", message);

		me.buffer[me.wp] = { time: stamp, message: message };
		me.wp += 1;
		if (me.wp == me.max_messages) {
			me.wp = 0;
			me.full = 1;
		}
	},

	clear: func {
		me.full = me.wp = 0;
	},

	##
	# Returns a vector with all messages, starting with the oldest one.
	# Each vector entry is a hash with the format:
	#     { time: <timestamp_str>, message: <the message> }

	get_buffer: func {
		if (me.full)
			!me.wp ? me.buffer : me.buffer[me.wp:-1] ~ me.buffer[0:me.wp-1];
		elsif (me.wp == 0)
			[];
		else
			me.buffer[0:me.wp-1];
	}
};
