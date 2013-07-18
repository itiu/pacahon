module trioplax.mongodb.MongodbTripleStorage;

private
{
	import std.c.string;
	import std.datetime;
	import std.stdio;
	import std.string;
	import std.outbuffer;
	import std.conv;

	import core.stdc.stdio;
	import core.thread;

	import util.Logger;

	import trioplax.mongodb.ComplexKeys;

	import mongoc.bson_h;
	import mongoc.mongo_h;

	import pacahon.know_predicates;
	import pacahon.graph;

	import onto.doc_template;
	//	import onto.docs_base;

	import pacahon.context;
	import trioplax.mongodb.TripleStorage;
}

import core.vararg;

alias eo dtrace;

void eo(...)
{
}

Logger log;

static this()
{
	log = new Logger("pacahon", "log", "");
}

class TripleStorageMongoDBIterator: TLIterator
{
	mongo_cursor* cursor;
	byte[string] reading_predicates;
	bool is_query_all_predicates = false;
	bool is_get_all = false;
	bool is_get_all_reifed = false;

	this(mongo_cursor* _cursor)
	{
		cursor = _cursor;
	}

	this(mongo_cursor* _cursor, ref byte[string] _reading_predicates)
	{
		cursor = _cursor;
		reading_predicates = _reading_predicates;

		if(reading_predicates.length > 0)
		{
			byte* type_of_getting_field = (query__all_predicates in reading_predicates);

			if(type_of_getting_field !is null)
			{
				is_query_all_predicates = true;
				if(*type_of_getting_field == field.GET)
				{
					is_get_all = true;
				} else if(*type_of_getting_field == field.GET_REIFED)
				{
					is_get_all_reifed = true;
				}

			}
		}

	}

	~this()
	{
		if(cursor !is null)
		{
			mongo_cursor_destroy(cursor);
		}
	}

	int opApply(int delegate(ref Triple) dg)
	{
		if(cursor is null)
			return -1;

		int result = 0;

		string S;
		string P;
		string O;

		Triple[][FKeys] reif_triples;
		int count_of_reifed_data = 0;

		if(trace_msg[1007] == 1)
			log.trace("opApply:TripleStorageMongoDBIterator:cursor %x", cursor);

		if(trace_msg[1007] == 1)
			log.trace("opApply:TripleStorageMongoDBIterator:reading_predicates %s", reading_predicates);

		while(mongo_cursor_next(cursor) == MONGO_OK)
		{
			if(trace_msg[1007] == 1)
				log.trace("while(mongo_cursor_next(cursor) == MONGO_OK)");

			bson_iterator it;
			bson_iterator_init(&it, &cursor.current);

			short count_fields = 0;
			while(bson_iterator_next(&it))
			{
				//					// writeln ("it++");
				bson_type type = bson_iterator_type(&it);

				if(trace_msg[1007] == 1)
					log.trace("TripleStorageMongoDBIterator:next key, TYPE=%d", type);

				switch(type)
				{
					case bson_type.BSON_STRING:
					{
						string _name_key = fromStringz(bson_iterator_key(&it));

						if(trace_msg[1008] == 1)
							log.trace("TripleStorageMongoDBIterator:string:_name_key:%s", _name_key);

						// если не указанны требуемые предикаты, то берем какие были считанны
						byte* type_of_getting_field = null;
						if(is_query_all_predicates == false && reading_predicates.length > 0)
						{
							type_of_getting_field = (_name_key in reading_predicates);

							if(type_of_getting_field is null)
								break;
						}

						string _value = fromStringz(bson_iterator_string(&it));

						if(trace_msg[1009] == 1)
							log.trace("TripleStorageMongoDBIterator:_value:%s", _value);

						if(_name_key == "@")
						{
							S = _value;
						} else if(_name_key[0] != '_')
						{
							P = _name_key;
							O = _value;

							if(O !is null)
							{
								Triple tt000 = new Triple(S, P, O);

								result = dg(tt000);
								if(result)
									return -1;
							}
							//							}

							// проверим есть ли для этого триплета реифицированные данные
							if(is_get_all_reifed == true || type_of_getting_field !is null && *type_of_getting_field == field.GET_REIFED)
							{
								FKeys t3 = new FKeys(S, P, O);

								Triple[]* vv = t3 in reif_triples;
								if(vv !is null)
								{
									Triple[] r1_reif_triples = *vv;

									if(r1_reif_triples !is null && r1_reif_triples.length > 0)
									{
										Triple tt0 = new Triple(r1_reif_triples[0].S, "a", "rdf:Statement");

										result = dg(tt0);
										if(result)
											return 1;

										tt0 = new Triple(r1_reif_triples[0].S, "rdf:subject", S);

										result = dg(tt0);
										if(result)
											return 1;

										tt0 = new Triple(r1_reif_triples[0].S, "rdf:predicate", P);
										result = dg(tt0);
										if(result)
											return 1;

										tt0 = new Triple(r1_reif_triples[0].S, "rdf:object", O);
										result = dg(tt0);
										if(result)
											return 1;

										foreach(tt; r1_reif_triples)
										{
											// можно добавлять в список
											//											if(trace_msg[1010] == 1)
											//												log.trace("reif : %s", tt);

											result = dg(tt);
											if(result)
												return 1;
										}
									}
								}
							}

						}

						break;
					}

					case bson_type.BSON_ARRAY:
					{
						string _name_key = fromStringz(bson_iterator_key(&it));

						if(trace_msg[1008] == 1)
							log.trace("TripleStorageMongoDBIterator:string:_name_key:%s", _name_key);

						if(_name_key != "@" && _name_key[0] != '_')
						{

							// если не указанны требуемые предикаты, то берем какие были считанны
							byte* type_of_getting_field = null;
							if(is_query_all_predicates == false && reading_predicates.length > 0)
							{
								type_of_getting_field = (_name_key in reading_predicates);

								if(type_of_getting_field is null)
									break;
							}

							bson_iterator i_1;
							bson_iterator_subiterator(&it, &i_1);

							while(bson_iterator_next(&i_1))
							{
								switch(bson_iterator_type(&i_1))
								{
									case bson_type.BSON_STRING:
									{
										string A_value = fromStringz(bson_iterator_string(&i_1));

										if(A_value.length > 0)
										{
											Triple tt0 = new Triple(S, _name_key, A_value);
											result = dg(tt0);
											if(result)
												return 1;
										}
									}
									default:
									break;
								}

							}
						}
						break;
					}

					case bson_type.BSON_OBJECT:
					{
						string _name_key = fromStringz(bson_iterator_key(&it));

						if(trace_msg[1008] == 1)
							log.trace("TripleStorageMongoDBIterator:string:_name_key:%s", _name_key);

						// если не указанны требуемые предикаты, то берем какие были считанны
						byte* type_of_getting_field = null;
						if(is_query_all_predicates == false && reading_predicates.length > 0)
						{
							type_of_getting_field = (_name_key in reading_predicates);

							if(type_of_getting_field is null)
								break;
						}

						if(_name_key[0] == '_' && _name_key[1] == 'r' && _name_key[2] == 'e' && _name_key[3] == 'i')
						{
							string s_reif_parent_triple = S;
							string p_reif_parent_triple = _name_key[6 .. $];

							// это реифицированные данные, восстановим факты его образующие
							// добавим в список:
							//	_new_node_uid a fdr:Statement
							//	_new_node_uid rdf:subject [$S]
							//	_new_node_uid rdf:predicate [$_name_key[6..]]
							//	_new_node_uid rdf:object [?]

							Triple[] r_triples = new Triple[10];
							int last_r_triples = 0;

							//							if(trace_msg[1013] == 1)
							//								log.trace("TripleStorageMongoDBIterator:REIFFF _name_key:%s", _name_key);

							//							char* val = bson_iterator_value(&it);
							bson_iterator i_L1;
							bson_iterator_subiterator(&it, &i_L1);
							//							bson_iterator_init(&i_L1, val);

							while(bson_iterator_next(&i_L1))
							{
								switch(bson_iterator_type(&i_L1))
								{

									case bson_type.BSON_OBJECT:
									{
										count_of_reifed_data++; //???

										string reifed_data_subj = "_:R_" ~ text(count_of_reifed_data);
										//										log.trace("TripleStorageMongoDBIterator: # <, count_of_reifed_data=%s", reifed_data_subj);										

										string _name_key_L1 = fromStringz(bson_iterator_key(&i_L1));
										string o_reif_parent_triple = _name_key_L1;

										if(trace_msg[1014] == 1)
											log.trace("TripleStorageMongoDBIterator:_name_key_L1 %s", _name_key_L1);

										//										char* val_L2 = bson_iterator_value(&i_L1);

										//										log.trace("TripleStorageMongoDBIterator: val_L2 %s", fromStringz(val_L2));

										bson_iterator i_L2;
										//										bson_iterator_init(&i_L2, val_L2);
										bson_iterator_subiterator(&i_L1, &i_L2);

										//										log.trace("TripleStorageMongoDBIterator: # {");

										while(bson_iterator_next(&i_L2))
										{
											switch(bson_iterator_type(&i_L2))
											{
												case bson_type.BSON_STRING:
												{
													string _name_key_L2 = fromStringz(bson_iterator_key(&i_L2));

													if(trace_msg[1015] == 1)
														log.trace("TripleStorageMongoDBIterator:_name_key_L2=%s", _name_key_L2);

													string _name_val_L2 = fromStringz(bson_iterator_string(&i_L2));

													if(trace_msg[1016] == 1)
														log.trace("TripleStorageMongoDBIterator:_name_val_L2L=%s", _name_val_L2);

													//	r_triple.P = _name_key_L2;
													//	r_triple.O = _name_val_L2;
													//	r_triple.S = cast(immutable) reifed_data_subj;

													Triple r_triple = new Triple(reifed_data_subj, _name_key_L2, _name_val_L2);
													//													log.trace("++ triple %s", r_triple);

													if(last_r_triples >= r_triples.length)
														r_triples.length += 50;

													r_triples[last_r_triples] = r_triple;

													last_r_triples++;

													break;
												}

												case bson_type.BSON_ARRAY:
												{
													string _name_key_L2 = fromStringz(bson_iterator_key(&i_L2));

													//													val = bson_iterator_value(&i_L2);

													bson_iterator i_1;
													bson_iterator_subiterator(&i_L2, &i_1);
													//													bson_iterator_init(&i_1, val);

													while(bson_iterator_next(&i_1))
													{
														switch(bson_iterator_type(&i_1))
														{
															case bson_type.BSON_STRING:
															{
																string A_value = fromStringz(bson_iterator_string(&i_1));

																Triple r_triple = new Triple(reifed_data_subj, _name_key_L2,
																		A_value);

																if(last_r_triples >= r_triples.length)
																	r_triples.length += 50;

																r_triples[last_r_triples] = r_triple;

																last_r_triples++;
															}
															default:
															break;
														}

													}

													break;
												}

												default:
												break;
											}
										}

										//										log.trace("TripleStorageMongoDBIterator: # }");

										r_triples.length = last_r_triples;

										//										log.trace("TripleStorageMongoDBIterator: #9 last_r_triples=%d, _name_key_L1=[%s]", last_r_triples, cast(immutable) _name_key_L1);

										//										if (reif_triples is null)
										//											log.trace("TripleStorageMongoDBIterator: reif_triples is null");																					

										FKeys reifed_composite_key = new FKeys(s_reif_parent_triple, p_reif_parent_triple,
												o_reif_parent_triple);
										reif_triples[reifed_composite_key] = r_triples;

										//										log.trace("TripleStorageMongoDBIterator: #10 reifed_composite_key=%s", reifed_composite_key);

										break;
									}
									/*
									 case bson_type.bson_eoo:
									 {
									 char[] _name_val_L1 = fromStringz(bson_iterator_string(&i_L1));

									 if(trace_msg[0][18] == 1)
									 log.trace("getTriplesOfMask:bson_type.bson_eoo QQQ L1 VAL=%s", _name_val_L1);

									 r_triples.length = last_r_triples;
									 reif_triples[cast(immutable) _name_key_L1] = r_triples;

									 break;
									 }
									 */
									default:
									break;
								}

							}

						}

						break;
					}

					default:
						{
							if(trace_msg[1019] == 1)
							{
								string _name_key = fromStringz(bson_iterator_key(&it));
								//								log.trace("TripleStorageMongoDBIterator:def:_name_key:", _name_key);
							}
						}
					break;

				}
			}
		}

		//		log.trace("mongo_cursor_destroy(cursor)");

		mongo_cursor_destroy(cursor);
		cursor = null;

		return 0;
	}

}

class MongodbTripleStorage: TripleStorage
{
	string query_log_filename = "triple-storage-io";

	private long total_count_queries = 0;

	private char[] buff = null;
	private char* dbname = cast(char*) "pacahon";
	private char* docs_collection = cast(char*) "pacahon.simple";
	private char* search_collection = cast(char*) "pacahon.search";

	private bool[char[]] predicate_as_multiple;
	private bool[char[]] multilang_predicates;
	private bool[char[]] fulltext_indexed_predicates;

	private bool log_query = false;

	private mongo conn;

	this(string host, int port, string db_name)
	{
		dbname = cast(char*) db_name;
		docs_collection = cast(char*) (db_name ~ ".simple");

		log.trace("connect to mongodb... %s", (db_name ~ ".simple"));

		int limit_count_attempt = 10;

		int err = 0;

		while(limit_count_attempt > 1)
		{
			err = mongo_connect(&conn, cast(char*) toStringz(host), port);
			if(err == MONGO_OK)
			{
				break;
			} else
			{
				log.trace("failed to connect to mongodb, err=%s", mongo_error_str[mongo_get_error(&conn)]);
			}
			limit_count_attempt--;
			core.thread.Thread.sleep(dur!("seconds")(5));
		}
		if(err != MONGO_OK)
		{
			log.trace("failed to connect to mongodb, err=%s", mongo_error_str[mongo_get_error(&conn)]);
			throw new Exception("failed to connect to mongodb");
		}

		log.trace("connect to mongodb sucessful");
//		mongo_set_op_timeout(&conn, 1000);
	}

	int _tmp_hhh = 0;

	public void set_log_query_mode(bool on_off)
	{
		log_query = on_off;

	}

	public void define_predicate_as_multiple(string predicate)
	{
		predicate_as_multiple[predicate] = true;

		log.trace("TSMDB:define predicate [%s] as multiple", predicate);
	}

	public void define_predicate_as_multilang(string predicate)
	{
		multilang_predicates[predicate] = true;

		log.trace("TSMDB:define predicate [%s] as multilang", predicate);
	}

	public void set_fulltext_indexed_predicates(string predicate)
	{
		fulltext_indexed_predicates[predicate] = true;

		log.trace("TSMDB:set fulltext indexed predicate [%s]", predicate);
	}

	public bool f_trace_list_pull = true;

	public bool removeSubject(string s)
	{
		try
		{
			//			// writeln("remove ", s);

			bson cond;

			bson_init(&cond);
			_bson_append_string(&cond, "@", s);

			bson_finish(&cond);
			mongo_remove(&conn, docs_collection, &cond);

			bson_destroy(&cond);

			return true;
		} catch(Exception ex)
		{
			log.trace("ex! removeSubject %s", s);
			return false;
		}
	}

	public bool isExistSubject(string subject)
	{
		//		if(ts_mem !is null)
		//			return ts_mem.isExistSubject(subject);

		StopWatch sw;
		sw.start();

		bool res = false;

		bson query;
		bson fields;
		bson out_data;

		bson_init(&query);
		bson_init(&fields);

		if(subject !is null)
			_bson_append_string(&query, "@", subject);

		bson_finish(&query);
		bson_finish(&fields);

		if(mongo_find_one(&conn, docs_collection, &query, &fields, &out_data) == 0)
			res = true;

		bson_destroy(&fields);
		bson_destroy(&query);
		bson_destroy(&out_data);

		sw.stop();
		long t = cast(long) sw.peek().usecs;

		if(t > 500000)
		{
			log.trace("isExistSubject [%s], total time: %d[µs]", subject, t);
		}
		return res;
	}

	public bool removeTriple(string s, string p, string o)
	{
		//		log.trace("TripleStorageMongoDB:remove triple <" ~ s ~ "><" ~ p ~ ">\"" ~ o ~ "\"");

		if(s is null || p is null || o is null)
		{
			throw new Exception("remove triple:s is null || p is null || o is null");
		}

		bson query;
		bson fields;

		bson_init(&query);
		bson_init(&fields);

		_bson_append_string(&query, "@", s);
		_bson_append_string(&query, p, o);

		bson_finish(&query);
		bson_finish(&fields);

		mongo_cursor* cursor = mongo_find(&conn, docs_collection, &query, &fields, 1, 0, 0);

		if(mongo_cursor_next(cursor))
		{
			bson_iterator it;
			bson_iterator_init(&it, &cursor.current);
			switch(bson_iterator_type(&it))
			{
				case bson_type.BSON_STRING:
					log.trace("remove! string");
				break;

				case bson_type.BSON_ARRAY:
					log.trace("remove! array");
				break;

				default:
				break;
			}

		} else
		{
			throw new Exception(
					"remove triple <" ~ cast(string) s ~ "><" ~ cast(string) p ~ ">\"" ~ cast(string) o ~ "\": triple not found");
		}

		mongo_cursor_destroy(cursor);
		bson_destroy(&fields);
		bson_destroy(&query);

		{
			bson op;
			bson cond;

			bson_init(&cond);
			_bson_append_string(&cond, "@", s);

			//			if(p == HAS_PART)
			//			{
			//				bson_buffer_init(&bb);
			//				bson_buffer* sub = bson_append_start_object(&bb,
			//						"$pull");
			//				bson_append_int(sub, p.ptr, 1);
			//				bson_append_finish_object(sub);
			//			} else
			//			{
			bson_init(&op);
			_bson_append_start_object(&op, "$unset");
			_bson_append_int(&op, p, 1);
			bson_append_finish_object(&op);
			//			}

			bson_finish(&op);
			bson_finish(&cond);

			mongo_update(&conn, docs_collection, &cond, &op, 0);

			bson_destroy(&cond);
			bson_destroy(&op);
		}

		//		if(cache_query_result !is null)
		//			cache_query_result.removeTriple(s, p, o);

		//		if(log_query == true)
		//			logging_query("REMOVE", s, p, o, null);

		return true;
	}

	public void addTripleToReifedData(Triple reif, string p, string o, byte lang)
	{
		//  {SUBJECT:[$reif_subject]}{$set: {'_reif_[$reif_predicate].[$reif_object].[$p]' : [$o]}});
		Triple newtt = new Triple(reif.S, "_reif_" ~ reif.P ~ "." ~ reif.O ~ "." ~ p, o, lang);

		addTriple(newtt);
	}

	private void subject2basic_mongo_doc(Subject graph, bson* doc, string reifed_p = null, string reifed_o = null)
	{
		//		// writeln ("#1");

		if(reifed_p is null)
		{
			_bson_append_start_object(doc, "$set");
			_bson_append_string(doc, "@", graph.subject);
		}

		foreach(pp; graph.getPredicates)
		{
			if(pp.count_objects > 0)
			{
				string pname = pp.predicate;

				//				dtrace ("&2 pname=", pname);

				string pd = pname;
				if(pp.count_objects > 1)
				{
					_bson_append_start_array(doc, pname);
					pd = "";
				}

				foreach(oo; pp.getObjects)
				{
					string oo_as_text;

					if(oo.type == OBJECT_TYPE.LITERAL || oo.type == OBJECT_TYPE.URI)
						oo_as_text = oo.literal;
					else
						oo_as_text = oo.subject.subject;

					if(oo.lang == _NONE)
					{
						_bson_append_string(doc, pd, oo_as_text);
					} else if(oo.lang == _RU)
					{
						_bson_append_string(doc, pd, oo_as_text ~ "@ru");
					} else if(oo.lang == _EN)
					{
						_bson_append_string(doc, pd, oo_as_text ~ "@en");
					}

					if(oo.reification !is null)
					{
						//		// writeln ("reif!!! oo.reification=", oo.reification, ", pp.predicate=", pp.predicate, ", oo_as_text=", oo_as_text);
						_bson_append_start_object(doc, "_reif_" ~ pp.predicate);
						_bson_append_start_object(doc, oo_as_text);

						subject2basic_mongo_doc(oo.reification, doc, pp.predicate, oo_as_text);

						bson_append_finish_object(doc); // } finish reif o					
						bson_append_finish_object(doc); // } finish reif p					
					}

				}

				if(pp.count_objects > 1)
				{
					bson_append_finish_object(doc); // ] finish array					
				}

			}
		}
		if(reifed_p is null)
		{
			bson_append_finish_object(doc); // finish document
		}

	}

	public void storeSubject(Subject graph, Context server_context)
	{
		// основной цикл по добавлению фактов в хранилище из данного субьекта 
		if(graph.count_edges > 0)
		{
			bson document;
			bson cond;

			bson_init(&cond);
			_bson_append_string(&cond, "@", graph.subject);
			bson_finish(&cond);

			bson_init(&document);
			subject2basic_mongo_doc(graph, &document);
			bson_finish(&document);

			//// writeln ("@----------------------------------------------------");
			//// writeln (bson_to_string(&cond));
			//// writeln ("@1");
			mongo_update(&conn, docs_collection, &cond, &document, MONGO_UPDATE_UPSERT);
			//// writeln ("@2");
			bson_destroy(&document);

			bson_destroy(&cond);
		}
		return;
	}

	public int addTriple(Triple tt, bool isReification = false)
	{
		StopWatch sw;
		sw.start();

		bson op;
		bson cond;

		bson_init(&cond);
		_bson_append_string(&cond, "@", tt.S);
		bson_finish(&cond);

		bson_init(&op);

		if((tt.P in predicate_as_multiple) !is null)
		{
			_bson_append_start_object(&op, "$addToSet");

			if(tt.lang == _NONE)
				_bson_append_string(&op, tt.P, tt.O);
			else if(tt.lang == _RU)
				_bson_append_string(&op, tt.P, tt.O ~ "@ru");
			if(tt.lang == _EN)
				_bson_append_string(&op, tt.P, tt.O ~ "@en");

			bson_append_finish_object(&op);
		} else
		{
			if(tt.lang == _NONE)
			{
				_bson_append_start_object(&op, "$set");
				_bson_append_string(&op, tt.P, tt.O);
			} else if(tt.lang == _RU)
			{
				_bson_append_start_object(&op, "$addToSet");
				_bson_append_string(&op, tt.P, tt.O ~ "@ru");
			} else if(tt.lang == _EN)
			{
				_bson_append_start_object(&op, "$addToSet");
				_bson_append_string(&op, tt.P, tt.O ~ "@en");
			}

			bson_append_finish_object(&op);
		}

		// добавим данные для полнотекстового поиска
		if((tt.P in fulltext_indexed_predicates) !is null || isReification == true)
		{
			char[] l_o = cast(char[]) toLower(tt.O);

			if(l_o.length > 2)
			{
				_bson_append_start_object(&op, "$addToSet");

				for(int ic = 0; ic < l_o.length; ic++)
				{
					if((l_o[ic] == '-' && ic == 0) || l_o[ic] == '"' || l_o[ic] == '\'' || (l_o[ic] == '@' && (l_o.length - ic) > 4) || l_o[ic] == '\'' || l_o[ic] == '\\' || l_o[ic] == '.' || l_o[ic] == '+')
						l_o[ic] = ' ';
				}

				char[][] aaa;
				aaa = split(l_o, " ");

				_bson_append_start_object(&op, "_keywords");
				_bson_append_start_array(&op, "$each");

				_bson_append_string(&op, "", cast(string) l_o);
				foreach(aa; aaa)
				{
					if(aa.length > 2)
					{
						_bson_append_string(&op, "", cast(string) aa);
					}
				}

				bson_append_finish_object(&op);

				bson_append_finish_object(&op);
				bson_append_finish_object(&op);
			}
		}

		bson_finish(&op);
		mongo_update(&conn, docs_collection, &cond, &op, 1);

		bson_destroy(&cond);
		bson_destroy(&op);

		sw.stop();
		long t = cast(long) sw.peek().usecs;

		if(t > 300 || trace_msg[1042] == 1)
		{
			log.trace("total time add triple: %d[µs]", t);
		}

		return 0;
	}

	public string getNextSubject(ref mongo_cursor* cursor)
	{
		if(cursor is null)
		{
			bson query;
			bson fields;

			bson_init(&query);
			bson_init(&fields);

			_bson_append_string(&fields, "@", "1");

			bson_finish(&query);
			bson_finish(&fields);

			cursor = mongo_find(&conn, docs_collection, &query, &fields, 0, 0, 0);
			if(cursor is null)
			{
				log.trace("ex! getSubjects, err=%s", mongo_error_str[mongo_get_error(&conn)]);
				throw new Exception("getSubjects, err=" ~ mongo_error_str[mongo_get_error(&conn)]);
			}

			bson_destroy(&fields);
			bson_destroy(&query);
		}

		if(mongo_cursor_next(cursor) == MONGO_OK)
		{
			bson_iterator it;
			bson_iterator_init(&it, &cursor.current);

			short count_fields = 0;
			while(bson_iterator_next(&it))
			{
				bson_type type = bson_iterator_type(&it);

				switch(type)
				{
					case bson_type.BSON_STRING:
					{
						string _value = fromStringz(bson_iterator_string(&it));
						return _value;
					}
					default:
				}
			}
		}
		return null;
	}

	public TLIterator getTriples(string s, string p, string o, int MAX_SIZE_READ_RECORDS = 1000, int OFFSET = 0)
	{
		//		StopWatch sw;
		//		sw.start();

		total_count_queries++;

		bool f_is_query_stored = false;

		bson query;
		bson fields;

		bson_init(&query);
		bson_init(&fields);

		if(s !is null)
		{
			_bson_append_string(&query, "@", s);
		}

		if(p !is null && o !is null)
		{
			_bson_append_string(&query, p, o);
		}

		//			bson_append_int(&bb2, cast(char*)"@", 1);
		//			if (p !is null)
		//			{
		//				bson_append_stringA(&bb2, p, cast(char[]) "1");
		//			}

		bson_finish(&query);
		bson_finish(&fields);

		mongo_cursor* cursor = mongo_find(&conn, docs_collection, &query, &fields, MAX_SIZE_READ_RECORDS, OFFSET, 0);
		if(cursor is null)
		{
			log.trace("ex! getTriples:mongo_find, err=%s", mongo_error_str[mongo_get_error(&conn)]);
			throw new Exception("getTriples:mongo_find, err=" ~ mongo_error_str[mongo_get_error(&conn)]);
		}

		TLIterator it;

		it = new TripleStorageMongoDBIterator(cursor);

		bson_destroy(&fields);
		bson_destroy(&query);

		return it;
	}

	public TLIterator getTriplesOfMask(ref Triple[] mask_triples, byte[string] reading_predicates,
			int MAX_SIZE_READ_RECORDS = 1000)
	{
		if(mask_triples !is null && mask_triples.length == 2 && mask_triples[0].S !is null && mask_triples[0].P is null && mask_triples[0].O is null && mask_triples[1].S is null && mask_triples[1].P !is null && mask_triples[1].O !is null)
		{
			mask_triples[0].P = mask_triples[1].P;
			mask_triples[0].O = mask_triples[1].O;
			mask_triples.length = 1;
			//			log.trace("!!!");
		}

		int count_of_reifed_data = 0;

		StopWatch sw;
		sw.start();

		if(trace_msg[1001] == 1)
			log.trace("getTriplesOfMask START mask_triples.length=%d\n", mask_triples.length);

		try
		{
			bson query;
			bson fields;

			if(mask_triples.length == 0)
			{
				if(trace_msg[1022] == 1)
					log.trace("getTriplesOfMask:mask_triples.length == 0, return");

				return null;
			}

			bson_init(&query);
			bson_init(&fields);

			//			bson_append_stringA(&bb2, cast(char[]) "@", cast(char[]) "1");

			for(short i = 0; i < mask_triples.length; i++)
			{
				string s = mask_triples[i].S;
				string p = mask_triples[i].P;
				string o = mask_triples[i].O;

				if(trace_msg[1002] == 1)
				{
					log.trace("getTriplesOfMask i=%d <%s><%s><%s>", i, s, p, o);
					if(o is null)
						log.trace("o is null");
				}

				if(s !is null && s.length > 0)
				{
					add_to_query("@", s, &query);
				}

				if(p !is null && p == "query:fulltext")
				{
					add_fulltext_to_query(o, &query);
				} else if(p !is null /*&& o !is null && o.length > 0*/)
				{
					add_to_query(p, o, &query);
				}
			}

			reading_predicates["@"] = field.GET;

			//			int count_readed_fields = 0;
			//			for(int i = 0; i < reading_predicates.keys.length; i++)
			//			{
			//				char[] field_name = cast(char[]) reading_predicates.keys[i];
			//				byte field_type = reading_predicates.values[i];
			//				bson_append_stringA(&bb2, cast(char[]) field_name, cast(char[]) "1");
			//
			//				if(trace_msg[0][3] == 1)
			//					log.trace("getTriplesOfMask:set out field:%s", field_name);
			//
			//				if(field_type == _GET_REIFED)
			//				{
			//					bson_append_stringA(&bb2, cast(char[]) "_reif_" ~ field_name, cast(char[]) "1");
			//
			//					if(trace_msg[0][4] == 1)
			//						log.trace("getTriplesOfMask:set out field:%s", "_reif_" ~ field_name);
			//				}
			//
			//				count_readed_fields++;
			//			}

			bson_finish(&query);
			bson_finish(&fields);

			if(trace_msg[1005] == 1)
			{
				char[] ss = bson_to_string(&query);
				log.trace("getTriplesOfMask:QUERY:\n %s", ss);
				//				log.trace("---- readed fields=%s", reading_predicates);
			}

			StopWatch sw0;
			sw0.start();

			mongo_cursor* cursor;

			if(trace_msg[1005] == 1)
			{
				log.trace("start query on mongo");
			}

			cursor = mongo_find(&conn, docs_collection, &query, &fields, MAX_SIZE_READ_RECORDS, 0, 0);
			if(cursor is null)
			{
				log.trace("ex! getTriplesOfMask:mongo_find, err=%s", mongo_error_str[mongo_get_error(&conn)]);
				throw new Exception("getTriplesOfMask:mongo_find, err=" ~ mongo_error_str[mongo_get_error(&conn)]);
			}

			sw0.stop();

			if(trace_msg[1005] == 1)
			{
				log.trace("end query on mongo");
			}

			long t0 = cast(long) sw0.peek().usecs;

			if(t0 > 50000)
			{
				char[] ss = bson_to_string(&query);
				log.trace("getTriplesOfMask: QUERY:\n %s", ss);
				log.trace("getTriplesOfMask: mongo_find: %d[µs]", t0);
			}

			TLIterator it;

			it = new TripleStorageMongoDBIterator(cursor, reading_predicates);

			bson_destroy(&fields);
			bson_destroy(&query);

			return it;
		} catch(Exception ex)
		{
			log.trace("@exception:%s", ex.msg);
			throw ex;
		}

	}

	private void add_to_query(string field_name, string field_value, bson* bb)
	{
		if(trace_msg[1030] == 1)
			log.trace("add_to_query ^^^ field_name = %s, field_value=%s", field_name, field_value);

		bool field_is_multilang = (field_name in multilang_predicates) !is null;

		if(field_value !is null && (field_value[0] == '"' && field_value[1] == '[' || field_value[0] == '['))
		{
			if(field_value[0] == '[')
				field_value = field_value[1 .. field_value.length - 1];
			else
				field_value = field_value[2 .. field_value.length - 2];

			string[] values = split(field_value, ",");
			if(values.length > 0)
			{
				_bson_append_start_array(bb, "$or");
				foreach(val; values)
				{
					_bson_append_start_object(bb, "");

					if(field_is_multilang)
						_bson_append_string(bb, field_name, val ~ "@ru");
					else
						_bson_append_string(bb, field_name, val);

					bson_append_finish_object(bb);
				}
				bson_append_finish_object(bb);
			}
		} else
		{
			if(field_is_multilang)
				_bson_append_string(bb, field_name, field_value ~ "@ru");
			else
				_bson_append_string(bb, field_name, field_value);
		}

		if(trace_msg[1031] == 1)
			log.trace("add_to_query return");
	}

	private bool bson2graph(ref GraphCluster res, bson_iterator* it, ref Subject ss, ref string allfields,
			ref string[string] fields, bool function(ref string id) authorizer, bool only_id, string predicate_array = null)
	{
		while(bson_iterator_next(it))
		{
			bson_type type = bson_iterator_type(it);

			switch(type)
			{
				
				case bson_type.BSON_STRING:
				{
					string name_key;

					if(predicate_array !is null)
						name_key = predicate_array;
					else
						name_key = fromStringz(bson_iterator_key(it)).dup;

					//					writeln("prepare_bson @3 name_key:", name_key);
					string value = fromStringz(bson_iterator_string(it)).dup;

					if(name_key == "@")
					{
						//						writeln("prepare_bson @4, value:", value);
//						if(authorizer(value) == true)
							ss.subject = value;
//						else
//							return false;
					} else if(only_id == false)
					{

						if(allfields !is null)
							ss.addPredicate(name_key, value);
						else
						{
							string ff = fields.get(name_key, null);

							if(ff !is null)
							{
								ss.addPredicate(name_key, value);
							}
						}
					}
					break;
				}
				
				
				case bson_type.BSON_ARRAY:
				{
					string name_key = fromStringz(bson_iterator_key(it)).dup;

					bson_iterator it_1;
					bson_iterator_subiterator(it, &it_1);

					bson2graph(res, &it_1, ss, allfields, fields, authorizer, only_id, name_key);

					break;
				}
				case bson_type.BSON_OBJECT:
				{
					string name_key = fromStringz(bson_iterator_key(it)).dup;
					if(name_key[0] == '_' && name_key[1] == 'r' && name_key[2] == 'e' && name_key[3] == 'i')
					{
						//						writeln("prepare_bson @10");

						string p_reif = name_key[6 .. $];

						if(allfields == "reif" || fields.get(p_reif, "") == "reif")
						{

							string s_reif = "_:R_" ~ text(res.length + 1);

							bson_iterator it_1;
							bson_iterator_subiterator(it, &it_1);

							while(bson_iterator_next(&it_1))
							{
								//								writeln("prepare_bson @11");
								bson_type type_1 = bson_iterator_type(&it_1);

								switch(type_1)
								{
									case bson_type.BSON_OBJECT:
									{
										Subject ss_reif = new Subject();
										//										writeln("prepare_bson @12");
										string o_reif = fromStringz(bson_iterator_key(&it_1)).dup;
										ss_reif.subject = s_reif;

										ss_reif.addPredicate(rdf__type, rdf__Statement);
										ss_reif.addPredicate(rdf__subject, ss.subject);
										ss_reif.addPredicate(rdf__predicate, p_reif);
										ss_reif.addPredicate(rdf__object, o_reif);

										bson_iterator it_2;
										bson_iterator_subiterator(&it_1, &it_2);

										string mallfield = "*";

										bson2graph(res, &it_2, ss_reif, mallfield, fields, authorizer, only_id);

										res.addSubject(ss_reif);
									}

									default:
									break;
								}
							}
						}
					}
					break;
				}

				default:
				break;

			}
		}
		return true;
	}

	public void get(ref GraphCluster res, bson* query, ref string[string] fields, int render,
			bool function(ref string id) authorizer)
	{
		try
		{
			string mostAllFields = fields.get("*", null);
			bson b_fields;

			bson_init(&b_fields);
			bson_finish(&b_fields);

			mongo_cursor* cursor;

			cursor = mongo_find(&conn, docs_collection, query, &b_fields, 10000, 0, 0);

			if(cursor is null)
			{
				log.trace("ex! get:mongo_find, err=%s", mongo_error_str[mongo_get_error(&conn)]);
				throw new Exception("get:mongo_find, err=" ~ mongo_error_str[mongo_get_error(&conn)]);
			}

			auto count_subj = 0;
			bson_iterator it;
			while(mongo_cursor_next(cursor) == MONGO_OK)
			{				
				bson_iterator_init(&it, &cursor.current);

				Subject ss = new Subject();
				
				bool isOk = false;
				
				if(count_subj < render)
					isOk = bson2graph(res, &it, ss, mostAllFields, fields, authorizer, false);
				else
					isOk = bson2graph(res, &it, ss, mostAllFields, fields, authorizer, true);

				if (isOk)
					res.addSubject(ss);
				
				count_subj ++;
			}
//	!!!		mongo_cursor_destroy(&cursor);
		} catch(Exception ex)
		{
			log.trace("@exception:%s", ex.msg);
			throw ex;
		}
	}

}
