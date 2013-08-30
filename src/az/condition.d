module az.condition;

private
{
	import std.json;
	import std.stdio;
	import std.string;
	import std.array;
	import std.datetime;	

	import ae.utils.container;

	import util.oi;
	import util.utils;
	import util.Logger;

	import trioplax.mongodb.TripleStorage;
	
	import pacahon.know_predicates;
	import pacahon.graph;
	import pacahon.vql;
	import pacahon.context;
	import pacahon.vel;	

	import az.orgstructure_tree;
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

struct ConditionsAndIndexes
{
//	Set!Element conditions;
	Set!Mandat conditions;

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
		vql.get(null, 
				"return { 'uo:condition'}
            filter { 'class:identifier' == 'mandat' && 'docs:actual' == 'true' && 'docs:active' == 'true' }",
				res, null);

		int count = 0;
		JSONValue nil;

		foreach(ss; res.getArray())
		{
			try
			{
				string condition_text = ss.getFirstLiteral("uo:condition");
				JSONValue condition_json = parseJSON(condition_text);
				Mandat mandat = void; 
				
				if (condition_json.type == JSON_TYPE.OBJECT)
				{
					mandat.id = ss.subject;
					JSONValue el = condition_json.object.get ("whom", nil);
					if (el != nil)
						mandat.whom = el.str;
					
					el = condition_json.object.get ("right", nil);
					if (el != nil)
						mandat.right = el.str;
					
					el = condition_json.object.get ("condition", nil);
					if (el != nil)
					{
						mandat.expression = parse_expr(el.str);
						//writeln ("TTA=", mandat.expression);
					}
										
					ConditionsAndIndexes* cai = whom_4_cai.get(mandat.whom, new ConditionsAndIndexes);					
					if(cai.conditions.size == 0)
						whom_4_cai[mandat.whom] = cai;
					
					found_templateIds_and_doc_fields (mandat.expression, "", cai.templateIds, cai.fields);
					
					cai.conditions ~= mandat;
				}
			} 
			catch(Exception ex)
			{

				writeln("error:load mandat :", ex.msg);
			}

		}

		//		writeln (whom_4_array_of_condition);
		//foreach(key, value; whom_4_cai)
		//{
		//	writeln("\n", key);
		//	writeln(value.templateIds.keys);
		//	writeln(value.fields.keys);
		//}

		log.trace_log_and_console("end load mandats, count=%d, whom_4_array_of_condition.length=%d", res.length,
				whom_4_cai.length);
		}
	}

	public bool calculate_rights_of_mandat(Mandat mndt, string userId, Subject doc, RightType rightType)
	{		
//		StopWatch sw_c;
//		sw_c.start();
		bool res = false;
		//writeln ("	DOC=", doc);
		//writeln ("	MANDAT=", mndt);
		try
		{
			string dummy;
			bool f_rigth_type = false;

			foreach(ch; mndt.right)
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
		
		
			res = eval(userId, mndt.expression , "", doc, dummy);		
		}
		finally
		{
//		sw_c.stop();
//		if (res == true)
//		{		
		//writeln ("мандат =", mndt);		
//		writeln (res, ", время вычисления мандата, time=", sw_c.peek().usecs);
//		}
		}
		
		return res;
	}

	public bool eval(string userId, TTA tta, string p_op, Subject doc, out string token, int level = 0)
	{
		if(tta.op == "==" || tta.op == "!=")
		{
			string A;
			eval(userId, tta.L, tta.op, doc, A, level + 1);
			string B;
			eval(userId, tta.R, tta.op, doc, B, level + 1);
//			writeln ("\ndoc=", doc);
//			writeln ("fields=", fields);
//			writeln (A, " == ", B);
		
			string ff;
			if (A == "mo/doc#tmplid")
				ff = class__identifier;
			else		
				ff = "uo:" ~ A;

			if (B == "$user")
				B = userId;
			
		//writeln ("ff=", ff);
		//writeln ("fields.get (ff).items=", doc.getObjects(ff));
		
			foreach (field_i ; doc.getObjects(ff))
			{
				string field = field_i.literal;
				if (field[3] == ':')
				{
					if (field[7] == '_')
						field = field[8..$];
					else if (field[8] == '_')
						field = field[9..$];
				}	
			
				//writeln ("field ", field, " ", tta.op, " ", B, " ", tta.op == "==" && field == B, " ", tta.op == "!=" && field != B);
				if (tta.op == "==" && field == B)
					return true;
				
				if (tta.op == "!=" && field != B)
					return true;
			}
			
			return false;		
		} else if(tta.op == "&&")
		{
			bool A = false, B = false;
		
			if(tta.R !is null)
				A = eval(userId, tta.R, tta.op, doc, token, level + 1);

			if(tta.L !is null)
				B = eval(userId, tta.L, tta.op, doc, token, level + 1);
			
			return A && B; 		
		}
		else if(tta.op == "||")
		{
			bool A = false, B = false;

			if(tta.R !is null)
				A = eval(userId, tta.R, tta.op, doc, token, level + 1);
				
			if (A == true)
				return true;	

			if(tta.L !is null)
				B = eval(userId, tta.L, tta.op, doc, token, level + 1);
					
			return A || B; 		
		} else
		{
			token = tta.op;
		}
		return false;
	}

	public string found_templateIds_and_doc_fields(TTA tta, string p_op, ref HashSet!string templateIds, ref HashSet!string fields, int level = 0)
	{
		if(tta.op == "==" || tta.op == "!=")
		{
			string A = found_templateIds_and_doc_fields(tta.L, tta.op, templateIds, fields, level + 1);
			string B = found_templateIds_and_doc_fields(tta.R, tta.op, templateIds, fields, level + 1);
			//writeln (A, " == ", B);
			if (A == "mo/doc#tmplid" || A == class__identifier)
			{
				templateIds.add (B);
				fields.add (class__identifier);
			}
			else			
				fields.add ("uo:" ~ A);
		
		} 
		else if(tta.op == "&&" || tta.op == "||")
		{
			if(tta.R !is null)
				found_templateIds_and_doc_fields(tta.R, tta.op, templateIds, fields, level + 1);

			if(tta.L !is null)
				found_templateIds_and_doc_fields(tta.L, tta.op, templateIds, fields, level + 1);		
		} 
		else
		{
			return tta.op;
		}
		
		return "";
	}





/*		
	private bool eval(string expr, ref Subject doc, string whom, ConditionsAndIndexes*[string]* whom_4_cai)
	{
		//		writeln ("@1.1.1.1");
		if(expr == "true")
			return true;

		expr = strip(expr);

		if(trace_msg[79] == 1)
			log.trace("expr: %s", expr);

		// [&&]
		// [||]

		int p1 = findOperand(expr, "&&");
		int p2 = findOperand(expr, "||");
		
		if(p1 >= 0)
		{
			if(whom_4_cai !is null)
			{
				eval(expr[0 .. p1], doc, whom, whom_4_cai);
				eval(expr[p1 + 2 .. $], doc, whom, whom_4_cai);
				return false;
			} else
			{
				return eval(expr[0 .. p1], doc, whom, whom_4_cai) && eval(expr[p1 + 2 .. $], doc, whom, whom_4_cai);
			}
		}

		if(p2 >= 0)
		{
			if(whom_4_cai is null)
			{
				eval(expr[0 .. p2], doc, whom, whom_4_cai);
				eval(expr[p2 + 2 .. $], doc, whom, whom_4_cai);
				return false;
			} else
			{
				return eval(expr[0 .. p2], doc, whom, whom_4_cai) || eval(expr[p2 + 2 .. $], doc, whom, whom_4_cai);
			}
		}

		if(expr.length > 2 && expr[0] == '(' && expr[$ - 1] == ')')
			return eval(expr[1 .. $ - 1], doc, whom, whom_4_cai);

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

			A = prepare_token(tA, whom, token_name_A);
			B = prepare_token(tB, whom, token_name_B);

			//		log.trace ("[A=%s tokens[1]=%s B=%s]", A, tokens[1], B);
			if(whom_4_cai !is null)
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
												triple_list_element* data_doc1 = ts.getTriplesUseIndexS1PPOO(null, user.ptr, docId.ptr);

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
						 }
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
*/
