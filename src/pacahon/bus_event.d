module pacahon.bus_event;

private import std.outbuffer;
private import std.stdio;
private import std.concurrency;
private import std.datetime;

private import util.container;
private import util.oi;
private import util.logger;
private import util.utils;
private import util.graph;

private import pacahon.know_predicates;
private import pacahon.context;

logger log;

static this()
{
    log = new logger("bus_event", "log", "bus_event");
}

void bus_event(Subject graph, string subject_as_cbor, EVENT type, Context context)
{
//	writeln ("#bus_event B subject_as_cbor=[", subject_as_cbor, "]");

//	Tid tid_condition = locate (thread.condition);
	Tid tid_condition = context.getTid (thread.condition);

	if (tid_condition != Tid.init)
	{
//		writeln ("#bus_event #1, conditin_name=", thread.condition, ", tid_condition=", tid_condition);
		try
		{
//			 core.thread.Thread.sleep(dur!("seconds")(10));
		send (tid_condition, type, subject_as_cbor);
		}
		catch (Exception ex)
		{
			writeln ("EX!bus_event:", ex.msg);
		}
//		writeln ("#bus_event #2");
	}	

//	writeln ("#bus_event E");
//    if (graph.docTemplate !is null && graph.docTemplate.isExsistsPredicate(docs__full_text_search, "0"))
//        return;

/*
    if (graph.isExsistsPredicate(rdf__type, docs__Document) && graph.isExsistsPredicate(docs__actual, "true"))
    {
//		writeln ("#to search !!!");
        Set!OI search_points = context.get_gateways("to-search");

//		writeln ("GWS:", context.gateways);
        if (search_points.size > 0)
        {
//		    writeln ("#C1");
            foreach (search_point; search_points.items)
            {
                if (search_point.get_db_type == "xapian")
                {
                    search_point.send(graph);
                }
                else
                {
                    log.trace("отправка данных по субьекту [%s] не была выполненна, так как  [%s] не был найден в файле настроек",
                              graph.subject, "to-search");
                }
            }
        }

        Set!OI report_points = context.get_gateways("to-report");

        if (report_points.size > 0)
        {
            foreach (report_point; report_points.items)
            {
                OutBuffer outbuff = new OutBuffer();
//				toJson_search(graph, outbuff, 0, false, null, context);
                ubyte[]   bb = outbuff.toBytes();

                report_point.send(bb);
                //report_point.reciev();
            }
        }
        else
        {
            log.trace("отправка данных по субьекту [%s] не была выполненна, так как  [%s] не был найден в файле настроек",
                      graph.subject, "to-report");
        }
    }
*/
}


