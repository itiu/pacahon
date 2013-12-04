// TODO - event:when = before

module pacahon.event_filter;

private import std.stdio;
private import std.string;
private import std.conv;
private import std.math;
private import std.exception;
private import std.datetime;
private import std.uuid;
private import std.array: appender;
private import std.regex;

private import ae.utils.container;

private import util.logger;
private import util.utils;
private import util.oi;
private import pacahon.know_predicates;
private import pacahon.graph;
private import pacahon.context;

logger log;

static this()
{
	log = new logger("pacahon", "log", "event-filter");
}

void load_events(Context context)
{
//	TLIterator it = context.ts.getTriples(null, rdf__type, event__Event);
//	foreach(triple; it)
//	{
//		context.event_filters.addTriple(triple.S, triple.P, triple.O, triple.lang);
//	}

//	delete (it);
	log.trace("loaded (%d) filter(s)", context.event_filters.length);
}

void processed_events(Subject subject, string type, Context context)
{
	//writeln("info:processed_events ", type, ":", subject);

	foreach(ef; context.event_filters.getArray)
	{
		string to = ef.getFirstLiteral(event__to);

		if(to is null || to.length < 2)
		{
			//log.trace("filter [%s] skipped, invalis gateway [%s]", ef.subject, to);
			continue;
		}

		Predicate subject_types = subject.getPredicate("a");
		//writeln ("subject_types.objects_of_value=",subject_types.objects_of_value);

		string filter_type = ef.getFirstLiteral(event__subject_type);

		if(subject_types.isExistLiteral(filter_type))
		{
			if(ef.getFirstLiteral(event__when) == "after")
			{
				string condition = ef.getFirstLiteral(event__condition);

				//writeln("condition= ", condition);

				bool res_cond = false;

				if(condition !is null)
				{
					res_cond = eval(condition, subject);
				}

				if(res_cond == true)
				{
					try
					{
//						writeln("EVENT! see ", ef.subject, " subject[", subject.subject, "].type = ",
//								subject_types.objects_of_value);

						Predicate p_template = ef.getPredicate(event__msg_template);

						if(p_template !is null)
						{
							foreach(p_object ; p_template.getObjects())
							{
								string msg_template = p_object.literal;

								if(msg_template !is null)
								{
									string r;

									auto rg = regex("`[^`]+`", "g");

									StopWatch sw;
									sw.start();

									auto m2 = match(msg_template, rg);

									string[string] vars;
									string[] list_vars = new string[16];

									int i = 0;
									foreach(c; m2)
									{
										string rrr = c.hit[1 .. $ - 1];

										list_vars[i] = "?";

										if((rrr in vars) is null)
										{
											if(rrr[0] == '$')
											{
												UUID new_id = randomUUID();
												list_vars[i] = new_id.toString ();
												vars[rrr] = list_vars[i];
											} else
											{
												// это предикат или субьект из изменяемого субьекта
												string predicat_name;
												string predicat_value;
												string regex0;

												// проверим, есть ли для него фильтр
												int start_pos_regex = cast(uint)std.string.indexOf(rrr, '/');
												if(start_pos_regex > 0)
												{
													predicat_name = rrr[0 .. start_pos_regex];
													regex0 = rrr[start_pos_regex + 1 .. $ - 1];

													if(predicat_name == "@")
														predicat_value = subject.subject;
													else
														predicat_value = subject.getFirstLiteral(predicat_name);

													auto rg1 = regex(regex0);
													auto m3 = match(predicat_value, rg1);

													auto _c = m3.captures;
													predicat_value = _c["var"];
												} else
												{
													predicat_name = rrr;
													predicat_value = subject.getFirstLiteral(predicat_name);
												}

												list_vars[i] = predicat_value;
											}
										} else
										{
											list_vars[i] = vars[rrr];
										}

										i++;
									}
									list_vars.length = i;

									r = replace(msg_template, rg, "%s");
									//							writeln (r);

									auto writer = appender!string(); // --format
									formattedWrite(writer, r, list_vars);
									//						writeln(writer.data);

									//	сообщение сформированно, отправляем согласно event:to	
									Set!OI gateways = context.get_gateways (to); 
									if(gateways.size > 0)
									{
										foreach (gateway; gateways.items)
										{
											gateway.send(writer.data);
											gateway.reciev();
										}	
									} else
									{
										log.trace("filter [%s] skipped, for gateway [%s] not found config", ef.subject,
												to);
									}

									//						sw.stop();
									//						long t = cast(long) sw.peek().usecs;
									//						writeln("regex time:", t, ", d:", t / count, ", cps:", 1_000_000 / (t / count));

								}
							}
						}

						string autoremove = ef.getFirstLiteral(event__autoremove);

						if(autoremove !is null && autoremove == "yes")
						{
							// удалить фильтр из базы и из памяти
						}
					} catch(Exception ex)
					{
						log.trace("ex! processed_events: %s, info %s", ef.subject, ex.msg);
					}
				}
			}
		}
	}

}

bool eval(string expr, Subject data)
{
	expr = strip(expr);

	//	writeln(expr);

	static int findOperand(string s, string op1)
	{
		int parens = 0;
		foreach_reverse(p, c; s)
		{
			char c2 = 0;

			if(p > 0)
				c2 = s[p - 1];

			if((c == op1[1] && c2 == op1[0]) && parens == 0)
				return cast(uint)(p - 1);

			else if(c == ')')
				parens++;
			else if(c == '(')
				parens--;
		}
		return -1;
	}

	// [&&]
	// [||]

	int p1 = findOperand(expr, "&&");
	int p2 = findOperand(expr, "||");

	if(p1 >= 0)
		return eval(expr[0 .. p1], data) && eval(expr[p1 + 2 .. $], data);

	if(p2 >= 0)
		return eval(expr[0 .. p2], data) || eval(expr[p2 + 2 .. $], data);

	if(expr.length > 2 && expr[0] == '(' && expr[$ - 1] == ')')
		return eval(expr[1 .. $ - 1], data);

	// [==] [!=]

	if(data !is null)
	{
		string A, B;

		string[] tokens = std.string.split(expr, " ");

		if(tokens.length != 3)
			return false;

		if(tokens[0][0] == '\'' || tokens[0][0] == '"')
		{
			// это строка
			A = tokens[0][1 .. $ - 1];
		} else
		{
			// нужно найти данный предикат tokens[0] в data и взять его значение
			A = data.getFirstLiteral(tokens[0]);
		}

		if(tokens[2][0] == '\'' || tokens[2][0] == '"')
		{
			// это строка
			B = tokens[2][1 .. $ - 1];
		} else
		{
			// нужно найти данный предикат tokens[1] в data и взять его значение
			B = data.getFirstLiteral(tokens[2]);
		}

		//		writeln("[", A, tokens[1], B, "]");

		if(tokens[1] == "==")
			return A == B;
	}

	return false;
}