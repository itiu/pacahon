module pacahon.command_io;

private import core.stdc.stdio, core.stdc.stdlib;
private import std.concurrency, std.c.string, std.string, std.conv, std.datetime, std.stdio, std.outbuffer, std.datetime, std.base64,
               std.digest.sha;

private import onto.sgraph;

private import util.logger;
private import util.utils;
private import util.json_ld_parser;
private import util.cbor;

private import pacahon.know_predicates;
private import pacahon.log_msg;
private import pacahon.context;
private import pacahon.define;

logger log;

static this()
{
    log = new logger("pacahon", "log", "command-io");
}

/*
 * комманда добавления / изменения фактов в хранилище
 * TODO !в данный момент обрабатывает только одноуровневые графы
 */
Subject put(Subject message, Predicate sender, Ticket *ticket, Context context, out bool isOk, out string reason)
{
    if (trace_msg[ 31 ] == 1)
        log.trace("command put");

    isOk   = false;
    reason = "добавление фактов не возможно";

    Subject   res;

    Predicate args = message.getPredicate(msg__args);

    if (trace_msg[ 32 ] == 1)
        log.trace("command put, args.count_objects=%d ", args.count_objects);

    foreach (arg; args.getObjects)
    {
        Subject[] graphs_on_put = null;

        try
        {
            if (arg.type == OBJECT_TYPE.LINK_CLUSTER)
            {
                graphs_on_put = arg.cluster.data;
            }
            else if (arg.type == OBJECT_TYPE.LINK_SUBJECT)
            {
                graphs_on_put      = new Subject[ 1 ];
                graphs_on_put[ 0 ] = arg.subject;
            }
        } catch (Exception ex)
        {
            log.trace("cannot parse arg message: ex %s", ex.msg);
        }

        if (trace_msg[ 34 ] == 1)
            log.trace("arguments has been read");

        if (graphs_on_put is null)
        {
            reason = "в сообщении нет фактов которые следует поместить в хранилище";
        }

        store_graphs(graphs_on_put, ticket, context, isOk, reason);

        if (trace_msg[ 37 ] == 1)
            log.trace("command put is finish");
    }

    return res;
}

public void store_graphs(Subject[] graphs_on_put, Ticket *ticket, Context context, out bool isOk, out string reason,
                         bool prepareEvents = true)
{
    foreach (graph; graphs_on_put)
    {
        Predicate type = graph.getPredicate(rdf__type);

        if (type !is null && ((rdf__Statement in type.objects_of_value) is null))
        {
            if (auth__Authenticated in type.objects_of_value)
            {
                writeln("!1 graph=", graph);
                Predicate acr = graph.getPredicate(auth__credential);

                Objectz   oo = acr.getObjects()[ 0 ];

                // это добавление пользовательской учетки
                string credential_64 = oo.literal;

                // сделаем хэш из пароля и сохраним
                ubyte[] credential = Base64.decode(credential_64);
                ubyte[ 20 ] hash = sha1Of(credential);
                credential_64    = Base64.encode(hash);

                oo.literal = credential_64;
                writeln("!6 graph=", graph);
            }

            if (trace_msg[ 35 ] == 1)
                log.trace("[35.1] adding subject=%s", graph.subject);

            // цикл по всем добавляемым субьектам
            /* 2. если создается новый субъект, то ограничений по умолчанию нет
             * 3. если добавляются факты к уже созданному субъекту, то разрешено добавлять
             * если добавляющий автор субъекта
             * или может быть вычислено разрешающее право на U данного субъекта. */

            string authorize_reason;
            bool   subjectIsExist = false;

            bool   authorization_res = false;

            if (authorization_res == true || ticket is null)
            {
                if (ticket !is null && graph.isExsistsPredicate(dc__creator) == false)
                {
                    // добавим признак dc:creator
                    graph.addPredicate(dc__creator, ticket.user_uri);
                }

                context.store_subject(graph, prepareEvents);

                reason = "добавление фактов выполнено:" ~ authorize_reason;
                isOk   = true;
            }
            else
            {
                reason = "добавление фактов не возможно: " ~ authorize_reason;
                if (trace_msg[ 36 ] == 1)
                    log.trace("autorize=%s", reason);
            }
        }
        else
        {
            if (type is null)
                reason = "добавление фактов не возможно: не указан rdf:type для субьекта" ~ graph.subject;
        }
    }
}

public void get(Ticket *ticket, Subject message, Predicate sender, Context context, out bool isOk, out string reason,
                ref Subjects res, out char from_out)
{
    // в качестве аргумента - шаблон для выборки, либо запрос на VQL

    // если аргумент маска:
    //      query:get - обозначает что будет возвращено значение соответствующего предиката
    //      поиск по маске обрабатывает только одноуровневые шаблоны

    isOk = false;

    if (trace_msg[ 41 ] == 1)
        log.trace("command get");

    reason = "запрос не выполнен";

    Predicate args = message.getPredicate(msg__args);

    if (trace_msg[ 42 ] == 1)
    {
        OutBuffer outbuff = new OutBuffer();
        toJson_ld(message, outbuff, true);
        log.trace("[42] command get, cmd=%s", outbuff.toString);
    }

    if (args !is null)
    {
        foreach (arg; args.getObjects())
        {
            if (trace_msg[ 43 ] == 1)
                log.trace("[43] args.objects.type = %s", text(arg.type));

            Subject[] queries;

            if (arg.type == OBJECT_TYPE.LINK_CLUSTER)
            {
                queries = arg.cluster.data;
            }
            else if (arg.type == OBJECT_TYPE.LINK_SUBJECT)
            {
                queries      = new Subject[ 1 ];
                queries[ 0 ] = arg.subject;
            }

            if (trace_msg[ 45 ] == 1)
                log.trace("[45] arguments has been read");

            if (queries is null)
            {
                reason = "в сообщении отсутствует граф-шаблон";
            }

            StopWatch sw;
            sw.start();

            foreach (s_query; queries)
            {
                int    count_found_subjects;

                string query = s_query.getFirstLiteral("query");
                if (query !is null)
                {
                    //writeln ("#1 ticket=", ticket);
                    count_found_subjects = context.vql.get(ticket, query, res);

                    reason = "";
                }
                /////////////////////////////////////////////////////////////////////////////////////////
                if (trace_msg[ 58 ] == 1)
                    log.trace("авторизуем найденные субьекты, для пользователя %s", ticket.user_uri);

                // авторизуем найденные субьекты
                int    count_authorized_subjects = res.length;

                string authorize_reason;
                /*
                   foreach(s; res.graphs_of_subject)
                   {
                   count_found_subjects++;

                   bool isExistSubject;
                   bool result_of_az = authorize(userId, s.subject, operation.READ, context, authorize_reason,
                   isExistSubject);

                   if(result_of_az == false)
                   {
                   if(trace_msg[59] == 1)
                   log.trace("AZ: s=%s -> %s ", s.subject, authorize_reason);

                   s.count_edges = 0;
                   s.subject = null;

                   if(trace_msg[60] == 1)
                   log.trace("remove from list");
                   } else
                   {
                   count_authorized_subjects++;
                   }

                   }
                 */
                if (count_found_subjects == count_authorized_subjects)
                {
                    reason = "запрос выполнен: авторизованны все найденные субьекты :" ~ text(count_found_subjects);
                }
                else if (count_found_subjects > count_authorized_subjects && count_authorized_subjects > 0)
                {
                    reason = "запрос выполнен: найденнo : " ~ text(count_found_subjects) ~ ", успешно авторизованно : " ~ text(
                                                                                                                               count_authorized_subjects);
                }
                else if (count_authorized_subjects == 0 && count_found_subjects > 0)
                {
                    reason =
                        "запрос выполнен: ни один из найденных субьектов (" ~ text(count_found_subjects) ~ "), не был успешно авторизован:"
                        ~
                        authorize_reason;
                }

                isOk = true;
                //				}
            }

            if (trace_msg[ 61 ] == 1)
            {
                sw.stop();
                long t = cast(long)sw.peek().usecs;

                log.trace("total time command get: %d [µs]", t);
            }
        }
    }

    // TODO !для безопасности, факты с предикатом [auth:credential] не отдавать !
    //	core.thread.Thread.getThis().sleep(dur!("msecs")( 1 ));
    return;
}

Subject remove(Subject message, Predicate sender, Ticket *ticket, Context context, out bool isOk, out string reason)
{
    if (trace_msg[ 38 ] == 1)
        log.trace("command remove");

    isOk = false;

    reason = "нет причин для выполнения комманды remove";

    Subject res;

    try
    {
        Predicate arg = message.getPredicate(msg__args);
        if (arg is null)
        {
            reason = "аргументы " ~ msg__args ~ " не указаны";
            isOk   = false;
            return null;
        }

        Subject ss = arg.getObjects()[ 0 ].subject;
        if (ss is null)
        {
            reason = msg__args ~ " найден, но не заполнен";
            isOk   = false;
            return null;
        }

        string authorize_reason;
        bool   isExistSubject;

        string userId;

        if (ticket !is null)
            userId = ticket.user_uri;

        bool result_of_az = false;

        if (result_of_az)
        {
            //context.ts.removeSubject(ss.subject);
            reason = "команда remove выполнена успешно";
            isOk   = true;
        }
        else
        {
            reason = "нет прав на удаление субьекта:" ~ authorize_reason;
            isOk   = false;
        }

        return res;
    } catch (Exception ex)
    {
        reason = "ошибка удаления субьекта :" ~ ex.msg;
        isOk   = false;

        return res;
    }
}
