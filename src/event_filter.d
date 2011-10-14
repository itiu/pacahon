// TODO - event:when = before

module pacahon.command.event_filter;

import std.stdio;
import std.string;
import std.conv;
import std.math;
import std.exception;
private import std.datetime;

private import pacahon.graph;
private import pacahon.thread_context;

private import trioplax.triple;
private import trioplax.TripleStorage;
private import trioplax.mongodb.TripleStorageMongoDB;

private import trioplax.Logger;
private import pacahon.know_predicates;

private import fred;

import std.array: appender;
//private import std.format;
private import pacahon.utils;

private import tango.util.uuid.NamespaceGenV5;
private import tango.util.digest.Sha1;
private import tango.util.uuid.RandomGen;
private import tango.math.random.Twister;

private import pacahon.zmq_connection;

Logger log;

static this()
{
	log = new Logger("pacahon", "log", "event-filter");
}

void load_events(ThreadContext server_thread)
{
	TLIterator it = server_thread.ts.getTriples(null, "a", event__Event);
	foreach(triple; it)
		server_thread.event_filters.addTriple(triple.S, triple.P, triple.O, triple.lang);

	log.trace("loaded (%d) filter(s)", server_thread.event_filters.length);
}

void processed_events(Subject subject, string type, ThreadContext server_thread)
{
	//	writeln("info:processed_events ", type, ":", subject);

	foreach(ef; server_thread.event_filters.graphs_of_subject.values)
	{
		string to = ef.getObject(event__to);

		if(to is null || to.length < 2)
		{
			log.trace("filter [%s] skipped, invalis gateway [%s]", ef.subject, to);
			continue;
		}

		string subject_type = subject.getObject("a");

		if(ef.getObject(event__subject_type) == subject_type)
		{
			if(ef.getObject(event__when) == "after")
			{
				string condition = ef.getObject(event__condition);

				//				writeln("condition= ", condition);

				bool res_cond = true;

				if(condition !is null)
				{
					res_cond = eval(condition, subject);
				}

				try
				{
					writeln("EVENT! see ", ef.subject, " subject[", subject.subject, "].type = ", subject_type);

					Predicate* p_template = ef.getEdge(event__msg_template);

					if(p_template !is null)
					{
						for(int i = 0; i < p_template.count_objects; i++)
						{
							Objectz p_object = p_template.objects[i];

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

									if(rrr[0] == '@')
									{
										if((rrr in vars) is null)
										{
											Twister rnd;
											rnd.seed;
											UuidGen rndUuid = new RandomGen!(Twister)(rnd);
											Uuid generated = rndUuid.next;
											list_vars[i] = cast(string) generated.toString;
											vars[rrr] = list_vars[i];
										} else
										{
											list_vars[i] = vars[rrr];
										}
									} else
									{
										// это предикат из изменяемого субьекта
										string predicat_name;
										string predicat_value;
										string regex0;

										// проверим, есть ли для него фильтр
										int start_pos_regex = std.string.indexOf(rrr, '/');
										if(start_pos_regex > 0)
										{
											predicat_name = rrr[0 .. start_pos_regex];
											regex0 = rrr[start_pos_regex + 1 .. $ - 1];

											auto rg1 = regex(regex0);
											predicat_value = subject.getObject(predicat_name);
											auto m3 = match(predicat_value, rg1);

											auto c = m3.captures;
											predicat_value = c["var"];
										} else
										{
											predicat_name = rrr;
											predicat_value = subject.getObject(predicat_name);
										}

										list_vars[i] = predicat_value;
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

								ZmqConnection gateway = server_thread.getGateway(to);

								if(gateway !is null)
								{
									gateway.send(writer.data);
									string res = gateway.reciev();
								} else
								{
									log.trace("filter [%s] skipped, for gateway [%s] not found config", ef.subject, to);
								}

								//						sw.stop();
								//						long t = cast(long) sw.peek().usecs;
								//						writeln("regex time:", t, ", d:", t / count, ", cps:", 1_000_000 / (t / count));

							}
						}
					}

					string autoremove = ef.getObject(event__autoremove);

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
				return p - 1;

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
			A = data.getObject(tokens[0]);
		}

		if(tokens[2][0] == '\'' || tokens[2][0] == '"')
		{
			// это строка
			B = tokens[2][1 .. $ - 1];
		} else
		{
			// нужно найти данный предикат tokens[1] в data и взять его значение
			B = data.getObject(tokens[2]);
		}

		//		writeln("[", A, tokens[1], B, "]");

		if(tokens[1] == "==")
			return A == B;
	}

	return false;
}