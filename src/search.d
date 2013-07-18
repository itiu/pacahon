module pacahon.search;

private import std.outbuffer;
private import std.stdio;

private import pacahon.know_predicates;

private import pacahon.graph;
private import pacahon.thread_context;
private import pacahon.oi;
private import onto.doc_template;

//private import pacahon.json_ld.parser1;

private import util.Logger;

Logger log;

static this()
{
	log = new Logger("2search", "log", "2search");
}

void search_event(Subject graph, ThreadContext server_context)
{
	if(graph.isExsistsPredicate(rdf__type, docs__Document) && graph.isExsistsPredicate(docs__actual, "true") && graph.isExsistsPredicate(
			docs__active, "true"))
	{
		//writeln ("to search !!!");
		OI search_point = server_context.gateways.get("search", null);

		if(search_point !is null)
		{
			OutBuffer outbuff = new OutBuffer();
			outbuff.write("PUT|/pacahon/doc1/");
			outbuff.write(graph.subject);
			outbuff.write('|');
			toJson_search(graph, outbuff, 0, false, null, server_context);
			outbuff.write(0);
			ubyte[] bb = outbuff.toBytes();

			search_point.send(bb);
			//string res = search_point.reciev();
			//		writeln (res);
		} else
		{
			log.trace("отправка данных для субьекта [%s] не была выполненна, так как  [%s] не был найден в файле настроек",
					graph.subject, "search");
		}
		OI report_point = server_context.gateways.get("report", null);
		if(report_point !is null)
		{
			OutBuffer outbuff = new OutBuffer();
			toJson_search(graph, outbuff, 0, false, null, server_context);
			ubyte[] bb = outbuff.toBytes();

			report_point.send(bb);
			//report_point.reciev();
		} else
		{
			log.trace("отправка данных для субьекта [%s] не была выполненна, так как  [%s] не был найден в файле настроек",
					graph.subject, "report");
		}

	}

}

void toJson_search(Subject ss, ref OutBuffer outbuff, int level, bool is_reification, string reifed_value,
		ThreadContext server_context)
{
	if(ss.subject is null && ss.count_edges == 0)
	{
		return;
	}

	for(int i = 0; i < level; i++)
		outbuff.write(cast(char[]) "	");

	outbuff.write("{\n");

	for(int i = 0; i < level; i++)
		outbuff.write(cast(char[]) "	 ");

	if(ss.subject !is null && ((is_reification == true && level == 0) || is_reification == false))
	{
		outbuff.write(cast(char[]) "\"@\" : \"");
		escaping_or_uuid2search(ss.subject, outbuff);
		outbuff.write(cast(char[]) "\",\n");
	}

	bool jj = 0;

	foreach(pp; ss.getPredicates())
	{
		if(is_reification == true && level > 0)
		{
			if(pp.predicate == rdf__type || pp.predicate == rdf__subject || pp.predicate == rdf__predicate || pp.predicate == rdf__object || pp.predicate == link__importClass)
				continue;
		}

		string type = "";

		if(pp.metadata !is null)
			type = pp.metadata.getFirstLiteral(owl__allValuesFrom);

		if(jj > 0)
			outbuff.write(cast(char[]) ",\n");
		jj = 1;

		for(int i = 0; i < level; i++)
			outbuff.write(cast(char[]) "	 ");

		string p_text_ru = "";
		string p_text_en = "";

		outbuff.write('"');
		outbuff.write(pp.predicate);
		outbuff.write(cast(char[]) "\": ");
		if(pp.count_objects > 1)
			outbuff.write('[');

		bool ff = false;
		foreach(oo; pp.getObjects())
		{
			if(ff == true)
				outbuff.write(',');
			ff = true;

			if(oo.type == OBJECT_TYPE.LITERAL)
			{
				outbuff.write('"');
				escaping_or_uuid2search(oo.literal, outbuff);
				outbuff.write('"');

				if(pp.count_objects > 1)
				{
					if(oo.lang == LANG.RU)
						p_text_ru ~= oo.literal;
					if(oo.lang == LANG.EN)
						p_text_en ~= oo.literal;
				}

			} else if(oo.type == OBJECT_TYPE.URI)
			{
				if(oo.literal is null)
				{
					outbuff.write("null");
				} else
				{
					outbuff.write('"');
					escaping_or_uuid2search(oo.literal, outbuff);
					outbuff.write('"');
				}
			} else if(oo.type == OBJECT_TYPE.SUBJECT)
			{
				if(oo.subject !is null && oo.subject.count_edges == 0)
				{
					outbuff.write(cast(char[]) "null");
				} else
				{
					outbuff.write('\n');
					toJson_search(oo.subject, outbuff, level + 1, false, null, server_context);
				}
			} else if(oo.type == OBJECT_TYPE.CLUSTER)
			{
				outbuff.write('[');

				for(int i = 0; i < oo.cluster.length; i++)
				{
					if(i > 0)
						outbuff.write(',');
					outbuff.write('\n');
					toJson_search(oo.cluster.getArray[i], outbuff, level + 1, false, null, server_context);
				}

				outbuff.write(']');
			}

		}
		if(pp.count_objects > 1)
			outbuff.write(']');

		if(pp.count_objects > 1)
		{
			if(p_text_ru.length > 0)
			{
				outbuff.write(",\n\"");

				outbuff.write(pp.predicate);
				outbuff.write("_ru\": \"");
				escaping_or_uuid2search(p_text_ru, outbuff);
				outbuff.write('"');
			}

			if(p_text_en.length > 0)
			{
				outbuff.write(",\n\"");

				outbuff.write(pp.predicate);
				outbuff.write("_en\": \"");
				escaping_or_uuid2search(p_text_en, outbuff);
				outbuff.write('"');
			}
		}

		if(type == xsd__string)
		{
			bool sp = true;

			ff = false;
			foreach(oo; pp.getObjects())
			{
				if(oo.type == OBJECT_TYPE.LITERAL && (oo.lang == _RU || oo.lang == _NONE))
				{
					if(sp == true)
					{
						outbuff.write(",\"");
						outbuff.write(pp.predicate);
						outbuff.write(cast(char[]) ".text_ru\": ");
						if(pp.count_objects > 1)
							outbuff.write('[');
						sp = false;
					}

					if(ff == true)
						outbuff.write(',');
					ff = true;

					outbuff.write('"');
					escaping_or_uuid2search(oo.literal, outbuff);
					outbuff.write('"');
				}
			}

			if(sp == false && pp.count_objects > 1)
				outbuff.write(']');

			sp = true;

			ff = false;
			foreach(oo; pp.getObjects())
			{
				if(oo.type == OBJECT_TYPE.LITERAL && (oo.lang == _EN))
				{
					if(sp == true)
					{
						outbuff.write(",\"");
						outbuff.write(pp.predicate);
						outbuff.write(cast(char[]) ".text_en\": ");
						if(pp.count_objects > 1)
							outbuff.write('[');
						sp = false;
					}

					if(ff == true)
						outbuff.write(',');
					ff = true;

					outbuff.write('"');
					escaping_or_uuid2search(oo.literal, outbuff);
					outbuff.write('"');
				}
			}

			if(sp == false && pp.count_objects > 1)
				outbuff.write(']');
		} else if(type == xsd__decimal)
		{
			if(pp.count_objects > 0)
				outbuff.write(",\n");

			outbuff.write('"');
			outbuff.write(pp.predicate);
			outbuff.write(cast(char[]) ".decimal\": ");
			if(pp.count_objects > 1)
				outbuff.write('[');

			ff = false;
			foreach(oo; pp.getObjects())
			{
				if(ff == true)
					outbuff.write(',');
				ff = true;

				if(oo.type == OBJECT_TYPE.LITERAL)
				{
					outbuff.write(oo.literal);
				}
			}
			if(pp.count_objects > 1)
				outbuff.write(']');
		} else if(type == xsd__dateTime)
		{
			if(pp.count_objects > 0)
				outbuff.write(",\n");

			outbuff.write('"');
			outbuff.write(pp.predicate);
			outbuff.write(cast(char[]) ".dateTime\": ");
			if(pp.count_objects > 1)
				outbuff.write('[');

			ff = false;
			foreach(oo; pp.getObjects())
			{
				if(ff == true)
					outbuff.write(',');
				ff = true;

				if(oo.type == OBJECT_TYPE.LITERAL)
				{
					outbuff.write('"');
					outbuff.write(oo.literal);
					outbuff.write('"');
				}
			}
			if(pp.count_objects > 1)
				outbuff.write(']');
		}
	}

	foreach(pp; ss.getPredicates())
	{
		bool sp = true;
		foreach(oo; pp.getObjects())
		{
			if(oo.reification !is null && oo.reification.count_edges > 0)
			{
				outbuff.write(',');
				if(sp == true)
				{
					outbuff.write('"');
					outbuff.write(pp.predicate);
					outbuff.write(".reif\": [");
					sp = false;
				}

				toJson_search(oo.reification, outbuff, level + 1, true, oo.literal, server_context);
			}
		}
		if(sp == false)
		{
			outbuff.write(']');
		}
	}

	if(ss.exportPredicates !is null)
	{
		string cname_composit_text_ru;
		string cname_composit_text_en;

		foreach(pp; ss.getPredicates())
		{
			if(ss.exportPredicates.isExistLiteral(pp.predicate) == true)
			{
				foreach(ooo; pp.getObjects)
				{
					if(ooo.type == OBJECT_TYPE.LITERAL && (ooo.lang == _RU || ooo.lang == _NONE))
					{
						if(ooo.literal.length > 2)
						{
							if(ooo.literal[$ - 3] == '@')
								cname_composit_text_ru = ooo.literal[0 .. $ - 3] ~ " " ~ cname_composit_text_ru;
							else
								cname_composit_text_ru = ooo.literal ~ " " ~ cname_composit_text_ru;
						} else
						{
							cname_composit_text_ru = ooo.literal ~ " " ~ cname_composit_text_ru;
						}
					}
					if(ooo.type == OBJECT_TYPE.LITERAL && ooo.lang == _EN)
					{
						if(ooo.literal.length > 2)
						{
							if(ooo.literal[$ - 3] == '@')
								cname_composit_text_en = ooo.literal[0 .. $ - 3] ~ " " ~ cname_composit_text_en;
							else
								cname_composit_text_en = ooo.literal ~ " " ~ cname_composit_text_en;
						} else
						{
							cname_composit_text_en = ooo.literal ~ " " ~ cname_composit_text_en;
						}
					}

				}

			}
		}

		if(cname_composit_text_ru !is null)
		{
			outbuff.write(",\"cname_ru\": \"");
			escaping_or_uuid2search(cname_composit_text_ru, outbuff);
			outbuff.write('"');
		}
		if(cname_composit_text_en !is null)
		{
			outbuff.write(",\"cname_en\": \"");
			escaping_or_uuid2search(cname_composit_text_en, outbuff);
			outbuff.write('"');
		}
	}

	if(is_reification == true)
	{
		string composit_text_ru;
		string composit_text_en;

		// считаем шаблон субьекта ссылки у которого были импортированны предикаты
		string reif_template_uid = ss.getFirstLiteral(link__importClass);

		DocTemplate reif_template = onto.docs_base.getTemplate(null, null, server_context, reif_template_uid);

		// 2. для каждого из импортированных предикатов в реификации определим тип данных						
		// иначе в текст напихаем все из реификации
		foreach(opp; ss.getPredicates)
		{
			if(opp.predicate == rdf__type || opp.predicate == rdf__subject || opp.predicate == rdf__predicate || opp.predicate == rdf__object || opp.predicate == link__importClass)
				continue;

			if(opp.count_objects <= 0)
				continue;

			if(reif_template is null)
				continue;

			Predicate reif_allValuesFrom;

			reif_allValuesFrom = reif_template.data.find_subject_and_get_predicate(owl__onProperty, opp.predicate,
					owl__allValuesFrom);

			if(reif_allValuesFrom is null || reif_allValuesFrom.isExistLiteral(xsd__string) == false)
				continue;

			foreach(ooo; opp.getObjects)
			{
				if(ooo.type == OBJECT_TYPE.LITERAL && ooo.lang == _RU || ooo.lang == _NONE)
				{
					if(ooo.literal.length > 2)
					{
						if(ooo.literal[$ - 3] == '@')
							composit_text_ru = ooo.literal[0 .. $ - 3] ~ " " ~ composit_text_ru;
						else
							composit_text_ru = ooo.literal ~ " " ~ composit_text_ru;
					} else
					{
						composit_text_ru = ooo.literal ~ " " ~ composit_text_ru;
					}
				}
				if(ooo.type == OBJECT_TYPE.LITERAL && ooo.lang == _EN)
				{
					if(ooo.literal.length > 2)
					{
						if(ooo.literal[$ - 3] == '@')
							composit_text_en = ooo.literal[0 .. $ - 3] ~ " " ~ composit_text_en;
						else
							composit_text_en = ooo.literal ~ " " ~ composit_text_en;
					} else
					{
						composit_text_en = ooo.literal ~ " " ~ composit_text_en;
					}
				}

			}
		}

		if(composit_text_ru !is null || composit_text_en !is null)
			outbuff.write(',');

		if(composit_text_ru !is null)
		{
			outbuff.write("\n\"text_ru\":\"");
			escaping_or_uuid2search(composit_text_ru, outbuff);

			if(composit_text_en !is null)
				outbuff.write("\",");
			else
				outbuff.write('"');
		}

		if(composit_text_en !is null)
		{
			outbuff.write("\n\"text_en\":\"");
			escaping_or_uuid2search(composit_text_en, outbuff);
			outbuff.write('"');
		}

		for(int i = 0; i < level; i++)
			outbuff.write("	");

	}

	if(is_reification == true && jj > 0)
	{
		outbuff.write(",\n\"link\" : \"");
		escaping_or_uuid2search(reifed_value, outbuff);
		outbuff.write('"');
	}

	outbuff.write("\n}");
}

private void escaping_or_uuid2search(string in_text, ref OutBuffer outbuff)
{
	int count_s = 0;

	bool need_prepare = false;
	bool is_uuid = false;

	foreach(ch; in_text)
	{
		if(ch == '-')
		{
			count_s++;
			if(count_s == 4 && in_text.length > 36 && in_text.length < 48)
			{
				is_uuid = true;
				need_prepare = true;
				break;
			}
		}
		if(ch == '"' || ch == '\n' || ch == '\\' || ch == '\t')
		{
			need_prepare = true;
			break;
		}
	}

	bool fix_uuid_2_doc = false;

	// TODO: временная корректировка ссылок в org
	if(is_uuid == true)
	{
		if(in_text[0] == 'z' && in_text[1] == 'd' && in_text[2] == 'b' && in_text[3] == ':' && ((in_text[4] == 'd' && in_text[5] == 'e' && in_text[6] == 'p') || (in_text[4] == 'o' && in_text[5] == 'r' && in_text[6] == 'g')))
			fix_uuid_2_doc = true;
	}

	if(need_prepare)
	{
		int len = cast(uint) in_text.length;

		for(int i = 0; i < len; i++)
		{
			if(i >= len)
				break;

			char ch = in_text[i];

			if((ch == '"' || ch == '\\'))
			{
				outbuff.write('\\');
				outbuff.write(ch);
			} else if(ch == '\n')
			{
				outbuff.write("\\n");
			} else if(ch == '\t')
			{
				outbuff.write("\\t");
			} else
			{
				if(ch == '-' && is_uuid == true)
					outbuff.write('_');
				else
				{
					if(fix_uuid_2_doc)
					{
						if(i == 4)
							outbuff.write('d');
						else if(i == 5)
							outbuff.write('o');
						else if(i == 6)
							outbuff.write('c');
						else
							outbuff.write(ch);
					} else
						outbuff.write(ch);
				}
			}
		}
	} else
	{
		outbuff.write(in_text);
	}

}
