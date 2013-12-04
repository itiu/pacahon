module search.search_event;

private import std.outbuffer;
private import std.stdio;

private import ae.utils.container;

private import util.oi;
private import util.logger;
private import util.utils;
private import pacahon.know_predicates;
private import pacahon.graph;
private import pacahon.context;
private import onto.doc_template;

logger log;

static this()
{
	log = new logger("2search", "log", "2search");
}

void search_event(Subject graph, Context context)
{
//	writeln ("#search_event 1");
	
	if (graph.docTemplate !is null && graph.docTemplate.isExsistsPredicate (docs__full_text_search, "0"))
	    return;
	    
//	writeln ("#search_event 2 ", graph);
	    
	if(graph.isExsistsPredicate(rdf__type, docs__Document) && graph.isExsistsPredicate(docs__actual, "true"))
	{
//		writeln ("#to search !!!");
		Set!OI search_points = context.get_gateways("to-search");
		
//		writeln ("GWS:", context.gateways);
		if(search_points.size > 0)
		{
//		    writeln ("#C1");
			foreach (search_point; search_points.items)
			{						
				if(search_point.get_db_type == "xapian")
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
		
		if(report_points.size > 0)
		{
			foreach (report_point; report_points.items)
			{			
				OutBuffer outbuff = new OutBuffer();
//				toJson_search(graph, outbuff, 0, false, null, context);
				ubyte[] bb = outbuff.toBytes();

				report_point.send(bb);
				//report_point.reciev();
			}
		} else
		{
			log.trace("отправка данных по субьекту [%s] не была выполненна, так как  [%s] не был найден в файле настроек",
					graph.subject, "to-report");
		}

	}

}


