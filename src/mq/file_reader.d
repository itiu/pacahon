module mq.file_reader;

import core.stdc.stdio;
import core.stdc.errno;
import core.stdc.string;
import core.stdc.stdlib;
import std.conv;
import std.stdio : writeln;
import std.datetime;
import std.concurrency;
import std.json;
import std.file;

import pacahon.context;
import pacahon.thread_context;
import pacahon.server;
import util.utils;

void file_reader_thread(string props_file_name, Tid tid_xapian_indexer, Tid tid_ticket_manager, Tid tid_subject_manager, Tid tid_acl_manager, Tid tid_statistic_data_accumulator)
{
    writeln("SPAWN: file reader");
    JSONValue props;

    try
    {
        props = get_props("pacahon-properties.json");
    } catch (Exception ex1)
    {
        throw new Exception("ex! parse params:" ~ ex1.msg, ex1);
    }

    core.thread.Thread.sleep(dur!("msecs")(100));

    ubyte[] out_data;

    Context context = new ThreadContext(props, "file_reader", tid_xapian_indexer, tid_ticket_manager, tid_subject_manager, tid_acl_manager, tid_statistic_data_accumulator);

    auto    buf = cast(ubyte[]) read("msg.txt");
    while (true)
    {
        try
        {
            if (buf !is null && buf.length > 0)
            {
                get_message(cast(byte *)buf, cast(int)buf.length, null, out_data, context);
            }
        }
        catch (Exception ex)
        {
            core.thread.Thread.sleep(dur!("msecs")(100));
        }
    }
}

public class FileReadThread : core.thread.Thread
{
    ThreadContext resource;
    ubyte[]       buf;
    ubyte[]       out_data;
    Context       context;

    this(string props_file_name, Tid tid_xapian_indexer, Tid tid_ticket_manager, Tid tid_subject_manager, Tid tid_acl_manager, Tid tid_statistic_data_accumulator)
    {
        super(&run);

        JSONValue props;

        try
        {
            props = get_props("pacahon-properties.json");
        } catch (Exception ex1)
        {
            throw new Exception("ex! parse params:" ~ ex1.msg, ex1);
        }

        core.thread.Thread.sleep(dur!("msecs")(100));


        context = new ThreadContext(props, "file_reader", tid_xapian_indexer, tid_ticket_manager, tid_subject_manager, tid_acl_manager, tid_statistic_data_accumulator);

        buf = cast(ubyte[]) read("msg.txt");
    }

private:
    void run()
    {
        writeln("SPAWN: file reader");
        while (true)
        {
            try
            {
                if (buf !is null && buf.length > 0)
                {
                    get_message(cast(byte *)buf, cast(int)buf.length, null, out_data, context);
                }
            }
            catch (Exception ex)
            {
                core.thread.Thread.sleep(dur!("msecs")(100));
            }
        }
    }
}
