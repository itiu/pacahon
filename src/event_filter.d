// TODO - event:when = before

module pacahon.command.event_filter;

import std.stdio;
import std.string;
import std.conv;
import std.math;
import std.exception;

private import pacahon.graph;
private import pacahon.thread_context;

private import trioplax.triple;
private import trioplax.TripleStorage;
private import trioplax.mongodb.TripleStorageMongoDB;

private import trioplax.Logger;
private import pacahon.know_predicates;

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
		string subject_type = subject.getObject("a");

		if(ef.getObject(event__subject_type) == subject.getObject("a"))
		{
			if(ef.getObject(event__when) == "after")
			{
				string condition = ef.getObject (event__condition);
				
//				writeln("condition= ", condition);
				
				bool res_cond = true;
				
				if (condition !is null)
				{
					res_cond = eval(condition, subject);
				}
				
				try
				{
					writeln("EVENT! see ", ef.subject, " subject[", subject.subject, "].type = ", subject_type);

					string autoremove = ef.getObject(event__autoremove);

					if(autoremove !is null && autoremove == "yes")
					{
						// удалить фильтр из базы и из памяти
					}
				} catch(Exception ex)
				{
					log.trace("ex! %s processed_events: %s", ex.msg, ef.subject);
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

		string[] tokens = split(expr, " ");

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
		
		if (tokens[1] == "==")
			return A == B;
	}

	return false;
}