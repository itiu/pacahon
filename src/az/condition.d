module az.condition;

private
{
	import std.json;
	import std.stdio;
	import std.string;
	import std.array;
	import std.datetime;	

	import util.container;
	import util.oi;
	import util.utils;
	import util.logger;
	import util.graph;

	import pacahon.know_predicates;
	import pacahon.context;

	import search.vel;	
	import search.vql;

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

logger log;

static this()
{
	log = new logger("pacahon", "log", "MandatManager");
}

struct Mandat
{
        string id;
        string whom;
        string right;
        TTA expression;
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
	VQL vql;
	Context thread_context;

	this(Context _thread_context)
	{
		thread_context = _thread_context;
		vql = new VQL(_thread_context);
		ost = new OrgStructureTree(_thread_context);
		ost.load();
	}

	ConditionsAndIndexes*[string] whom_4_cai;

	void bus_event(event_type et)
	{
	}

	public void load()
	{
		log.trace_log_and_console("start load mandats");

//		vql = new VQL(_thread_context);

		GraphCluster res = new GraphCluster();
		vql.get(null, 
				"return { 'uo:condition'}
            filter { 'class:identifier' == 'mandat' && 'docs:actual' == 'true' && 'docs:active' == 'true' }",
				res, thread_context);

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
						//writeln ("\nmandat.id=", mandat.id);
						//writeln ("str=", el.str);
						//writeln ("TTA=", mandat.expression);
					}
										
					ConditionsAndIndexes* cai = whom_4_cai.get(mandat.whom, new ConditionsAndIndexes);					
					if(cai.conditions.size == 0)
						whom_4_cai[mandat.whom] = cai;
					
					found_in_condition_templateIds_and_docFields (mandat.expression, "", cai.templateIds, cai.fields);
					
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
	

	public bool calculate_rights_of_mandat(Mandat mndt, string userId, Subject doc, RightType rightType)
	{		
//		StopWatch sw_c;
//		sw_c.start();
		bool res = false;
		//writeln ("	DOC=", doc);
		//writeln ("\n	MANDAT=", mndt);
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
		} else if(tta.op == "true")
		{
			return true;
		} 
		else
		{
			token = tta.op;
		}
		return false;
	}
}

private static string found_in_condition_templateIds_and_docFields(TTA tta, string p_op, ref HashSet!string templateIds, ref HashSet!string fields, int level = 0)
{
		if(tta.op == "==" || tta.op == "!=")
		{
			string A = found_in_condition_templateIds_and_docFields(tta.L, tta.op, templateIds, fields, level + 1);
			string B = found_in_condition_templateIds_and_docFields(tta.R, tta.op, templateIds, fields, level + 1);
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
				found_in_condition_templateIds_and_docFields(tta.R, tta.op, templateIds, fields, level + 1);

			if(tta.L !is null)
				found_in_condition_templateIds_and_docFields(tta.L, tta.op, templateIds, fields, level + 1);		
		} 
		else
		{
			return tta.op;
		}
		
		return "";
}
	
	