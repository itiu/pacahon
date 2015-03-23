/**
 * загрузка индивидов в базу данных из *.ttl
 */
module io.file_reader;

import core.stdc.stdio, core.stdc.errno, core.stdc.string, core.stdc.stdlib;
import std.conv, std.datetime, std.concurrency, std.json, std.file, std.outbuffer, std.string, std.path, std.utf, std.stdio : writeln;

import type;
import util.container;
import util.cbor;
import util.utils;
import util.logger;
import util.raptor2individual;

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

        Individual *[ string ][ string ] list_of_fn;

        foreach (fn; files_to_load)
        {
            if (trace_msg[ 29 ] == 1)
                log.trace("load file=%s", fn);

            log.trace("prepare_file %s", fn);

            list_of_fn[ fn ] = ttl2individuals(fn, context);
        }

        // load admin onto
        foreach (key, value; list_of_fn)
        {
            Individual *[ string ] individuals = value;

            if (individuals.get("v-a:", null) !is null)
                prepare_list(individuals.values, context);
        }

        // load other onto
        foreach (key, value; list_of_fn)
        {
            Individual *[ string ] individuals = value;

            if (individuals.get("v-a:", null) is null)
                prepare_list(individuals.values, context);
        }


        core.thread.Thread.sleep(dur!("seconds")(30));
    }
}

private void prepare_list(Individual *[] ss_list, Context context)
{
    // 1. сравнивает owl:versionInfo с версией в хранилище, для всех rdf:type == owl:Ontology,
    //    запоминает несуществующие или отличающиеся версией, для последующей загрузки
    // 2. попутно находит системный аккаунт (veda)
    try
    {
        if (trace_msg[ 30 ] == 1)
            log.trace("ss_list.count=%d", ss_list.length);

        if (trace_msg[ 30 ] == 1)
            log.trace("prefix_map=%s", context.get_prefix_map);

        bool[ string ] for_load;

        foreach (ss; ss_list)
        {
            //log.trace("ss=%s", *ss);
            //if (ss.uri[ $ - 1 ] == '#')
            //    ss.uri.length = ss.uri.length - 1;

            //if (trace_msg[ 31 ] == 1)
//                log.trace("prepare uri=%s", ss.uri);

            string prefix = context.get_prefix_map.get(ss.uri, null);

            if (prefix !is null)
            {
                if (trace_msg[ 31 ] == 1)
                    log.trace("found prefix=%s ss=%s", prefix, *ss);

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
        {
            log.trace_log_and_console("Onto for load:%s", for_load.keys);
        }

        foreach (ss; ss_list)
        {        	
            if (ss.isExist(veda_schema__login, "veda"))
            {
                //writeln("FOUND SYSTEM ACCOUNT = ", ss);
                context.push_signal("43", ss.getFirstLiteral(veda_schema__password));
            }
            if (ss.isExist(rdf__type, owl__Ontology))
            {
                string    prefix = context.get_prefix_map.get(ss.uri, null);
                Resources ress   = Resources.init;
                ress ~= Resource(prefix);
                ss.resources[ veda_schema__fullUrl ] = ress;
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

                        //writeln("#1 file_reader:store, ss=\n", *ss);
                        if (indv_in_storage.getStatus() == ResultCode.OK)
                        {
                            //writeln("#2 file_reader:store, indv_in_storage=\n", indv_in_storage);
                            // обьеденить данные: ss = ss + indv_in_storage
                            auto ss1 = ss.apply(indv_in_storage);
                            //writeln("#3 file_reader:store, ss=\n", ss);
                            
                            ResultCode res = context.put_individual(null, ss.uri, ss1.repare_unique ("rdf:type"), false);
                            if (trace_msg[ 33 ] == 1)
                                log.trace("file_reader:apply, uri=%s %s", ss.uri, ss1);
                            if (res != ResultCode.OK)
                                log.trace("individual =%s, not store, errcode =%s", ss1.uri, text(res));
                        }
                        else
                        {
                            ResultCode res = context.put_individual(null, ss.uri, (*ss).repare_unique ("rdf:type"), false);
                            if (trace_msg[ 33 ] == 1)
                                log.trace("file_reader:store, uri=%s %s", ss.uri, *ss);
                            if (res != ResultCode.OK)
                                log.trace("individual =%s, not store, errcode =%s", ss.uri, text(res));
                        }
                    }
                }
            }
            else
            {
                //if (for_load.get(ss.uri, false) == true)
                {
                    if (trace_msg[ 33 ] == 1)
                        log.trace("file_reader:store, uri=%s %s", ss.uri, *ss);
                    context.put_individual(null, ss.uri, (*ss).repare_unique ("rdf:type"), false);
                }
            }
        }

        context.wait_thread(P_MODULE.fulltext_indexer);

        Tid tid_search_manager = context.getTid(P_MODULE.fulltext_indexer);
        if (tid_search_manager != Tid.init)
            send(tid_search_manager, CMD.COMMIT, "");

        context.set_reload_signal_to_local_thread("search");

        //writeln ("file_reader::prepare_file end");
    }
    catch (Exception ex)
    {
        writeln("file_reader:Exception!", ex);
    }
}
