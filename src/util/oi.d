module util.oi;

private import std.json;
private import std.stdio;
private import std.concurrency;
private import std.conv;

private import mq.mq_client;
private import mq.rabbitmq_client;

private import util.logger;
private import util.sgraph;
private import util.cbor;
private import util.cbor8sgraph;

private import std.datetime;


logger log;
logger oi_msg;

static this()
{
    log    = new logger("pacahon", "log", "server");
    oi_msg = new logger("pacahon", "oi", "server");
}

class OI
{
    private string    _alias;
    private mq_client client;
    private           string[ string ] params;
    private string    _db_type;
    Tid               embedded_gateway;
    bool              is_embedded = false;

    this()
    {
    }

    public string get_alias()
    {
        return _alias;
    }

    public string get_db_type()
    {
        return _db_type;
    }

    int connect(string[ string ] _params)
    {
        writeln("OI: connect use params:", params.keys, " : ", params.values);
        params = _params;

        _alias = params.get("alias", null);
        string transport = params.get("transport", "zmq");

        _db_type = params.get("db-type", "");

        if (_db_type == "xapian")
        {
            is_embedded = true;
            return 0;
        }

        else if (transport == "rabbitmq")
            client = new rabbitmq_client();

        if (client !is null)
        {
            int code = client.connect_as_req(params);
            if (code == 0)
                log.trace_log_and_console("success connect to gateway: %s, transport:%s, params:%s", _alias, transport, params.values);
            else
            {
                log.trace_log_and_console("fail connect to gateway: %s, transport:%s, params:%s", _alias, transport, params.values);
                return -1;
            }
        }
        return -1;
    }

    void send(Subject graph)
    {
//		writeln ("@0 embedded_gateway=", embedded_gateway);
//		writeln ("@1 graph=", graph);

        if (is_embedded == true)
        {
//			writeln ("@2");
//			string doc_id = "doc_id";
//			string field = "FFFF1";
//			string val = "sdfgdsgsgddsgds";
//			string ff;
//			string vv;

//        StopWatch sw;
//        sw.start();

            //Subject[] metadata = graph.get_metadata ();

            // отправляем данные документа
            string data = encode_cbor (graph);
            std.concurrency.send(embedded_gateway, data);
/*
                // отправляем метаданные
        foreach (mm ; metadata)
        {
                if (mm !is null)
                {
                        string mmstr = mm.toBSON ();
                        std.concurrency.send (embedded_gateway, mmstr);
   //               writeln ("send metadata");
                        }
        }
 */
//			for (int i = 0; i < 100; i++)
//				ff ~= "," ~ field;

//			for (int i = 0; i < 100; i++)
//				vv ~= "," ~ val;


//        sw.stop();
//        long t = cast(long) sw.peek().usecs;

//        writeln ("#16 [µs]", t);

//			writeln ("@3");
            return;
        }
    }

    void send(string msg)
    {
        if (is_embedded == true)
        {
            std.concurrency.send(embedded_gateway, msg);
            oi_msg.trace_io(false, cast(byte *)msg, msg.length);
            return;
        }

        if (client is null)
            return;

        int  length = cast(uint)msg.length;
        char *data  = cast(char *)msg;

        if (*(data + length - 1) == ' ')
            *(data + length - 1) = 0;

        client.send(data, length, false);

        oi_msg.trace_io(false, cast(byte *)msg, msg.length);
    }

    void send(ubyte[] msg)
    {
        if (is_embedded == true)
        {
            std.concurrency.send(embedded_gateway, cast(immutable)msg);
            oi_msg.trace_io(false, cast(byte *)msg, msg.length);
            return;
        }

        if (client is null)
            return;

        int length = cast(uint)msg.length;
        //		char* data = cast(char*) msg;

        //		if(*(data + length - 1) == ' ')
        //		{
        //			*(data + length - 1) = 0;
        //			length --;
        //		}

        int qq = 1;
        while (msg[ length - qq ] == 0)
        {
            qq++;
        }

        if (qq > 0)
            length = length - qq + 2;

        client.send(cast(char *)msg, length, false);

        oi_msg.trace_io(false, cast(byte *)msg, length);
    }

    string reciev()
    {
        if (client is null)
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
