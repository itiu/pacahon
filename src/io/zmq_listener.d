module io.zmq_listener;

import core.stdc.stdio;
import core.stdc.errno;
import core.stdc.string;
import core.stdc.stdlib;

import std.conv;
import std.stdio : writeln;
import std.datetime;
import std.concurrency;
import std.json;

import deimos.zmq.zmq;

import pacahon.context;
import pacahon.thread_context;
import pacahon.server;
import util.utils;

void zmq_thread(string thread_name, string props_file_name, int pos_in_listener_section)
{
	core.thread.Thread tr = core.thread.Thread.getThis();
	tr.name = thread_name;		
		
    //writeln("SPAWN: zmq listener");

    Context context = new PThreadContext(props_file_name, "zmq");

    string[ string ] params;
    JSONValue[] _listeners;
    _listeners = context.get_props().object[ "listeners" ].array;
    int         listener_section_count = 0;
    foreach (listener; _listeners)
    {
        listener_section_count++;
        if (listener_section_count == pos_in_listener_section)
        {
            foreach (key; listener.object.keys)
                params[ key ] = listener[ key ].str;
            break;
        }
    }

    core.thread.Thread.sleep(dur!("msecs")(100));
    void *ctx = zmq_init(1);

    ///  Socket to talk to clients
    void   *responder = zmq_socket(ctx, ZMQ_REP);
    string connect_to = params.get("point", null);
    zmq_bind(responder, cast(char *)connect_to);


    ubyte[] out_data;
    try
    {
        while (true)
        {
            ///  Wait for next request from client
            zmq_msg_t request;
            zmq_msg_init(&request);
            zmq_recvmsg(responder, &request, 0);

//        byte* data = cast(byte*)zmq_msg_data(&request);
            int data_length = cast(int) zmq_msg_size(&request);

            if (data_length > 0)
            {
                byte *data = cast(byte *) zmq_msg_data(&request);

                //get_message(data, data_length, null, out_data, context);

                zmq_msg_close(&request);

                ///  Send reply back to client
                zmq_msg_t reply;
//        zmq_msg_init_data(&reply, cast(byte*)out_data, out_data.length, null, null);

                zmq_msg_init_size(&reply, out_data.length);

                ///Slicing calls memcpy internally.
                (zmq_msg_data(&reply))[ 0..out_data.length ] = out_data[ 0..out_data.length ];
                zmq_sendmsg(responder, &reply, 0);
                zmq_msg_close(&reply);
            }
            else
            {
                zmq_msg_t reply;
                zmq_msg_init_size(&reply, 0);
                zmq_sendmsg(responder, &reply, 0);
                zmq_msg_close(&reply);
            }
        }
        ///  We never get here but if we did, this would be how we end
    }
    catch (Exception ex)
    {
    }
    //zmq_close(responder);
    //zmq_term(ctx);
}

