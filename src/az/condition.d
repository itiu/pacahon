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
	import pacahon.az.orgstructure_tree;
	import pacahon.thread_context;
	import pacahon.context;
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
	log = new Logger("pacahon", "log", "MandatManager");
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
				qq ~= key ~ " : " ~ pairs[key].toString() ~ "\n";
			}

			return qq;
		}
		if(type == asArray)
		{
			string qq;

			foreach(el; array)
			{
				qq ~= el.toString() ~ "\n";
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
		oe.type = asObject;

		return oe;
	} else if(je.type == JSON_TYPE.ARRAY)
	{

		auto arr = je.array;

		oe.array = new Element[arr.length];
		oe.type = asArray;

		int qq = 0;
		foreach(aa; arr)
		{
			oe.array[qq] = json2Element(aa, passed_elements);
			qq++;
		}
	} else if(je.type == JSON_TYPE.STRING)
	{
		oe.str = je.str.dup;
		oe.type = asString;
	}

	return oe;
}

struct ConditionsAndIndexes
{
	Set!Element conditions;

	// indexes
	HashSet!string templateIds;
	HashSet!string fields;	
}

class MandatManager: BusEventListener
{
	OrgStructureTree ost;
	TripleStorage ts;
	VQL vql;

	this(TripleStorage _ts)
	{
		ts = _ts;
		vql = new VQL(ts);
		ost = new OrgStructureTree(ts);
		ost.load();
	}

	ConditionsAndIndexes*[string] whom_4_cai;

	void bus_event(event_type et)
	{
	}

	public void load()
	{
		log.trace_log_and_console("start load mandats");

		vql = new VQL(ts);

		GraphCluster res = new GraphCluster();
		vql.get(
				"return { 'uo:condition'}
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
				Element root = new Element();
				json2Element(condition_json, passed_elements, root);
				root.id = mandat_subject;

				Element whom = root.pairs.get("whom", null);
				if(whom !is null)
				{
					ConditionsAndIndexes* cai = whom_4_cai.get(whom.str, new ConditionsAndIndexes);

					if(cai.conditions.size == 0)
						whom_4_cai[whom.str] = cai;

					cai.conditions ~= root;

					calculate_rights_of_mandat(root, "", null, RightType.READ, whom.str, true);

					log.trace("found mandat: %s", root.id);
				}

			} catch(Exception ex)
			{

				writeln("error:load mandat :", ex.msg);
			}

		}

		//		writeln (whom_4_array_of_condition);
		foreach(key, value; whom_4_cai)
		{
			writeln("\n", key);
			writeln(value.templateIds.keys);
			writeln(value.fields.keys);
		}

		log.trace_log_and_console("end load mandats, count=%d, whom_4_array_of_condition.length=%d", res.length,
				whom_4_cai.length);
	}

	public bool calculate_rights(Ticket ticket, Subject doc, uint rightType)
	{
		if(calculate_rights_of_unit(ticket.userId, doc, rightType) == true)
			return true;

		if(calculate_rights_of_units(ticket.parentUnitIds, doc, rightType) == true)
			return true;

		return false;
	}

	private bool calculate_rights_of_units(ref string[] units, Subject doc, uint rightType)
	{
		// найдем мандаты для этого узла
		if(units !is null)
		{
			foreach(unit_id; units)
			{
				auto cai = whom_4_cai.get(unit_id, null);
				if(cai !is null)
				{
					foreach(mandat; cai.conditions.data)
					{
						if(calculate_rights_of_mandat(mandat, unit_id, doc, rightType) == true)
							return true;
					}
				}

				string[] up_units = ost.node_4_parents.get(unit_id, null);
				if(up_units !is null)
				{
					if(calculate_rights_of_units(up_units, doc, rightType) == true)
						return true;
				}

			}
		}
		return false;
	}

	private bool calculate_rights_of_unit(string unit, Subject doc, uint rightType)
	{
		// найдем мандаты для этого узла
		auto cai = whom_4_cai.get(unit, null);
		if(cai !is null)
		{
			foreach(mandat; cai.conditions.data)
			{
				if(calculate_rights_of_mandat(mandat, unit, doc, rightType) == true)
					return true;
			}
		}
		return false;
	}

	private bool calculate_rights_of_mandat(Element mndt, string user, Subject doc, uint rightType, string whom = null,
			bool isTest = false)
	{
		//writeln("\n------------------------------------\n", mndt);

		if(mndt is null)
			return false;

		bool res = false;

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

					bool eval_res = eval(condt.str, doc, user, whom, isTest);
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

	private bool eval(string expr, ref Subject doc, string user, string whom, bool isTest)
	{
		//		writeln ("@1.1.1.1");
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
		{
			if(isTest)
			{
				eval(expr[0 .. p1], doc, user, whom, isTest);
				eval(expr[p1 + 2 .. $], doc, user, whom, isTest);
				return false;
			} else
			{
				return eval(expr[0 .. p1], doc, user, whom, isTest) && eval(expr[p1 + 2 .. $], doc, user, whom, isTest);
			}
		}

		if(p2 >= 0)
		{
			if(isTest)
			{
				eval(expr[0 .. p2], doc, user, whom, isTest);
				eval(expr[p2 + 2 .. $], doc, user, whom, isTest);
				return false;
			} else
			{
				return eval(expr[0 .. p2], doc, user, whom, isTest) || eval(expr[p2 + 2 .. $], doc, user, whom, isTest);
			}
		}

		if(expr.length > 2 && expr[0] == '(' && expr[$ - 1] == ')')
			return eval(expr[1 .. $ - 1], doc, user, whom, isTest);

		// [==] [!=]

		//		if(doc !is null)
		{
			string A, B;

			string[] tokens = split(expr, " ");

			if(trace_msg[80] == 1)
				log.trace("tokens=%s", tokens);

			if(tokens.length != 3)
				return false;

			string tA = tokens[0];
			string tB = tokens[2];

			string token_name_A;
			string token_name_B;

			A = prepare_token(tA, user, token_name_A);
			B = prepare_token(tB, user, token_name_B);

			//		log.trace ("[A=%s tokens[1]=%s B=%s]", A, tokens[1], B);
			if(isTest == true)
			{
				auto cai = whom_4_cai.get(whom, null);
				if(cai !is null)
				{
					if(token_name_A == "mo/doc#tmplid")
						cai.templateIds.add(B);
					else
						cai.fields.add(token_name_A);
				}
			}

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

	private string prepare_token(string tA, string user, out string token_name)
	{
		//		writeln ("@1.1.1.1.1 tA=", tA);

		string A;
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
				string docId;// = doc.getFirstLiteral(ttt[0][1 .. $ - 2]);

				//used_doc_fields

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
			if(A !is null)
				log.trace("%s = %s", tA, A);

			token_name = tA;

			//writeln("@1:tA=", tA);
			// нужно найти данный предикат tokens[0] в data и взять его значение
			//			log.trace("нужно найти данный предикат tokens[0] в data и взять его значение");
			//A = doc.getFirstLiteral(tA);
		}
		return A;
	}
}