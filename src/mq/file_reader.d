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
import std.string;

import util.container;
import util.graph;
import util.cbor;
import util.utils;
import util.turtle_parser;
import util.json_ld.parser;

import pacahon.context;
import pacahon.thread_context;
import pacahon.server;
import pacahon.define;
import pacahon.know_predicates;

void file_reader_thread(string props_file_name, immutable string[] tids_names)
{	
    writeln("SPAWN: file reader");
	
    try
    {
        mkdir("core-onto");
    }
    catch (Exception ex)
    {
    }

    JSONValue props;

    try
    {
        props = get_props(props_file_name);
    } catch (Exception ex1)
    {
        throw new Exception("ex! parse params:" ~ ex1.msg, ex1);
    }

    core.thread.Thread.sleep(dur!("msecs")(100));

    ubyte[] out_data;

    Context context = new ThreadContext(props, "file_reader", tids_names);

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
            	Subject[] ss_list = parse_turtle_string(cast(char*)buf, cast(int)buf.length, context.get_prefix_map);
            	
            	writeln (context.get_prefix_map);
            	
            	bool[string] for_load;

            	foreach (ss; ss_list)
            	{
					string prefix = context.get_prefix_map.get (ss.subject, null); 
					if (prefix !is null)
					{
						writeln ("found prefix=", prefix);
						if (ss.isExsistsPredicate (rdf__type, owl__Ontology))
						{
							string version_onto = ss.getFirstLiteral (owl__versionInfo);
							writeln (prefix, ", version=", version_onto);
							
							// проверить какая версия данной отологии в хранилище
							writeln ("look in storage[", ss.subject, "]");
							Subject sss = context.get_subject (ss.subject);
							
							if (sss !is null)
							{
							Predicate aaa = sss.getPredicate (owl__versionInfo);
							if (aaa !is null)
							{
								if (aaa.isExistLiteral (version_onto))
								{
									writeln ("This version [", version_onto, "] onto[", prefix, "] already exist");
								}
								else
								{
									writeln ("1 This version [", version_onto, "] onto[", prefix, "] not exist in store");
									for_load[prefix] = true;									
									for_load[ss.subject] = true;									
								}
							}
							}
							else
							{
									writeln ("2 This version [", version_onto, "] onto[", prefix, "] not exist in store");
									for_load[prefix] = true;									
									for_load[ss.subject] = true;																	
							}							
						}
					}	
            	}
            	
            	writeln ("Onto for load:", for_load);
            	
            	foreach (ss; ss_list)
            	{
            		if (ss.isExsistsPredicate (rdf__type, rdfs__Class) || ss.isExsistsPredicate (rdf__type, rdf__Property))
            		{
            			long pos = indexOf (ss.subject, ":");
            			if (pos > 0)
            			{
            				string prefix = ss.subject[0..pos+1];
            				if (for_load.get(prefix, false) == true)
            				{
            					writeln (ss.subject, " 1 store! ");
            					context.store_subject (ss);
            				}
            			}
            		}
            		else if (for_load.get (ss.subject, false) == true)
            		{
            					writeln (ss.subject, " 2 store! ");
            					context.store_subject (ss);
            		}

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