module pacahon.zmq_connection;

private import mq_client;
private import trioplax.Logger;

Logger log;

static this()
{
	log = new Logger("pacahon", "log", "server");
}

class ZmqConnection
{
	string point;
	void* context;
	mq_client client;

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
		client.send(context, cast(char*) msg, msg.length, false);
	}

	string reciev()
	{
		return client.reciev(context);

	}
}
