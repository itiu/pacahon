module pacahon.command.event_filter;

import std.stdio;
import std.string;
import std.conv;
import std.math;
import std.exception;

private import pacahon.graph;
private import pacahon.thread_context;

private import trioplax.Logger;

Logger log;

static this()
{
	log = new Logger("pacahon", "log", "event-filter");
}

void processed_events(Subject subject, string type)
{
	writeln("info:processed_events ", type, ":", subject);

}

bool eval(string expr, Subject data)
{
	expr = strip(expr);

	writeln(expr);

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

		writeln(A, tokens[1], B);
		//	return Color(expr);
	}

	return true;
}