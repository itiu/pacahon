module onto.docs_base;

private import std.stdio;

private import trioplax.triple;
private import trioplax.mongodb.TripleStorage;

//private import util.Logger;

private import pacahon.know_predicates;

private import pacahon.graph;
private import pacahon.thread_context;

//private import std.json_str;
//private import std.string;

//private import util.Logger;
//private import std.outbuffer;
//private import pacahon.json_ld.parser;

//private import util.utils;

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

/*
 void setActualTemplate(string v_dc_identifier, GraphCluster old_version_tmpl, GraphCluster new_version_tmpl,
 ThreadContext server_context)
 {
 if(old_version_tmpl is null)
 old_version_tmpl = getTemplate(v_dc_identifier, null, server_context);

 if(old_version_tmpl !is null)
 {
 Predicate* old_version = old_version_tmpl.find_subject_and_get_predicate(rdf__type, rdfs__Class, docs__version);

 if(old_version !is null)
 {
 templates[v_dc_identifier][old_version.getFirstObject()] = old_version_tmpl;
 }
 templates[v_dc_identifier]["actual"] = new_version_tmpl;
 new_version_tmpl.reindex_i1PO(indexedPredicates);
 //		new_version_tmpl.reindex_iXPO();		
 }

 }
 */

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
		byte[char[]] readed_predicate;
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
