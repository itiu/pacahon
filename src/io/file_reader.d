/**
 * загрузка индивидов в базу данных из *.ttl
 */
module io.file_reader;

import core.stdc.stdio, core.stdc.errno, core.stdc.string, core.stdc.stdlib;
import std.conv, std.datetime, std.concurrency, std.json, std.file, std.outbuffer, std.string, std.path, std.stdio : writeln;

import type;
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

/// процесс отслеживающий появление новых файлов и добавление их содержимого в базу данных
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

    SysTime[ string ] file_modification_time;
    string path = "./ontology";

    while (true)
    {
        Set!string files_to_load;

        if (exists(path ~ "/.load_sequence") == false)
        {
            auto oFiles = dirEntries(path, SpanMode.depth);

            if (trace_msg[ 29 ] == 1)
                log.trace("load directory sequence");

            foreach (o; oFiles)
            {
                if (extension(o.name) == ".ttl")
                {
                    if ((o.name in file_modification_time) !is null)
                    {
                        if (o.timeLastModified != file_modification_time[ o.name ])
                        {
                            if (trace_msg[ 29 ] == 1)
                                log.trace("look modifed file=%s", o.name);

                            file_modification_time[ o.name ] = o.timeLastModified;
                            files_to_load ~= o.name;
                        }
                    }
                    else
                    {
                        file_modification_time[ o.name ] = o.timeLastModified;
                        files_to_load ~= o.name;

                        if (trace_msg[ 29 ] == 1)
                            log.trace("look new file=%s", o.name);
                    }
                }
            }
        }
        else
        {
            if (trace_msg[ 29 ] == 1)
                log.trace("[%s] load custom sequence", name);

            auto     load_sequence = cast(char[]) read(path ~ "/.load_sequence");
            string[] els           = cast(string[])load_sequence.split('\n');
            foreach (el; els)
            {
                auto fn = el.strip();
                if (fn.length > 4)
                {
                    string file_name = path ~ "/" ~ fn;
                    //writeln ("@1 file_name=", file_name);

                    if ((file_name in file_modification_time) !is null)
                    {
                        //writeln ("@1.1 file_name=", file_name);
                        SysTime lst_mdf = timeLastModified(file_name);
                        if (lst_mdf != file_modification_time[ file_name ])
                        {
                            file_modification_time[ file_name ] = lst_mdf;
                            files_to_load ~= file_name;
                        }
                    }
                    else
                    {
                        //writeln ("@1.2 file_name=", file_name);
                        SysTime lst_mdf = timeLastModified(file_name);
                        file_modification_time[ file_name ] = lst_mdf;
                        files_to_load ~= file_name;
                    }
                }
            }
        }

        foreach (fn; files_to_load)
        {
            if (trace_msg[ 29 ] == 1)
                log.trace("load file=%s", fn);

            prepare_file(fn, context);
        }

        core.thread.Thread.sleep(dur!("seconds")(30));
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
                            Individual indv_in_storage = context.get_individual(null, ss.uri);
                            //writeln("#1 file_reader:store, ss=\n", ss);
                            if (indv_in_storage.getStatus() == ResultCode.OK)
                            {
                                //writeln("#2 file_reader:store, indv_in_storage=\n", indv_in_storage);
                                // обьеденить данные: ss = ss + indv_in_storage
                                ss = ss.apply(indv_in_storage);
                                //writeln("#3 file_reader:store, ss=\n", ss);
                            }
                            ResultCode res = context.put_individual(null, ss.uri, ss);
                            if (res != ResultCode.OK)
                                log.trace("individual =%s, not store, errcode =%s", ss.uri, text(res));                                
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

        context.wait_thread(P_MODULE.fulltext_indexer);                    

        //writeln ("file_reader::prepare_file end");
    }
    catch (Exception ex)
    {
        writeln("file_reader:Exception!", ex);
    }
}
