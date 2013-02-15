module pacahon.zmq_connection;

private import mq_client;
private import util.Logger;

Logger log;
Logger oi_msg;

static this()
{
	log = new Logger("pacahon", "log", "server");
	oi_msg = new Logger("pacahon", "oi", "server");
}

class ZmqConnection
{
	private string point;
	private void* context;
	private mq_client client;

	this(mq_client _client, string _point)
	{
		client = _client;
		point = _point;
	}

	public void check_connect()
	{
		if(context is null && point !is null)
		{
			log.trace("connect to %s", point);
			context = client.connect_as_req(point);
			log.trace("zmq context = %X", context);
		}
	}

	void send(string msg)
	{
		check_connect();

		int length = cast(uint)msg.length;
		char* data = cast(char*) msg;

		if(*(data + length - 1) == ' ')
			*(data + length - 1) = 0;

		client.send(context, data, length, false);

		oi_msg.trace_io(false, cast(byte*) msg, msg.length);
	}

	string reciev()
	{
		check_connect();

		string msg;
		msg = client.reciev(context);

		oi_msg.trace_io(true, cast(byte*) msg, msg.length);

		return msg;
	}
}
