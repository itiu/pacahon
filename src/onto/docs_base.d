module onto.docs_base;

private import std.stdio;

private import trioplax.mongodb.triple;
private import trioplax.mongodb.TripleStorage;

//private import util.Logger;

private import pacahon.know_predicates;

private import pacahon.graph;
private import pacahon.thread_context;


// TODO предусмотреть сброс кэша шаблонов
GraphCluster[string][string] templates;
byte[string] indexedPredicates;

//Logger log;

static this()
{
	//	log = new Logger("pacahon", "log", "command-io");

	indexedPredicates[owl__onProperty] = 1;
	indexedPredicates[rdf__type] = 1;
	indexedPredicates[docs__actual] = 1;
}

GraphCluster getDocument(string subject, Objectz[] readed_predicate, ThreadContext server_context)
{
	if(subject is null)
		return null;

	byte[string] r_predicate;

	if (readed_predicate is null)
	{
		r_predicate[query__all_predicates] = 1;
	}
	else
	{
	foreach(el; readed_predicate)
	{
		r_predicate[el.literal] = 1;
	}
	
	r_predicate[rdf__type] = 0;
	}
	return _getDocument(subject, r_predicate, server_context);
}

GraphCluster _getDocument(string subject, byte[string] r_predicate, ThreadContext server_context)
{
//	writeln ("#### getDocument :[", subject, "] ", readed_predicate);
	GraphCluster res = null;

	if(subject is null)
		return null;

	Triple[] search_mask = new Triple[1];
	TLIterator it;

	search_mask[0] = new Triple(subject, null, null);

//	writeln ("r_predicate = ", r_predicate);
	it = server_context.ts.getTriplesOfMask(search_mask, r_predicate);
	if(it !is null)
	{
		foreach(triple; it)
		{
			if(res is null)
				res = new GraphCluster();

			res.addTriple(triple.S, triple.P, triple.O, triple.lang);
//			writeln(triple.S, " ", triple.P, " ", triple.O, " ", triple.lang);
		}
	}
	
	if(res !is null)
	{
		res.reindex_i1PO(indexedPredicates);
	}	
	return res;
}

GraphCluster getTemplate(string v_dc_identifier, string v_docs_version, ThreadContext server_context)
{
	GraphCluster res = null;

	if(v_dc_identifier is null)
		return null;

	try
	{
		GraphCluster[string] rr = templates.get(v_dc_identifier, null);

		if(rr !is null)
		{
			if(v_docs_version is null)
				res = rr.get("actual", null);
			else
				res = rr.get(v_docs_version, null);
		}
	} catch(Exception ex)
	{
		writeln("Ex!" ~ ex.msg);
	}

	if(res is null)
	{
		writeln("не найдено в кэше [", v_dc_identifier, "][", v_docs_version, "]");
		//				writeln(templates);

		// в кэше не найдено, ищем в базе
		Triple[] search_mask = new Triple[3];
		byte[string] readed_predicate;
		TLIterator it;

		search_mask[0] = new Triple(null, dc__identifier, v_dc_identifier);
		search_mask[1] = new Triple(null, rdf__type, rdfs__Class);
		if(v_docs_version is null)
			search_mask[2] = new Triple(null, docs__actual, "true");
		else
			search_mask[2] = new Triple(null, docs__version, v_docs_version);
		readed_predicate["query:all_predicates"] = 1;

		it = server_context.ts.getTriplesOfMask(search_mask, readed_predicate);
		string tmpl_subj;
		if(it !is null)
		{
			foreach(triple; it)
			{
				if(res is null)
					res = new GraphCluster();

				if(tmpl_subj is null)
					tmpl_subj = triple.S;

				res.addTriple(triple.S, triple.P, triple.O, triple.lang);
				//								writeln (triple.S, " ", triple.P, " ",triple.O, " ",triple.lang);
			}

			search_mask = new Triple[1];
			search_mask[0] = new Triple(null, dc__hasPart, tmpl_subj);

			it = server_context.ts.getTriplesOfMask(search_mask, readed_predicate);
			if(it !is null)
			{
				foreach(triple; it)
				{
					res.addTriple(triple.S, triple.P, triple.O, triple.lang);
					//										writeln (triple.S, " ", triple.P, " ",triple.O, " ",triple.lang);
				}
			}
		}

		if(res !is null)
		{
			res.reindex_i1PO(indexedPredicates);
			//			res.reindex_iXPO();

			if(res.find_subject(docs__actual, "true"))
			{
				//				writeln ("set actual to:[", v_dc_identifier, "][", v_docs_version, "]");
				// это актуальная версия шаблона
				templates[v_dc_identifier]["actual"] = res;
			}

			if(v_docs_version !is null)
				templates[v_dc_identifier][v_docs_version] = res;
		}

	} else
	{
		//				writeln("найдено в кэше[", v_dc_identifier, "][", v_docs_version, "]");
	}

	return res;
}
