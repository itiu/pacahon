module search.vel;

// VEDA EXPRESSION LANG

private
{
	import std.string;
	import std.array;
	import std.stdio;
	import std.conv;
	import std.datetime;
	import std.json;
	import std.outbuffer;
	import std.c.string;
	
	import util.utils;
	
	import pacahon.graph;
}

//  expression
//  "==", "!=" 
//  "=*" : полнотекстовый поиск
//  "=+" : полнотекстовый поиск в реификации
//  "&&", "||", 
//  ">", "<", ">=", "<=", 
//  "->" : переход по ссылке на другой документ 

protected bool delim(char c)
{
	return c == ' ' || c == '	' || c == '\r' || c == '\n';
}

private string is_op(string c)
{
	//    writeln (c);

	if(c.length == 1)
	{
		if(c[0] == '>')
			return ">";
		if(c[0] == '<')
			return "<";
	} else if(c.length == 2)
	{
		if(c[0] == '>' && c[1] != '=')
			return ">";

		if(c[0] == '<' && c[1] != '=')
			return "<";

		if(c == ">=" || c == "<=" || c == "==" || c == "!=" || c == "=*" || c == "=+" || c == "->" || c == "||" || c == "&&")
			return c;
	}
	return null;
}

private int priority(string op)
{
	if(op == "<" || op == "<=" || op == ">" || op == "=>")
		return 4;

	if(op == "==" || op == "!=" || op == "=*" || op == "=+" || op == "->")
		return 3;

	if(op == "&&")
		return 2;

	if(op == "||")
		return 1;

	return -1;
}

private void process_op (ref stack!TTA st, string op) 
{
	TTA r = st.popBack();
	TTA l = st.popBack();
	
//	writeln ("process_op:op[", op, "], L:", l, ", R:", r);
	switch (op) 
	{
		case "<":  st.pushBack (new TTA (op, l, r));  break;
		case ">":  st.pushBack (new TTA (op, l, r));  break;
		case "==":  st.pushBack (new TTA (op, l, r));  break;
		case "!=":  st.pushBack (new TTA (op, l, r));  break;
		case "=*":  st.pushBack (new TTA (op, l, r));  break;
		case "=+":  st.pushBack (new TTA (op, l, r));  break;
		case "->":  st.pushBack (new TTA (op, l, r));  break;
		case ">=":  st.pushBack (new TTA (op, l, r));  break;
		case "<=":  st.pushBack (new TTA (op, l, r));  break;
		case "||":  st.pushBack (new TTA (op, l, r));  break;
		case "&&":  st.pushBack (new TTA (op, l, r));  break;
		default:
	}
}

//int g_count = 0;
class TTA
{
	string op;

	TTA L;
	TTA R;
	int count = 0;

	this(string _op, TTA _L, TTA _R)
	{
		op = _op;
		L = _L;
		R = _R;
		//	g_count ++;
		//	count = g_count;
	}

	override public string toString()
	{
		//	string res = "[" ~ text (count) ~ "]:{";
		string res = "{";
		if(L !is null)
			res ~= L.toString();
		res ~= op;
		if(R !is null)
			res ~= R.toString();
		return res ~ "}";
	}
}

public TTA parse_expr(string s)
{
	stack!TTA st = new stack!TTA();
	stack!string op = new stack!string();
	//	writeln("s=", s);

	for(int i = 0; i < s.length; i++)
	{
		if(!delim(s[i]))
		{
			//	writeln("s[", i, "]:", s[i]);
			if(s[i] == '(')
				op.pushBack("(");
			else if(s[i] == ')')
			{

				while(op.back() != "(")
					process_op(st, op.popBack());
				op.popBack();
			} else
			{
				int e = i + 2;
				if(e > s.length)
					e = cast(int) (s.length - 1);

				string curop = is_op(s[i .. e]);
				if(curop !is null)
				{
					//				writeln ("	curop:", curop);
					while(!op.empty() && priority(op.back()) >= priority(curop))
						process_op(st, op.popBack());
					op.pushBack(curop);
					i += curop.length - 1;
				} else
				{
					string operand;

					while(i < s.length && s[i] == ' ')
						i++;

					if(s[i] == '\'')
					{
						i++;
						int bp = i;
						while(i < s.length && s[i] != '\'')
							i++;
						operand = s[bp .. i];
						//				    writeln ("	operand=", operand);
						st.pushBack(new TTA(operand, null, null));
					}
					else if(s[i] == '`')
					{
						i++;
						int bp = i;
						while(i < s.length && s[i] != '`')
							i++;
						operand = s[bp .. i];
						//				    writeln ("	operand=", operand);
						st.pushBack(new TTA(operand, null, null));
					} else if(s[i] == '[')
					{
						i++;
						int bp = i;
						while(i < s.length && s[i] != ']')
							i++;
						operand = s[bp .. i];
						//				    writeln ("	operand=", operand);
						st.pushBack(new TTA(operand, null, null));
					}
					else 
					{
						int bp = i;
						while(i < s.length && s[i] != ' ' && s[i] != '&' && s[i] != '|' && s[i] != '='&& s[i] != '<'&& s[i] != '>'&& s[i] != '!' && s[i] != '-' && s[i] != ' ')
							i++;
						operand = s[bp .. i];
						//				    writeln ("	operand=", operand);
						st.pushBack(new TTA(operand, null, null));						
					}

				}
			}
		}
	}
	while(!op.empty())
		process_op(st, op.popBack());

	return st.back();
}

