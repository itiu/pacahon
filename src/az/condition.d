module pacahon.az.condition;

private
{
	import std.json;
	import std.stdio;
	import std.string;
	import std.array;
	import util.utils;
	import trioplax.mongodb.TripleStorage;
	import pacahon.graph;
	import pacahon.oi;
	import util.Logger;
	import pacahon.vql;
	import ae.utils.container;
}

enum RightType
{
	CREATE = 0,
	READ = 1,
	WRITE = 2,
	UPDATE = 3,
	DELETE = 4,
	ADMIN = 5
}

Logger log;

static this()
{
	log = new Logger("pacahon", "log", "server");
}

const byte asObject = 0;
const byte asArray = 1;
const byte asString = 2;

class Element
{
	Element[string] pairs;
	Element[] array;
	string str;
	string id;

	byte type;

	override string toString()
	{
		if(type == asObject)
		{
			string qq;

			foreach(key; pairs.keys)
			{
				qq ~= key ~ " : " ~ pairs[key].toString() ~ "\r";
			}

			return qq;
		}
		if(type == asArray)
		{
			string qq;

			foreach(el; array)
			{
				qq ~= el.toString() ~ "\r";
			}
			return qq;
		} else if(type == asString)
			return str;
		else
			return "?";
	}

}

Element json2Element(ref JSONValue je, ref bool[string] passed_elements, Element oe = null)
{
	if(oe is null)
		oe = new Element;

	if(je.type == JSON_TYPE.OBJECT)
	{
		auto atts = je.object;

		int i = 0;
		foreach(key, value; atts)
		{
			if((key in passed_elements) is null)
			{
				passed_elements[key] = true;
				oe.pairs[cast(string) key.dup] = json2Element(value, passed_elements);
			}
		}

		return oe;
	} else if(je.type == JSON_TYPE.ARRAY)
	{

		auto arr = je.array;

		oe.array = new Element[arr.length];

		int qq = 0;
		foreach(aa; arr)
		{
			oe.array[qq] = json2Element(aa, passed_elements);
			qq++;
		}
	} else if(je.type == JSON_TYPE.STRING)
	{
		oe.str = je.str.dup;
	}

	return oe;
}

class MandatManager
{
	TripleStorage ts;

	this(TripleStorage _ts)
	{
		ts = ts;
	}

	Set!Element*[string] whom_4_array_of_condition;

	public void load_mandats()
	{
		writeln("start load documents[uid=mandat]");

		VQL vql = new VQL(ts);

		GraphCluster res = new GraphCluster();
		vql.get(
				"return { 'uo:condition'}
            render { '1000' }
            filter { 'class:identifier' == 'mandat' && 'docs:actual' == 'true' && 'docs:active' == 'true' }",
				res, null);

		int count = 0;

		foreach(ss; res.getArray())
		{
			try
			{
				string mandat_subject = ss.subject;
				string condition_text = ss.getFirstLiteral("uo:condition");
				JSONValue condition_json = parseJSON(condition_text);
				bool[string] passed_elements;
				Element root = new Element;
				json2Element(condition_json, passed_elements, root);
				root.id = mandat_subject;

				Element whom = root.pairs.get("whom", null);
				Set!Element* array = whom_4_array_of_condition.get(whom.str, new Set!Element);

				*array ~= root;

				printf("found mandat %s\n", mandat_subject);
				log.trace("found mandat: %s", root.id);

			} catch(Exception ex)
			{

				writeln("error:load mandat :", ex.msg);
			}

		}

		log.trace("end load documents[mandat], count = %d", res.length);
	}

	public bool calculate_condition(string user, ref Element mndt, ref Subject doc, ref string[] hierarhical_departments_of_user,
			uint rightType)
	{
		if(mndt is null)
			return false;

		bool res = false;

		if(("whom" in mndt.pairs) !is null)
		{
			string whom;
			Element _whom = mndt.pairs["whom"];

			if(_whom !is null)
			{
				whom = _whom.str;

				if(trace_msg[70] == 1)
					log.trace("condition: проверим вхождение whom=[%s] в иерархию пользователя ", whom);

				bool is_whom = false;

				// проверим, попадает ли  пользователь под критерий whom (узел на который выданно)
				//	сначала, проверим самого пользователя
				if(user == whom)
				{
					if(trace_msg[71] == 1)
						log.trace("condition: да, пользователь попадает в иерархию whom");
					is_whom = true;
				} else
				{
					foreach(dep_id; hierarhical_departments_of_user)
					{
						if(dep_id == whom)
						{
							if(trace_msg[72] == 1)
								log.trace("condition: да, пользователь попадает в иерархию whom");
							is_whom = true;
							break;
						} else
						{
							if(trace_msg[72] == 1)
								log.trace("condition: нет, dep_id = [%s]", dep_id);
						}
					}
				}

				if(is_whom == false)
				{
					if(trace_msg[73] == 1)
						log.trace("condition: нет, пользователь не попадает в иерархию whom");
					return false;
				}
			}
		}

		if(("condition" in mndt.pairs) !is null)
		{
			Element right = mndt.pairs["right"];

			if(trace_msg[74] == 1)
				log.trace("rigth=%s", right);

			bool f_rigth_type = false;

			foreach(ch; right.str)
			{
				if(ch == 'c' && rightType == RightType.CREATE)
				{
					f_rigth_type = true;
					break;
				} else if(ch == 'r' && rightType == RightType.READ)
				{
					f_rigth_type = true;
					break;
				} else if(ch == 'w' && rightType == RightType.WRITE)
				{
					f_rigth_type = true;
					break;
				} else if(ch == 'u' && rightType == RightType.UPDATE)
				{
					f_rigth_type = true;
					break;
				} else if(ch == 'a')
				{
					f_rigth_type = true;
					break;
				}
			}

			if(f_rigth_type == false)
				return false;

			if(("date_from" in mndt.pairs) !is null && ("date_to" in mndt.pairs) !is null)
			{
				Element date_from = mndt.pairs["date_from"];
				Element date_to = mndt.pairs["date_to"];

				if(date_from !is null && date_to !is null)
				{
					if(is_today_in_interval(date_from.str, date_to.str) == false)
					{
						if(trace_msg[75] == 1)
							log.trace("condition: текущая дата не в указанном мандатом интервале [%s - %s]", date_from.str,
									date_to.str);
						return false;
					}
				}
			}

			Element condt = mndt.pairs["condition"];
			if(condt !is null)
			{
				if(condt.type == asString)
				{
					if(trace_msg[76] == 1)
						log.trace("eval (%s)", condt.str);

					bool eval_res = eval(condt.str, doc, user);
					if(trace_msg[77] == 1)
						log.trace("eval:%s, res=%s", condt.str, eval_res);
					return eval_res;
				}
			}
		}

		if(trace_msg[78] == 1)
			log.trace("calculate_condition return res=%s", res);

		return res;
	}

	private bool eval(string expr, ref Subject doc, string user)
	{
		if(expr == "true")
			return true;

		expr = strip(expr);

		if(trace_msg[79] == 1)
			log.trace("expr: %s", expr);

		static int findOperand(string s, string op1)
		{
			int parens = 0;
			foreach_reverse(p, c; s)
			{
				char c2 = 0;

				if(p > 0)
					c2 = s[p - 1];

				if((c == op1[1] && c2 == op1[0]) && parens == 0)
					return cast(int) (p - 1);

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
			return eval(expr[0 .. p1], doc, user) && eval(expr[p1 + 2 .. $], doc, user);

		if(p2 >= 0)
			return eval(expr[0 .. p2], doc, user) || eval(expr[p2 + 2 .. $], doc, user);

		if(expr.length > 2 && expr[0] == '(' && expr[$ - 1] == ')')
			return eval(expr[1 .. $ - 1], doc, user);

		// [==] [!=]

		if(doc !is null)
		{
			string A, B;

			string[] tokens = split(expr, " ");

			if(trace_msg[80] == 1)
				log.trace("tokens=%s", tokens);

			if(tokens.length != 3)
				return false;

			string tA = tokens[0];
			string tB = tokens[2];

			if(tA[0] == '[')
			{
				// это адресация к другому документу
				// считаем документ указанный в конструкции [field1], 
				// где field1 поле текущего документа содержащее id требуемого нам документа

				string[] ttt = split(tA, ".");
				if(trace_msg[81] == 1)
					log.trace("A:ttt=%s", ttt);

				if(ttt.length == 2)
				{
					// 1. вытащим имя поля и возьмем его значение
					string docId = doc.getFirstLiteral(ttt[0][1 .. $ - 2]);
					log.trace("A:docId=%s", docId);

					if(docId !is null && docId.length > 3)
					{
						if(ttt[1] == "$rights")
						{
							// 2. считаем документ по значению из[2] в: triple_list_element* doc1
							/*						triple_list_element* data_doc1 = ts.getTriplesUseIndexS1PPOO(null, user.ptr, docId.ptr);

							 if(data_doc1 !is null)
							 {
							 A = data_doc1.getFirstLiteral("mo/at/acl#rt");
							 }
							 } else
							 {
							 // 2. считаем права у документа
							 triple_list_element* data_doc1 = ts.getTriples(docId.ptr, null, null);

							 if(data_doc1 !is null)
							 {
							 A = data_doc1.getFirstLiteral(ttt[1]);
							 }*/
						}
					}
				}
			} else if(tA[0] == '\'' || tA[0] == '"' || tA[0] == '`')
			{
				// это строка
				A = tA[1 .. $ - 1];
			} else if(tA[0] == '$' && tA[1] == 'u' && tA[2] == 's' && tA[3] == 'e' && tA[4] == 'r')
			{
				// это проверяемый пользователь
				A = user;
			} else
			{
				// нужно найти данный предикат tokens[0] в data и взять его значение
				//			log.trace("нужно найти данный предикат tokens[0] в data и взять его значение");
				A = doc.getFirstLiteral(tA);
				if(A !is null)
					log.trace("%s = %s", tA, A);
			}

			if(tB[0] == '[')
			{
				// это адресация к другому документу
				// считаем документ указанный в конструкции [field1], 
				// где field1 поле текущего документа содержащее id требуемого нам документа

				string[] ttt = split(tB, ".");
				if(trace_msg[82] == 1)
					log.trace("B:ttt=%s", ttt);

				if(ttt.length == 2)
				{
					// 1. вытащим имя поля и возьмем его значение
					string docId = doc.getFirstLiteral(ttt[0][1 .. $ - 2]);

					// 2. считаем документ по значению из[2] в: triple_list_element* doc1
					if(docId !is null && docId.length > 3)
					{
						if(ttt[1] == "$rights")
						{
							// 2. считаем документ по значению из[2] в: triple_list_element* doc1
							/*						triple_list_element* data_doc1 = ts.getTriplesUseIndexS1PPOO(null, user.ptr, docId.ptr);

							 if(data_doc1 !is null)
							 {
							 B = data_doc1.getFirstLiteral("mo/at/acl#rt");
							 }
							 } else
							 {
							 // 2. считаем права у документа
							 triple_list_element* data_doc1 = ts.getTriples(docId.ptr, null, null);

							 if(data_doc1 !is null)
							 {
							 B = data_doc1.getFirstLiteral(ttt[1]);
							 } */
						}
					}

				}
			} else if(tB[0] == '\'' || tB[0] == '"' || tB[0] == '`')
			{
				// это строка
				B = tB[1 .. $ - 1];
			} else if(tB[0] == '$' && tB[1] == 'u' && tB[2] == 's' && tB[3] == 'e' && tB[4] == 'r')
			{
				// это проверяемый пользователь
				B = user;
			} else
			{
				//			log.trace("нужно найти данный предикат tokens[1] в data и взять его значение");
				// нужно найти данный предикат tokens[1] в data и взять его значение
				B = doc.getFirstLiteral(tB);

				if(B !is null)
					log.trace("%s = %s", tB, B);
			}

			//		log.trace ("[A=%s tokens[1]=%s B=%s]", A, tokens[1], B);

			if(tokens[1] == "==")
				return A == B;

			if(tokens[1] == "*=")
			{
				foreach(ch; B)
				{
					if(inPattern(ch, A) == false)
						return false;
				}
				return true;
			}
		}

		if(trace_msg[82] == 1)
			log.trace("return false");
		return false;

	}
}