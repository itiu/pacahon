module onto.docs_base;

private import std.stdio;
private import std.datetime;

private import pacahon.know_predicates;

private import pacahon.graph;
private import pacahon.thread_context;
private import util.Logger;
private import onto.rdf_base;
private import onto.doc_template;
private import trioplax.mongodb.TripleStorage;

byte[string] indexedPredicates;

Logger log;

static this()
{
	log = new Logger("ba2pacahon", "log", "ba2pacahon");
}

//Logger log;

static this()
{
	//	log = new Logger("pacahon", "log", "command-io");

	indexedPredicates[owl__onProperty] = 1;
	indexedPredicates[rdf__type] = 1;
	indexedPredicates[docs__actual] = 1;
}

Subject getDocument(string subject, Objectz[] readed_predicate, ThreadContext server_context, ref Subject[string] doc_cache)
{
	if(subject is null)
		return null;

	Subject res = doc_cache.get(subject, null);
	if(res !is null)
		return res;

	byte[string] r_predicate;

	if(readed_predicate is null)
	{
		r_predicate[query__all_predicates] = 1;
	} else
	{
		foreach(el; readed_predicate)
		{
			r_predicate[el.literal] = 1;
		}

		r_predicate[rdf__type] = 0;
	}
	return _getDocument(subject, r_predicate, server_context, doc_cache);
}

Subject _getDocument(string subject, byte[string] r_predicate, ThreadContext server_context,
		ref Subject[string] doc_cache_for_insert)
{
	//	 writeln("#### getDocument :[", subject, "] ", r_predicate);
	Subject main_subject = null;
	GraphCluster res = null;

	if(subject is null)
		return null;

	Triple[] search_mask = new Triple[1];
	TLIterator it;

	search_mask[0] = new Triple(subject, null, null);

	it = server_context.ts.getTriplesOfMask(search_mask, r_predicate);
	if(it !is null)
	{
		foreach(triple; it)
		{
			if(res is null)
				res = new GraphCluster();

			Subject ss = res.addTriple(triple.S, triple.P, triple.O, triple.lang);

			if(triple.P == rdf__type)
			{
				if(triple.O != rdf__Statement && main_subject is null)
					main_subject = ss;
				if(triple.O == docs__employee_card || triple.O == docs__unit_card || triple.O == docs__department_card)
					doc_cache_for_insert[ss.subject] = ss;
			}

		}
		if(res !is null)
		{
			foreach(Subject subj; res.getArray)
			{
				if(subj != main_subject)
				{
					// это реификация
					//?					string r_predicate = subj.getFirstLiteral(rdf__predicate);
					//					string r_object = subj.getFirstLiteral(rdf__object);

					Objectz[] objects = main_subject.getObjects(rdf__predicate);
				}
			}
		}
	}

	//	 if (main_subject is null)
	//	 {
	//		 writeln("#### getDocument :[", subject, "] ", r_predicate, ", main_subject=", main_subject);
	//			writeln ("pause 10s");
	//			core.thread.Thread.sleep(dur!("seconds")(10));
	//		 
	//	 }

	return main_subject;
}

/////////////////////////////////////////////////////////////////////////////////////////////////////////////
DocTemplate getTemplate(string v_dc_identifier, string v_docs_version, ThreadContext server_context, string uid = null)
{
	Triple[] search_mask = new Triple[3];

	DocTemplate res = null;

	if(v_dc_identifier is null && uid is null)
		return null;

	try
	{
		DocTemplate[string] rr;

		if(uid !is null)
		{
			v_dc_identifier = uid;
			v_docs_version = "@";
		}

		rr = server_context.templates.get(v_dc_identifier, null);

		if(rr !is null)
		{
			if(v_docs_version is null)
				res = rr.get("actual", null);
			else
				res = rr.get(v_docs_version, null);
		}
	} catch(Exception ex)
	{
		// writeln("Ex!" ~ ex.msg);
	}

	if(res is null)
	{
		log.trace("не найдено в кэше [%s][%s]", v_dc_identifier, v_docs_version);
		//				// writeln(templates);

		// в кэше не найдено, ищем в базе
		byte[string] readed_predicate;
		TLIterator it;

		if(uid is null)
		{
			search_mask[0] = new Triple(null, dc__identifier, v_dc_identifier);
			search_mask[1] = new Triple(null, rdf__type, rdfs__Class);
			if(v_docs_version is null)
				search_mask[2] = new Triple(null, docs__actual, "true");
			else
				search_mask[2] = new Triple(null, docs__version, v_docs_version);
		} else
		{
			//// writeln ("UID=", uid);
			search_mask[0] = new Triple(uid, null, null);
			search_mask.length = 1;
		}

		readed_predicate[query__all_predicates] = 1;

		it = server_context.ts.getTriplesOfMask(search_mask, readed_predicate);
		string tmpl_subj;
		if(it !is null)
		{
			foreach(triple; it)
			{
				if(res is null)
					res = new DocTemplate();

				if(tmpl_subj is null)
					tmpl_subj = triple.S;

				Subject ss = res.addTriple(triple.S, triple.P, triple.O, triple.lang);
				if(res.main is null)
				{
					res.main = ss;
					server_context.templates[tmpl_subj]["@"] = res;
				}

			}

			if(res !is null)
			{
				search_mask = new Triple[1];
				search_mask[0] = new Triple(null, dc__hasPart, tmpl_subj);

				it = server_context.ts.getTriplesOfMask(search_mask, readed_predicate);
				if(it !is null)
				{
					foreach(triple; it)
					{
						res.addTriple(triple.S, triple.P, triple.O, triple.lang);
						//										// writeln (triple.S, " ", triple.P, " ",triple.O, " ",triple.lang);
					}
				}
			}
		}

		if(res !is null)
		{
			res.data.reindex_i1PO(indexedPredicates);
			//			res.reindex_iXPO();

			if(res.data.find_subject(docs__actual, "true"))
			{
				//				// writeln ("set actual to:[", v_dc_identifier, "][", v_docs_version, "]");
				// это актуальная версия шаблона
				server_context.templates[v_dc_identifier]["actual"] = res;
			}

			if(v_docs_version !is null)
				server_context.templates[v_dc_identifier][v_docs_version] = res;
		}

	} else
	{
		//				// writeln("найдено в кэше[", v_dc_identifier, "][", v_docs_version, "]");
	}

	if(res is null)
	{
		if(v_docs_version !is null)
		{
			log.trace("шаблон [%s], с указаной версией[%s], не найден, поищем без версии", v_dc_identifier, v_docs_version);
			// попробуем еще раз поискать без версии
			res = getTemplate(v_dc_identifier, null, server_context);

			if(res !is null)
				server_context.templates[v_dc_identifier][v_docs_version] = res;
		}
		if(res is null)
			log.trace("template not found:%s search_mask=%s", v_dc_identifier, search_mask);
	}

	return res;
}

Subject get_reification_subject_of_link(string subj_versioned_UID, string new_code, string value, ThreadContext server_context,
		ref Subject[string] doc_cache, out Predicate real_importPredicates, Predicate importPredicates = null)
{
	//	bool TMP_on_trace = false;

	//	if (value == "zdb:doc_d4a7956e-1382-4c6d-be6b-32d0bd511df3")
	//	{
	//		 writeln("#!!!");
	//		TMP_on_trace = true;
	//	}

	// в случае линка, в исходной ba-json данных не достаточно для реификации ссылки, 
	// требуется считать из базы

	//	if (TMP_on_trace)
	//	 writeln("#link value=", value);

	Subject linked_doc = null;
	string linked_template_uid;

	if(importPredicates !is null)
	{
		//		if (TMP_on_trace)
		//		{
		//		writeln("###1 importPredicates=", importPredicates.getObjects());
		//		writeln("###1 value=", value);
		//		}

		//		linked_doc = getDocument(value, importPredicates.getObjects(), server_context, doc_cache);
		// TODO: OPTIMIZE IT, конечно, так не экономно считывать весь документ, с другой стороны в кэше лучше хранить полный документ или
		// указание, какие предикаты были считанны
		linked_doc = getDocument(value, null, server_context, doc_cache);
		// writeln("###1 linked_doc=", linked_doc);

		// найдем @ шаблона
		if(linked_doc !is null)
		{
			Predicate type_in = linked_doc.getPredicate(rdf__type);
			linked_template_uid = type_in.getObjects()[0].literal;
			if(type_in.getObjects().length > 1 && (linked_template_uid == docs__Document || linked_template_uid == auth__Authenticated || linked_template_uid == docs__unit_card || linked_template_uid == docs__group_card))
				linked_template_uid = type_in.getObjects()[1].literal;
		}

	} else
	{
		//		if (TMP_on_trace)
		//			writeln("###2 new_code=", new_code);
		// импортируемые предикаты не указанны
		// считаем экспортируемые предикаты из шаблона документа
		linked_doc = getDocument(value, null, server_context, doc_cache);

		//		if (TMP_on_trace)
		//			writeln("###2.0.1 linked_doc=", linked_doc);

		if(linked_doc !is null)
		{
			// найдем @ шаблона
			Predicate type_in = linked_doc.getPredicate(rdf__type);
			linked_template_uid = type_in.getObjects()[0].literal;
			if(type_in.getObjects().length > 1 && (linked_template_uid == docs__Document || linked_template_uid == auth__Authenticated || linked_template_uid == docs__unit_card || linked_template_uid == docs__group_card))
				linked_template_uid = type_in.getObjects()[1].literal;

			DocTemplate template_gr = getTemplate(null, null, server_context, linked_template_uid);

			if(template_gr !is null)
			{
				//				if (TMP_on_trace)
				//				 writeln("###2.5 template_gr.data=", template_gr.data);
				importPredicates = template_gr.get_export_predicates();
				//				if (TMP_on_trace)
				//				writeln("###2.5 importPredicates=", importPredicates);
			}

			//			if (TMP_on_trace)
			//			writeln("###2.6");
		}
	}
	//	if (TMP_on_trace)
	//	writeln("###3");
	if(importPredicates !is null && linked_doc !is null)
	{
		//		if (TMP_on_trace)
		//		writeln("###3.1");
		// создать реифицированный субьект rS к текущему аттрибуту
		Subject rS = create_reifed_info(subj_versioned_UID, new_code, value);

		foreach(el; importPredicates.getObjects())
		{
			Predicate pp = linked_doc.getPredicate(el.literal);
			//			if (TMP_on_trace)
			//				writeln("###3.2 pp=", pp);
			if(pp !is null)
			{
				rS.addPredicate(el.literal, pp.getObjects());
			}
		}

		real_importPredicates = importPredicates;

		if(rS !is null)
		{
			rS.addPredicate(link__importClass, linked_template_uid);
		}

		//		if (TMP_on_trace)
		//			writeln("###3.3 rS=", rS);

		//		if (TMP_on_trace)
		//		{
		//			core.thread.Thread.sleep(dur!("seconds")(10));
		//		}

		return rS;
	}

	return null;
}
