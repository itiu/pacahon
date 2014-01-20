module mq.nanomsg_listener;

import core.stdc.stdio;
import core.stdc.errno;
import core.stdc.string;
import core.stdc.stdlib;
import std.conv;
import std.stdio : writeln;
import std.datetime;
import std.concurrency;
import std.json;

import bind.nanomsg_header;

import pacahon.context;
import pacahon.thread_context;
import pacahon.server;
import util.utils;

void nanomsg_thread(string props_file_name, immutable string[] tids_names)
{
 	writeln("SPAWN: nanomsg listener");

    JSONValue props;

    try
    {
        props = get_props("pacahon-properties.json");
    } catch (Exception ex1)
    {
        throw new Exception("ex! parse params:" ~ ex1.msg, ex1);
    }

    core.thread.Thread.sleep(dur!("msecs")(100));

    char *IN_SOCKET_ADDRESS = cast(char *)"tcp://127.0.0.1:6699";
//    char* OUT_SOCKET_ADDRESS = cast(char*)"tcp://127.0.0.1:5534";

    int in_sock;

    in_sock = nn_socket(AF_SP, NN_REP);
    if (in_sock < 0)
    {
        fprintf(stderr, "Failed create socket: %s [%d] (%s:%d)\n", nn_err_strerror(errno), cast(int)errno);
        nn_err_abort();
    }

    int rc;

    rc = nn_bind(in_sock, IN_SOCKET_ADDRESS);
    if (rc < 0)
    {
        fprintf(stderr, "Failed bind to \"%s\": %s [%d] (%s:%d)\n", IN_SOCKET_ADDRESS, nn_err_strerror(errno), cast(int)errno);
        nn_err_abort();
    }

    int     buf_size = 4 * 1024;
    byte    *buf     = cast(byte *) malloc(buf_size);
    ubyte[] out_data;

    Context context = new ThreadContext(props, "nanomsg", tids_names);

    int     i = 0;
    while (true)
    {
//        test_send (out_ch, cast(char*)"123");
//        i++;
        rc = nn_recv(in_sock, buf, buf_size, 0);
//      writeln ("Ж5: rc=", rc);
        if (rc < 0)
        {
//          if (errno == 4)
            //nn_err_abort ();
//      writeln ("Ж6: errno=", errno);
//          fprintf (stderr, "Failed to recv: %s [%d] (%s:%d)\n", nn_err_strerror (errno), cast(int) errno);
        }
        else
        {
            int rc1;
//          string msg = cast(immutable)buf[0..rc];
            get_message(buf, rc, null, out_data, context);
//          writeln (msg);
            rc1 = nn_send(in_sock, cast(byte *)out_data, out_data.length, 0);
//      writeln ("Ж7: rc=", rc1, ", errno=", errno);
        }


        i++;
    }
}

