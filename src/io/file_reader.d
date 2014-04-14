module io.file_reader;

import core.stdc.stdio, core.stdc.errno, core.stdc.string, core.stdc.stdlib;
import std.conv, std.datetime, std.concurrency, std.json, std.file, std.outbuffer, std.string, std.stdio : writeln;

import onto.sgraph;

import util.container;
import util.cbor;
import util.utils;
import util.turtle_parser;
import util.json_ld_parser;

import pacahon.context;
import pacahon.thread_context;
import pacahon.server;
import pacahon.define;
import pacahon.know_predicates;

void file_reader_thread(P_MODULE name, string props_file_name)
{
	core.thread.Thread tr = core.thread.Thread.getThis();
	tr.name = std.conv.text (name);	
		
    //writeln("SPAWN: file reader");

    try
    {
        mkdir("ontology");
    }
    catch (Exception ex)
    {
    }

    core.thread.Thread.sleep(dur!("msecs")(100));

    ubyte[] out_data;

    Context context = new PThreadContext(props_file_name, "file_reader");

    SysTime[ string ] prev_state_of_files;
    string path = "./ontology";

    while (true)
    {
        bool[ string ] files_to_load;
        auto oFiles = dirEntries(path, "*.{ttl}", SpanMode.depth);

        foreach (o; oFiles)
        {
//	        writeln ("@@ file:", o);
            if ((o.name in prev_state_of_files) !is null)
            {
                if (o.timeLastModified != prev_state_of_files[ o.name ])
                {
                    //writeln("file is modifed [", o.name, "]");
                    prev_state_of_files[ o.name ] = o.timeLastModified;
                    files_to_load[ o.name ]       = true;
                }
            }
            else
            {
                prev_state_of_files[ o.name ] = o.timeLastModified;
                //writeln("new file [", o.name, "]");
                files_to_load[ o.name ] = true;
            }
        }

        if (exists(path ~ "/.load_sequence") == false)
        {
            foreach (fn; files_to_load.keys)
            {
//              writeln ("@@ fn:", fn);
                prepare_file(fn, context);
            }
        }
        else
        {
            auto     load_sequence = cast(char[]) read(path ~ "/.load_sequence");
            string[] els           = cast(string[])load_sequence.split('\n');
            foreach (el; els)
            {
                auto fn = el.strip();
                if (fn.length > 4)
                {
                    if (files_to_load.get(path ~ "/" ~ fn, false) == true)
                    {
                        prepare_file(path ~ "/" ~ fn, context);
                    }
                }
            }
        }


        core.thread.Thread.sleep(dur!("seconds")(10));
    }
}

private void prepare_file(string file_name, Context context)
{
    // 1. читает файл, парсит индивидов, сравнивает owl:versionInfo с версией в хранилище, для всех rdf:type == owl:Ontology,
    //    запоминает несуществующие или отличающиеся версией, для последующей загрузки
    // 2. попутно находит системный аккаунт (veda)
    try
    {
        auto buf = cast(ubyte[]) read(file_name);

        if (buf !is null && buf.length > 0)
        {
            Subject[] ss_list = parse_turtle_string(cast(char *)buf, cast(int)buf.length, context.get_prefix_map);

            //writeln(context.get_prefix_map);

            bool[ string ] for_load;

            foreach (ss; ss_list)
            {
                string prefix = context.get_prefix_map.get(ss.subject, null);

                //						writeln ("found prefix=", prefix);
                if (prefix !is null)
                {
                    if (ss.isExsistsPredicate(rdf__type, owl__Ontology))
                    {
                        string version_onto = ss.getFirstLiteral(owl__versionInfo);
//                        writeln(prefix, ", version=", version_onto);

                        // проверить какая версия данной онтологии в хранилище
//                        writeln("look in storage[", ss.subject, "]");
                        Subject sss = context.get_subject(ss.subject);

                        if (sss !is null)
                        {
                            Predicate aaa = sss.getPredicate(owl__versionInfo);
                            if (aaa !is null)
                            {
                                if (aaa.isExistLiteral(version_onto))
                                {
//                                    writeln("This version [", version_onto, "] onto[", prefix, "] already exist");
                                }
                                else
                                {
//                                    writeln("1 This version [", version_onto, "] onto[", prefix, "] not exist in store");
                                    for_load[ prefix ]     = true;
                                    for_load[ ss.subject ] = true;
                                }
                            }
                        }
                        else
                        {
//                            writeln("2 This version [", version_onto, "] onto[", prefix, "] not exist in store");
                            for_load[ prefix ]     = true;
                            for_load[ ss.subject ] = true;
                        }
                    }
                }
            }

            if (for_load.length > 0)
                writeln("Onto for load:", for_load);

            foreach (ss; ss_list)
            {
                if (ss.isExsistsPredicate(veda_schema__login, "veda"))
                {
                    writeln("FOUND SYSTEM ACCOUNT = ", ss);
                    context.push_signal("43", ss.getFirstLiteral(veda_schema__password));
                }

                long pos_path_delimiter = indexOf(ss.subject, '/');

                if (pos_path_delimiter < 0)
                {
                    long pos = indexOf(ss.subject, ':');
                    if (pos >= 0)
                    {
                        string prefix = ss.subject[ 0..pos + 1 ];
                        if (for_load.get(prefix, false) == true)
                        {
                            //writeln("#1 file_reader:store, ss=\n", ss);
                            context.store_subject(ss);
                        }
                    }
                }
                else
                {
                    if (for_load.get(ss.subject, false) == true)
                    {
                        // writeln("#2 file_reader:store, ss=\n", ss);
                        context.store_subject(ss);
                    }
                }
            }

            Tid tid_search_manager = context.getTid(P_MODULE.fulltext_indexer);
            if (tid_search_manager != Tid.init)
                send(tid_search_manager, CMD.COMMIT, "");
            //put(Subject message, Predicate sender, Ticket *ticket, Context context, out bool isOk, out string reason)
//                get_message(cast(byte *)buf, cast(int)buf.length, null, out_data, context);
        }
    }
    catch (Exception ex)
    {
        writeln("EX!", ex);
    }
}
