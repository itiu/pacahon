module util.oi;

private import std.json;
private import std.stdio;
private import mq.mq_client;
private import mq.zmq_point_to_poin_client;
private import mq.rabbitmq_client;
private import util.Logger;

Logger log;
Logger oi_msg;

static this()
{
	log = new Logger("pacahon", "log", "server");
	oi_msg = new Logger("pacahon", "oi", "server");
}

class OI
{
	private string _alias;
	private mq_client client;

	this()
	{
	}

	int connect(string[string] params)
	{
		_alias = params.get("alias", null);
		string transport = params.get("transport", "zmq");

		if(transport == "zmq")
			client = new zmq_point_to_poin_client();

		else if(transport == "rabbitmq")
			client = new rabbitmq_client();
		
		int code = client.connect_as_req(params);
		if (code == 0)
			log.trace_log_and_console("success connect to gateway: %s, transport:%s, params:%s", _alias, transport, params.values);
		else	
		{			
			log.trace_log_and_console("fail connect to gateway: %s, transport:%s, params:%s", _alias, transport, params.values);
			return -1;
		}
			
		return 0;	
	}

	void send(string msg)
	{
		if(client is null)
			return;

		int length = cast(uint) msg.length;
		char* data = cast(char*) msg;

		if(*(data + length - 1) == ' ')
			*(data + length - 1) = 0;

		client.send(data, length, false);

		oi_msg.trace_io(false, cast(byte*) msg, msg.length);
	}

	void send(ubyte[] msg)
	{
		if(client is null)
			return;

		int length = cast(uint) msg.length;
		//		char* data = cast(char*) msg;

		//		if(*(data + length - 1) == ' ')
		//		{
		//			*(data + length - 1) = 0;
		//			length --;
		//		}

		int qq = 1;
		while(msg[length - qq] == 0)
		{
			qq++;
		}

		if(qq > 0)
			length = length - qq + 2;

		client.send(cast(char*) msg, length, false);

		oi_msg.trace_io(false, cast(byte*) msg, length);
	}

	string reciev()
	{
		if(client is null)
			return null;

		string msg;
		//writeln ("#1");
		msg = client.reciev();
		//writeln ("#2 msg:", msg);
		
		//if (msg !is null)
		//	oi_msg.trace_io(true, cast(byte*) msg, msg.length);

		//writeln ("#3");
		
		return msg;
	}
}
