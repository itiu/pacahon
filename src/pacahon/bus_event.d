/**
  * обработка событий 
  */
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
private import onto.resource;

logger log;

static this()
{
    log = new logger("bus_event", "log", "bus_event");
}

int count;

void bus_event_after(Individual *individual, Resource[ string ] rdfType, string subject_as_cbor, EVENT ev_type, Context context)
{
    //writeln ("@bus_event B subject_as_cbor=[", individual.uri, "]");
    //writeln (rdfType);

    if (ev_type == EVENT.CREATE || ev_type == EVENT.UPDATE)
    {
        Tid tid_condition = context.getTid(P_MODULE.condition);

        if (rdfType.anyExist(owl_tags) == true)
        {
            // изменения в онтологии, послать в interthread сигнал о необходимости перезагрузки (context) онтологии
            context.push_signal("onto", Clock.currStdTime() / 10000);
        }

        if (rdfType.anyExist(veda_schema__Mandate))
        {
            // изменения в veda-schema:Mandate, послать модуль Condition сигнал о перезагузке скрипта
            send(tid_condition, CMD.RELOAD, subject_as_cbor, thisTid);
            receive((bool){});
        }

        if (rdfType.anyExist(veda_schema__PermissionStatement) == true || rdfType.anyExist(veda_schema__Membership) == true)
        {
            Tid tid_acl = context.getTid(P_MODULE.acl_manager);
            if (tid_acl != Tid.init)
            {
                send(tid_acl, CMD.STORE, ev_type, subject_as_cbor);
            }
        }


        if (tid_condition != Tid.init)
        {
//		writeln ("#bus_event #1, conditin_name=", P_MODULE.condition, ", tid_condition=", tid_condition);
            try
            {
//			 core.P_MODULE.P_MODULE.sleep(dur!("seconds")(10));
                send(tid_condition, ev_type, subject_as_cbor);
            }
            catch (Exception ex)
            {
                writeln("EX!bus_event:", ex.msg);
            }
        }
    }
    //writeln ("#bus_event E");
}


