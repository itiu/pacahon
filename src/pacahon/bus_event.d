module pacahon.bus_event;

private import std.outbuffer, std.stdio, std.concurrency, std.datetime, std.conv;

private import util.container;
private import util.logger;
private import util.utils;
private import util.cbor8individual;

private import pacahon.know_predicates;
private import pacahon.context;
private import pacahon.define;
private import onto.individual;
private import onto.sgraph;
private import onto.resource;

logger log;

static this()
{
    log = new logger("bus_event", "log", "bus_event");
}

int count;

void bus_event_after(Individual *individual, string subject_as_cbor, EVENT type, Context context)
{
    //writeln ("@bus_event B subject_as_cbor=[", subject_as_cbor, "]");

    Tid tid_condition = context.getTid(THREAD.condition);

    if (tid_condition != Tid.init)
    {
//		writeln ("#bus_event #1, conditin_name=", thread.condition, ", tid_condition=", tid_condition);
        try
        {
//			 core.thread.Thread.sleep(dur!("seconds")(10));
            // отправляем информацию об изменении индивидуала в модуль авторизации
            send(tid_condition, type, subject_as_cbor);
        }
        catch (Exception ex)
        {
            writeln("EX!bus_event:", ex.msg);
        }
    }

    Resources rdfType = individual.resources[ rdf__type ];

    //writeln (rdfType);

    if (rdfType.anyExist(owl_tags) == true)
    {
        try
        {
            // изменения в онтологии, послать в interthread сигнал о необходимости перезагрузки онтологии
            context.push_signal("onto", Clock.currStdTime() / 10000);
        }
        catch (Exception ex)
        {
            writeln("EX!bus_event:", ex.msg);
        }
    }

    if (rdfType.anyExist(veda_schema__PermissionStatement) == true || rdfType.anyExist(veda_schema__Membership) == true)
    {
        Tid tid_acl = context.getTid(THREAD.acl_manager);
        if (tid_acl != Tid.init)
        {
            send(tid_acl, CMD.STORE, type, subject_as_cbor);
        }
    }

    //writeln ("#bus_event E");
}


