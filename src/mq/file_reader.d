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
import std.outbuffer;

import pacahon.context;
import pacahon.thread_context;
import pacahon.server;
import pacahon.graph;
import pacahon.define;
import util.utils;
import util.turtle_parser;
import util.json_ld.parser;

void file_reader_thread(string props_file_name, Tid tid_xapian_indexer, Tid tid_ticket_manager, Tid tid_subject_manager, Tid tid_acl_manager, Tid tid_statistic_data_accumulator)
{
    try
    {
        mkdir("core-onto");
    }
    catch (Exception ex)
    {
    }

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

    SysTime[string] prev_state_of_files;

    while (true)
    {
    	auto oFiles = dirEntries("./core-onto","*.{ttl}", SpanMode.depth);
    	
    	foreach(o; oFiles)
    	{
    		if ((o.name in prev_state_of_files) !is null)
    		{
    			if (o.timeLastModified != prev_state_of_files[o.name])
    			{
    				writeln ("file is modifed [", o.name, "]");
    				prepare_file (o.name, context);
    				prev_state_of_files[o.name] = o.timeLastModified;
    			}	    		
    		}
    		else
    		{	
    			prev_state_of_files[o.name] = o.timeLastModified;
   				writeln ("new file [", o.name, "]");
   				prepare_file (o.name, context);
    		}    		
    	}	
        
        core.thread.Thread.sleep(dur!("seconds")(3));
    }
}

private void prepare_file (string file_name, Context context)
{
        try
        {
        	auto    buf = cast(ubyte[]) read(file_name);

            if (buf !is null && buf.length > 0)
            {
            	Subject[] ss_list = parse_turtle_string(cast(char*)buf, cast(int)buf.length);
            	
            	foreach (ss; ss_list)
            	{
/*            		writeln ("-------------------------------------------------------------------------------");

            		OutBuffer outbuff = new OutBuffer();
            		toJson_ld(ss, outbuff, true);            		
            		writeln (outbuff);
            		writeln ("-------------------------------------------------------------------------------");
*/
					string ss_as_bson = ss.toBSON();
					send(context.get_tid_search_manager, ss_as_bson);
						//get .get_tid_subject_manager, STORE, ss_as_bson, thisTid);
            	}
				send(context.get_tid_search_manager, "COMMIT");
            	//put(Subject message, Predicate sender, Ticket *ticket, Context context, out bool isOk, out string reason)            	
//                get_message(cast(byte *)buf, cast(int)buf.length, null, out_data, context);
            }
        }
        catch (Exception ex)
        {
        	writeln ("EX!", ex);
        }
	
}
/*
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
*/