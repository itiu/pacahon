/**
 * загрузка индивидов в базу данных из *.ttl
 */
module io.file_reader;

import core.stdc.stdio, core.stdc.errno, core.stdc.string, core.stdc.stdlib;
import std.conv, std.datetime, std.concurrency, std.json, std.file, std.outbuffer, std.string, std.path, std.utf, std.stdio : writeln;

import type;
import util.container, util.cbor, util.utils, util.logger, util.raptor2individual;
import onto.individual, onto.resource;
import pacahon.context, pacahon.thread_context, pacahon.define, pacahon.know_predicates, pacahon.log_msg;

logger log;

static this()
{
    log = new logger("pacahon", "log", "file_reader");
}

/// процесс отслеживающий появление новых файлов и добавление их содержимого в базу данных
void file_reader_thread(P_MODULE name, string props_file_name, int checktime)
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

        Individual *[ string ][ string ] list_of_fln;

        foreach (fln; files_to_load)
        {
            if (trace_msg[ 29 ] == 1)
                log.trace("load file=%s", fln);

            log.trace("prepare_file %s", fln);

            list_of_fln[ fln ] = ttl2individuals(fln, context);
        }

        // set order
        Individual *[][] ordered_list = (Individual *[][]).init;

        // load index onto
        foreach (key, individuals; list_of_fln)
            if (individuals.get("vdi:", null) !is null)
                ordered_list ~= individuals.values;

        // load admin onto
        foreach (key, individuals; list_of_fln)
            if (individuals.get("v-a:", null) !is null)
                ordered_list ~= individuals.values;

        // load rdf onto
        foreach (key, individuals; list_of_fln)
            if (individuals.get("rdf:", null) !is null)
                ordered_list ~= individuals.values;

        // load rdfs onto
        foreach (key, individuals; list_of_fln)
            if (individuals.get("rdfs:", null) !is null)
                ordered_list ~= individuals.values;

        // load owl onto
        foreach (key, individuals; list_of_fln)
            if (individuals.get("owl:", null) !is null)
                ordered_list ~= individuals.values;

        // load other onto
        foreach (key, individuals; list_of_fln)
            if (individuals.get("v-a:", null) is null &&
                individuals.get("owl:", null) is null &&
                individuals.get("rdf:", null) is null &&
                individuals.get("rdfs:", null) is null &&
                individuals.get("vdi:", null) is null &&
                individuals.get("td:", null) is null)
                ordered_list ~= individuals.values;

        // load other test-data
        foreach (key, individuals; list_of_fln)
            if (individuals.get("td:", null) !is null)
                ordered_list ~= individuals.values;

        foreach (value; ordered_list)
        {
            prepare_list(value, context);
        }

        core.thread.Thread.sleep(dur!("seconds")(checktime));
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

        bool   is_load = false;

        string prefix;

        foreach (ss; ss_list)
        {
            //log.trace("ss=%s", *ss);
            //if (ss.uri[ $ - 1 ] == '#')
            //    ss.uri.length = ss.uri.length - 1;

            //if (trace_msg[ 31 ] == 1)
//                log.trace("prepare uri=%s", ss.uri);

            prefix = context.get_prefix_map.get(ss.uri, null);

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
                                is_load = true;
                                break;
                            }
                        }
                    }
                    else
                    {
                        is_load = true;
                        //writeln("@ 2 This version [", version_onto, "] onto[", prefix, "] not exist in store");
                        break;
                    }
                }
            }
        }
        if (is_load)
        {
            log.trace_log_and_console("Onto for load:%s", prefix);

            foreach (ss; ss_list)
            {
                if (ss.isExist(veda_schema__login, "veda"))
                {
                    //writeln("FOUND SYSTEM ACCOUNT = ", ss);
                    context.push_signal("43", ss.getFirstLiteral(veda_schema__password));
                }
                if (ss.isExist(rdf__type, owl__Ontology))
                {
                    prefix = context.get_prefix_map.get(ss.uri, null);
                    Resources ress = Resources.init;
                    ress ~= Resource(prefix);
                    ss.resources[ veda_schema__fullUrl ] = ress;
                }

                long pos_path_delimiter = indexOf(ss.uri, '/');

                if (pos_path_delimiter < 0)
                {
                    long pos = indexOf(ss.uri, ':');
                    if (pos >= 0)
                    {
                        prefix = ss.uri[ 0..pos + 1 ];

                        //if (for_load.get(prefix, false) == true)
                        {
                            Individual indv_in_storage = context.get_individual(null, ss.uri);
                            bool       apply           = false;
                            if (indv_in_storage.getStatus() == ResultCode.OK)
                            {
                                bool is_type_indv_in_storage = ("rdf:type" in indv_in_storage.resources) is null;
                                bool is_type_ss              = ("rdf:type" in ss.resources) is null;

                                if ((is_type_indv_in_storage == true && is_type_ss == false) ||
                                    (is_type_indv_in_storage == false && is_type_ss == true))
                                    apply = true;
                            }

                            if (apply)
                            {
                                // обьеденить данные: ss = ss + indv_in_storage
                                auto       ss1 = ss.apply(indv_in_storage);

                                ResultCode res = context.put_individual(null, ss.uri, ss1.repare_unique("rdf:type"), false);
                                if (trace_msg[ 33 ] == 1)
                                    log.trace("file_reader:apply, uri=%s %s", ss.uri, ss1);
                                if (res != ResultCode.OK)
                                    log.trace("individual =%s, not store, errcode =%s", ss1.uri, text(res));
                            }
                            else
                            {
                                ResultCode res = context.put_individual(null, ss.uri, (*ss).repare_unique("rdf:type"), false);
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
                        context.put_individual(null, ss.uri, (*ss).repare_unique("rdf:type"), false);
                    }
                }
            }

            Tid tid_search_manager = context.getTid(P_MODULE.fulltext_indexer);
            if (tid_search_manager != Tid.init)
                send(tid_search_manager, CMD.COMMIT, "");

            context.wait_thread(P_MODULE.fulltext_indexer);

            context.set_reload_signal_to_local_thread("search");
        }
        //context.reopen_ro_subject_storage_db ();
        //writeln ("file_reader::prepare_file end");
    }
    catch (Exception ex)
    {
        writeln("file_reader:Exception!", ex);
    }
}
