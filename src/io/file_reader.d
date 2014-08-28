module io.file_reader;

import core.stdc.stdio, core.stdc.errno, core.stdc.string, core.stdc.stdlib;
import std.conv, std.datetime, std.concurrency, std.json, std.file, std.outbuffer, std.string, std.stdio : writeln;

import util.container;
import util.cbor;
import util.utils;
import util.turtle_parser;
import util.logger;

import onto.individual;
import onto.resource;

import pacahon.context;
import pacahon.thread_context;
import pacahon.define;
import pacahon.know_predicates;
import pacahon.log_msg;

logger log;

static this()
{
    log = new logger("pacahon", "log", "file_reader");
}

void file_reader_thread(P_MODULE name, string props_file_name)
{
    core.thread.Thread tr = core.thread.Thread.getThis();
    tr.name = std.conv.text(name);

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
            if ((o.name in prev_state_of_files) !is null)
            {
                if (o.timeLastModified != prev_state_of_files[ o.name ])
                {
                    if (trace_msg[ 29 ] == 1)
                        log.trace("look modifed file=%s", o.name);

                    prev_state_of_files[ o.name ] = o.timeLastModified;
                    files_to_load[ o.name ]       = true;
                }
            }
            else
            {
                prev_state_of_files[ o.name ] = o.timeLastModified;

                if (trace_msg[ 29 ] == 1)
                    log.trace("look new file=%s", o.name);

                files_to_load[ o.name ] = true;
            }
        }

        if (exists(path ~ "/.load_sequence") == false)
        {
            if (trace_msg[ 29 ] == 1)
                log.trace("load directory sequence");

            foreach (fn; files_to_load.keys)
            {
                if (trace_msg[ 29 ] == 1)
                    log.trace("load directory sequence, file=%s", fn);

                prepare_file(fn, context);
            }
        }
        else
        {
            if (trace_msg[ 29 ] == 1)
                log.trace("load custom sequence");

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
        if (trace_msg[ 30 ] == 1)
            log.trace("prepare_file %s", file_name);

        auto buf = cast(ubyte[]) read(file_name);

        if (buf !is null && buf.length > 0)
        {
            Individual[] ss_list = parse_turtle_string(cast(char *)buf, cast(int)buf.length, context.get_prefix_map);

            if (trace_msg[ 30 ] == 1)
                log.trace("ss_list.count=%d", ss_list.length);

            if (trace_msg[ 30 ] == 1)
                log.trace("prefix_map=%s", context.get_prefix_map);

            bool[ string ] for_load;

            foreach (ss; ss_list)
            {
                if (ss.uri[ $ - 1 ] == '#')
                    ss.uri.length = ss.uri.length - 1;

                if (trace_msg[ 31 ] == 1)
                    log.trace("prepare uri=%s", ss.uri);

                string prefix = context.get_prefix_map.get(ss.uri, null);

                if (prefix !is null)
                {
                    if (trace_msg[ 31 ] == 1)
                        log.trace("found prefix=%s ss=%s", prefix, ss);

                    if (ss.isExist(rdf__type, owl__Ontology))
                    {
                        string version_onto = ss.getFirstLiteral(owl__versionInfo);

                        if (trace_msg[ 32 ] == 1)
                            log.trace("%s, readed version=%s", prefix, version_onto);

                        // проверить какая версия данной онтологии в хранилище
                        //writeln("look in storage[", ss.uri, "]");
                        Individual sss = context.get_individual(null, ss.uri);

                        if (trace_msg[ 33 ] == 1)
                            log.trace("look in storage=%s, found=%s", ss.uri, sss);

                        if (sss.getStatus() == ResultCode.OK)
                        {
                            Resources aaa = sss.resources.get(owl__versionInfo, Resources.init);
                            if (aaa != Resources.init)
                            {
                                if (aaa.anyExist(version_onto))
                                {
                                    //writeln("@ This version [", version_onto, "] onto[", prefix, "] already exist");
                                }
                                else
                                {
                                    //writeln("@ 1 This version [", version_onto, "] onto[", prefix, "] not exist in store");
                                    for_load[ prefix ] = true;
                                    for_load[ ss.uri ] = true;
                                }
                            }
                        }
                        else
                        {
                            //writeln("@ 2 This version [", version_onto, "] onto[", prefix, "] not exist in store");
                            for_load[ prefix ] = true;
                            for_load[ ss.uri ] = true;
                        }
                    }
                }
            }

            if (for_load.length > 0)
                writeln("Onto for load:", for_load.keys);

            foreach (ss; ss_list)
            {
                if (ss.isExist(veda_schema__login, "veda"))
                {
                    writeln("FOUND SYSTEM ACCOUNT = ", ss);
                    context.push_signal("43", ss.getFirstLiteral(veda_schema__password));
                }

                long pos_path_delimiter = indexOf(ss.uri, '/');

                if (pos_path_delimiter < 0)
                {
                    long pos = indexOf(ss.uri, ':');
                    if (pos >= 0)
                    {
                        string prefix = ss.uri[ 0..pos + 1 ];
                        if (for_load.get(prefix, false) == true)
                        {
                            //writeln("#1 file_reader:store, ss=\n", ss);
                            context.put_individual(null, ss.uri, ss);
                        }
                    }
                }
                else
                {
                    if (for_load.get(ss.uri, false) == true)
                    {
                        //writeln("#2 file_reader:store, ss=\n", ss);
                        context.put_individual(null, ss.uri, ss);
                    }
                }
            }

            Tid tid_search_manager = context.getTid(P_MODULE.fulltext_indexer);
            if (tid_search_manager != Tid.init)
                send(tid_search_manager, CMD.COMMIT, "");
        }
        //writeln ("file_reader::prepare_file end");
    }
    catch (Exception ex)
    {
        writeln("file_reader:Exception!", ex);
    }
}
