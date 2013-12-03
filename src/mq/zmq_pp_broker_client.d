module mq.zmq_pp_broker_client;

private import core.stdc.stdlib;
private import core.thread;
private import core.runtime;
private import std.c.string;
private import std.stdio;
private import std.process;
private import std.conv;

version (linux) import std.c.linux.linux;

private import std.datetime;

private import bind.libzmq_header;
private import bind.libczmq_header;

private import util.Logger;

private import mq.mq_client;

private import std.outbuffer;

private import core.stdc.stdio;
private import std.uuid;
private import pacahon.context;

alias void listener_result;

static int ZMQ_POLL_MSEC = 1;

const PPP_HEARTBEAT_LIVENESS = 5; //  		3-5 is reasonable
const PPP_HEARTBEAT_INTERVAL = 1000 * 10; //  	msecs
const PPP_INTERVAL_RECONNECT_INIT = 1000; //  		Initial reconnect
const PPP_INTERVAL_RECONNECT_MAX = 32000; //  		After exponential backoff
const PPP_HEARTBEAT = "H";

// поведение:
//	all - выполняет все операции
//  writer - только операции записи
//  reader - только операции чтения
//  logger - ничего не выполняет а только логгирует операции, параметры logging не учитываются 		

const PPP_BEHAVIOR_ALL = "RA";
const PPP_BEHAVIOR_WRITER = "RW";
const PPP_BEHAVIOR_READER = "RR";
const PPP_BEHAVIOR_LOGGER = "RL";

static string PPP_READY;

// Called upon a signal from Linux
extern (C) public void sighandler0(int sig) nothrow @system
{
	printf("signal %d caught...\n", sig);
	try
	{
	    system ("kill -kill " ~ text (getpid()));
	    //Runtime.terminate();
	}
	catch (Exception ex)
	{
	}
}

class zmq_pp_broker_client: mq_client
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
	
	char[] identity;
	zctx_t* ctx;
	void* worker;

	int count_h = 0;

	size_t liveness;
	size_t interval;

	ulong heartbeat_at;
	char* bind_to;

	void function(byte* txt, int size, mq_client from_client, ref ubyte[] out_data, Context context = null) message_acceptor;

	int count = 0;
	bool isSend = false;

	this()
	{
	}

	~this()
	{
		zctx_destroy(&ctx);
		printf("zmq_pp_broker_client destroy\n");
	}

	int connect_as_listener(string[string] params)
	{
		string _bind_to = params.get ("bind_to", null);
		string _behavior = params.get ("behavior", null); 
		
		PPP_READY = PPP_BEHAVIOR_ALL;

		if(_behavior == "all")
			PPP_READY = PPP_BEHAVIOR_ALL;
		else if(_behavior == "writer")
			PPP_READY = PPP_BEHAVIOR_WRITER;
		else if(_behavior == "reader")
			PPP_READY = PPP_BEHAVIOR_READER;
		else if(_behavior == "logger")
			PPP_READY = PPP_BEHAVIOR_LOGGER;

		bind_to = cast(char*) (_bind_to);// ~ "\0");
		printf("worker\n");

		ctx = zctx_new();
		worker = s_worker_socket(ctx, bind_to);

		//  If liveness hits zero, queue is considered disconnected
		liveness = PPP_HEARTBEAT_LIVENESS;
		interval = PPP_INTERVAL_RECONNECT_INIT;

		//  Send out heartbeats at regular intervals
		heartbeat_at = zclock_time() + PPP_HEARTBEAT_INTERVAL;
		
		is_success_status = true;
		return 0;
	}
	
	int connect_as_req(string[string] params)
	{
		return -1;
	}

	// set callback function for listener ()
	void set_callback(void function(byte* txt, int size, mq_client from_client, ref ubyte[] out_data, Context context = null) _message_acceptor)
	{
		message_acceptor = _message_acceptor;
	}
 
	void get_count(out int cnt)
	{
		cnt = count;
	}

	// in thread listens to the queue and calls _message_acceptor
	listener_result listener()
	{
		version (linux) 
		{
		    // установим обработчик сигналов прерывания процесса
		    signal(SIGABRT, &sighandler0);
		    signal(SIGTERM, &sighandler0);
		    signal(SIGQUIT, &sighandler0);
		    signal(SIGINT, &sighandler0);
		}	


		while(1)
		{
			//			StopWatch sw;
			zmq_pollitem_t items[] = new zmq_pollitem_t[1];

			items[0].socket = worker;
			items[0].fd = 0;
			items[0].events = io_multiplexing.ZMQ_POLLIN;
			items[0].revents = 0;

			int rc = zmq_poll(cast(zmq_pollitem_t*) items, 1, PPP_HEARTBEAT_INTERVAL * ZMQ_POLL_MSEC);
			if(rc == -1)
			{
			//	break; //  Interrupted
			}

			//        printf("items [0].revents = %d\n", items [0].revents);
			if(items[0].revents & io_multiplexing.ZMQ_POLLIN)
			{
				//	    		sw.start();

				//  Get message
				//  - 3-part envelope + content -> request
				//  - 1-part "HEARTBEAT" -> heartbeat            
				zmsg_t* msg = zmsg_recv(worker);

				if(!msg)
					break; //  Interrupted

				int size_msg = cast(uint)zmsg_size(msg);
				//				   printf("message size=%d\n", size_msg);

				if(size_msg == 3)
				{
					//					printf("I: recieve task\n");

					zframe_t* frame = zmsg_last(msg);
					byte* msg_body = zframe_data(frame);
					int size = cast(uint)zframe_size(frame);

					isSend = false;
					// обработка принятого сообщения и отправка ответа

					//					printf("zmq_pp_broker_client #1\n");
					count++;

					ubyte[] outbuff;

					//		        		sw.stop();
					//		        		printf ("(1):%d\n", sw.peek().usecs);

					message_acceptor(msg_body, size, this, outbuff);

					//			sw.reset ();
					//	    		sw.start();
					//					printf("zmq_pp_broker_client #2\n");

					//					if (isSend == false)
					//					{
					//						возможно потребуется обработка такой ситуации
					//					}

					//					zclock_sleep(50);
					zframe_reset(frame, cast(char*) outbuff, outbuff.length);

					zmsg_send(&msg, worker);
					//		zstr_send (worker, "safsfsd");

					liveness = PPP_HEARTBEAT_LIVENESS;

					//				Thread.getThis().sleep(100_000);

					//					if(zctx_interrupted)
					//						break;
					//					zmsg_destroy(&msg);

				} else if(size_msg == 1)
				{
				    //printf ("I'm recieve message size = 1");
					zframe_t* frame = zmsg_first(msg);
					char* msg_body = cast(char*) zframe_data(frame);
					if(strncmp(msg_body, cast(char*) PPP_HEARTBEAT, PPP_HEARTBEAT.length) == 0)
					{
						printf ("I: recieve HEARTBEAT\n");
						liveness = PPP_HEARTBEAT_LIVENESS;
					} else
					{
						printf("E: ( %s invalid message)\n", cast(char*) identity);
						zmsg_dump(msg);
					}
					zmsg_destroy(&msg);
				}
				interval = PPP_INTERVAL_RECONNECT_INIT;
			} else
			{
				if(liveness < PPP_HEARTBEAT_LIVENESS)
					printf("!!!! --liveness = %d\n", liveness);
				if(--liveness == 0)
				{
					printf("W: heartbeat failure, can't reach queue\n");
					printf("W: reconnecting in %zd msec...\n", interval);
					Thread.sleep(dur!("msecs")(interval));

					if(interval < PPP_INTERVAL_RECONNECT_MAX)
					{
						interval *= 2;
					}
					else
					{
					    system ("kill -kill " ~ text (getpid()));
					}

					zsocket_destroy(ctx, worker);
					worker = s_worker_socket(ctx, bind_to);
					liveness = PPP_HEARTBEAT_LIVENESS;
				}
			}

			//  Send heartbeat to broker if it's time
			if(zclock_time() > heartbeat_at)
			{
				heartbeat_at = zclock_time() + PPP_HEARTBEAT_INTERVAL;
				//          printf ("I: worker heartbeat\n");
				zframe_t* frame = zframe_new(cast(char*) PPP_HEARTBEAT, PPP_HEARTBEAT.length);
				zframe_send(&frame, worker, 0);
				count_h++;
				//				printf ("count_h=%d\n", count_h);
			}

			//		        		sw.stop();
			//		        		printf ("(2):%d\n", sw.peek().usecs);
			//			if(zctx_interrupted)
			//				break;
		}

		system ("kill -kill " ~ text (getpid()));

		return;
	}

	//	 Set simple random printable identity on socket	
	private static char[] s_set_id(void* socket)
	{
		UUID uid = randomUUID();
//		Twister rnd;
//		rnd.seed;
//		UuidGen rndUuid = new RandomGen!(Twister)(rnd);
//		Uuid generated = rndUuid.next;
		string id = uid.toString();

		zmq_setsockopt(socket, soc_opt.ZMQ_IDENTITY, cast(char*)id, cast(int)id.length);

		return cast(char[])id;
	}

	private void* s_worker_socket(zctx_t* ctx, char* point)
	{
		void* soc_worker = zsocket_new(ctx, soc_type.ZMQ_DEALER);

		//		void* context = zmq_init(1);
		//		void* soc_worker = zmq_socket(context, soc_type.ZMQ_DEALER);

		//zmq_socket(context, soc_type.ZMQ_XREQ);

		if(soc_worker is null)
		{
			printf("error in zsocket_new, socket not created\n");
			return null;
		}

		printf("soc_worker %x\n", soc_worker);

		//  Set random identity to make tracing easier
		identity = s_set_id(soc_worker);

		printf("connect to: %s\n", point);
		int rc = zmq_connect(soc_worker, point);
		if(rc != 0)
		{
			printf("error in zmq_connect: %s\n", zmq_strerror(zmq_errno()));
			return null;
		}
		printf("ok\n");

		//  Configure socket to not wait at close time
		int linger = 0;
		zmq_setsockopt(soc_worker, soc_opt.ZMQ_LINGER, &linger, linger.sizeof);

		//  Tell queue we're ready for work
		writeln("I: worker ready: [", identity, "] ", PPP_READY);
		zframe_t* frame = zframe_new(cast(char*) PPP_READY, PPP_READY.length);
		zframe_send(&frame, soc_worker, 0);

		return soc_worker;
	}

	///////////////////////////////////////////////////////////////////////
	int send(char* messagebody, int message_size, bool send_more)
	{
		return -1;
	}

	string reciev()
	{
		return null;
	}

}