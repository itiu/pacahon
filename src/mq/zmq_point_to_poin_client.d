module mq.zmq_point_to_poin_client;

private import core.thread;
private import core.stdc.stdio;
private import std.c.string;
private import std.stdio;
private import std.outbuffer;
private import std.datetime;
private import std.process;
private import std.conv;

private import bind.libzmq_header;
private import mq.mq_client;
private import util.logger;
private import pacahon.context;

alias void listener_result;

logger log;

static this()
{
	log = new logger("zmq", "log", null);
}

class zmq_point_to_poin_client: mq_client
{
	private string fail;
	private bool is_success_status = false;

	bool is_success()
	{
		return is_success_status;
	}

	string get_fail_msg()
	{
		return fail;
	}

	int count = 0;

	void* context = null;
	void* soc;

	bool need_resend_msg = false;

	void function(byte* txt, int size, mq_client from_client, ref ubyte[] out_data, Context context = null) message_acceptor;

	int connect_as_listener(string[string] params)
	{
		bind_to = params.get("point", null);
		return 0;
	}

	int connect_as_req(string[string] params)
	{
		string connect_to = params.get("point", null);

		if(connect_to !is null)
		{
			if(context is null)
				context = zmq_init(1);

			soc = zmq_socket(context, ZMQ_REQ);

			int rc = zmq_connect(soc, cast(char*) (connect_to ~ "\0"));
			if(rc != 0)
			{
				log.trace("error in zmq_connect: %s %s", connect_to, zmq_error2string(zmq_errno()));
				return -1;
			}

			is_success_status = true;
			return 0;
		}
		return -1;
	}

	string bind_to;

	this()
	{
	}

	~this()
	{
		//		log.trace("libzmq_client:destroy\n");

		//		log.trace("libzmq_client:#0\n");
		//		log.trace("libzmq_client:#a\n");
		//		if (soc_rep !is null)
		{
			//		log.trace("libzmq_client:#1\n");
			//		log.trace("libzmq_client:zmq_close, soc_rep=%p\n", soc_rep);
			//		zmq_close(soc_rep);
		}
		//		zmq_close(soc_rep);
		//		log.trace("libzmq_client:zmq_term\n");
		//		zmq_term(context);
	}

	void get_count(out int cnt)
	{
		cnt = count;
	}

	void set_callback(void function(byte* txt, int size, mq_client from_client, ref ubyte[] out_data, Context context = null) _message_acceptor)
	{
		message_acceptor = _message_acceptor;
	}

	int send(char* messagebody, int message_size, bool send_more)
	{
		zmq_msg_t msg;

		int rc = zmq_msg_init_size(&msg, message_size);
		if(rc != 0)
		{
			log.trace("error in zmq_msg_init_size: %s", zmq_error2string(zmq_errno()));
			return -1;
		}

		memcpy(zmq_msg_data(&msg), messagebody, message_size);

		int send_param = 0;

		if(send_more)
			send_param = ZMQ_SNDMORE;

		rc = zmq_sendmsg(soc, &msg, send_param);
		if(rc != 0)
		{
			log.trace("libzmq_client.send:zmq_send: {}\n", zmq_error2string(zmq_errno()));
			return -1;
		}

		need_resend_msg = false; // ответное сообщение было отправлено, снимем флажок о требовании отправки повторного сообщения

		rc = zmq_msg_close(&msg);
		if(rc != 0)
		{
			log.trace("error in zmq_msg_close: %s", zmq_error2string(zmq_errno()));
			return -1;
		}

		return 0;
	}

	string reciev()
	{
		string data = null;
		zmq_msg_t msg;
		int rc = zmq_msg_init(&msg);
		if(rc != 0)
		{
			log.trace("error in zmq_msg_init_size: %s", zmq_error2string(zmq_errno()));
			return null;
		}

		//StopWatch sw_c;

		rc = zmq_recvmsg(soc, &msg, 0);
		if(rc != 0)
		{
			rc = zmq_msg_close(&msg);
			log.trace("error in zmq_recv: %s", zmq_error2string(zmq_errno()));
			return null;
		}
		else
		{
		//sw_c.start();

			char* res = cast(char*) zmq_msg_data(&msg);
			size_t len = zmq_msg_size(&msg);
			data = cast(string) res[0 .. len];
		}

		data = data.dup;

		rc = zmq_msg_close(&msg);
		
		if(rc != 0)
		{
			log.trace("error in zmq_msg_close: %s", zmq_error2string(zmq_errno()));
			return null;
		}
		
		//sw_c.stop();		
		//writeln ("msg recv, time=", sw_c.peek().usecs);

		return data;
	}

	listener_result listener()
	{
		context = zmq_init(1);
		while(1)
		{
			soc = zmq_socket(context, ZMQ_REP);

			log.trace_log_and_console("libzmq_client: listen from client: %s", bind_to);
			int rc = zmq_bind(soc, cast(char*) (bind_to ~ "\0"));
			if(rc != 0)
			{
				log.trace_log_and_console("error in zmq_bind: %s", zmq_error2string(zmq_errno()));
				throw new Exception("error in zmq_bind: " ~ zmq_error2string(zmq_errno()));
			}

			while(1)
			{
				zmq_msg_t msg;

				if(need_resend_msg == true)
				{
					need_resend_msg = false;

					rc = zmq_msg_init_size(&msg, 1);
					if(rc != 0)
					{
						log.trace_log_and_console("error in zmq_msg_init_size: %s", zmq_error2string(zmq_errno()));
						break;
					}

					rc = zmq_sendmsg(soc, &msg, 0);
					if(rc != 0)
					{
						log.trace_log_and_console("error in zmq_msg_send: %s", zmq_error2string(zmq_errno()));
						zmq_msg_close(&msg);
						break;
					}

					rc = zmq_msg_close(&msg);
					if(rc != 0)
					{
						log.trace_log_and_console("error in zmq_msg_close: %s", zmq_error2string(zmq_errno()));
						zmq_msg_close(&msg);
						break;
					}
				}

				rc = zmq_msg_init(&msg);
				if(rc != 0)
				{
					log.trace_log_and_console("error in zmq_msg_init_size: %s", zmq_error2string(zmq_errno()));
					zmq_msg_close(&msg);
					break;
				}

				rc = zmq_recvmsg(soc, &msg, 0);
				if(rc != 0)
				{
					log.trace_log_and_console("listener:error in zmq_recv: %s", zmq_error2string(zmq_errno()));
					rc = zmq_msg_close(&msg);
					if(rc != 0)
						log.trace("error in zmq_msg_close: %s", zmq_error2string(zmq_errno()));
					break;
				}
				else
				{
					need_resend_msg = true;

					byte* data = cast(byte*) zmq_msg_data(&msg);
					size_t len = zmq_msg_size(&msg);
					char* result = null;
					try
					{
						count++;

						ubyte[] outbuff;

						message_acceptor(data, cast(uint) (len + 1), this, outbuff, null);

						if (outbuff.length < 2)
						{
							send(cast(char*) "FAIL", cast(uint) "FAIL".length, false);
						}
						else
						{	
							send(cast(char*) outbuff, cast(uint) outbuff.length, false);
						}
					}
					catch(Exception ex)
					{
						send(cast(char*) ("FAIL:" ~ ex.msg), cast(uint) ("FAIL:".length + ex.msg.length), false);
						log.trace_log_and_console("ex! user function callback, %s", ex.msg);
					}
				}

				rc = zmq_msg_close(&msg);
				if(rc != 0)
					log.trace_log_and_console("error in zmq_msg_close: %s", zmq_error2string(zmq_errno()));
			}
			//			zmq_unbind (soc_rep, cast(char*) (bind_to ~ "\0"));
			rc = zmq_close(soc);
			if(rc != 0)
				log.trace_log_and_console("error in zmq_close: %s", zmq_error2string(zmq_errno()));

			core.thread.Thread.sleep(dur!("seconds")(1));
		}
	}
	
/*	
	listener_result listener()
	{
    void* ctx = zmq_init(1);

    ///  Socket to talk to clients
    void* responder = zmq_socket(ctx, ZMQ_REP);
    zmq_bind(responder, cast(char*)bind_to);
	
    ubyte[] out_data;
    while(true)
    {
        ///  Wait for next request from client
        zmq_msg_t request;
        zmq_msg_init(&request);
        zmq_recvmsg(responder, &request, 0);

        byte* data = cast(byte*)zmq_msg_data(&request);
        int data_length = cast (int)zmq_msg_size (&request);
        
        message_acceptor(data, data_length, this, out_data, null);

        zmq_msg_close(&request);

        ///  Send reply back to client
        zmq_msg_t reply;
        zmq_msg_init_size(&reply, out_data.length);

        ///Slicing calls memcpy internally.
        (zmq_msg_data(&reply))[0..out_data.length] = out_data[0..out_data.length];
        zmq_sendmsg(responder, &reply, 0);
        zmq_msg_close(&reply);
    }
    ///  We never get here but if we did, this would be how we end
    zmq_close(responder);
    zmq_term(ctx);
	}	
*/	
}

string fromStringz(char* s)
{
	return cast(immutable) (s ? s[0 .. strlen(s)] : null);
}

public string zmq_error2string (int errnum)
{
    char* err_text = zmq_strerror (errnum);
    return cast (string) err_text[0..strlen (err_text)];
}
