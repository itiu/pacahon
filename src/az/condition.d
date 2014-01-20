module az.condition;

private
{
	import std.json;
	import std.stdio;
	import std.string;
	import std.array;
	import std.datetime;	
	import std.concurrency;

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


public void condition_thread()
{
	string key2slot_str;
	long last_update_time;	
	
    writeln("SPAWN: condition_thread");    
 	last_update_time = Clock.currTime().stdTime ();          	

    while (true)
    {
    	receive((EVENT type, string msg)
    	{    	
    		writeln ("condition_thread:", type, ":", msg); 
    	});    	
    }
}



class MandatManager
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

	public void load()
	{
		log.trace_log_and_console("start load mandats");

//		vql = new VQL(_thread_context);

		GraphCluster res = new GraphCluster();
		vql.get(null, 
				"return { 'veda:condition'}
            filter { 'class:identifier' == 'veda:mandat' && 'docs:actual' == 'true' && 'docs:active' == 'true' }",
				res, thread_context);

		int count = 0;
		JSONValue nil;

		foreach(ss; res.getArray())
		{
			try
			{
				string condition_text = ss.getFirstLiteral(veda__condition);
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
		
			string ff = A;

			if (B == "$user")
				B = userId;
			
		//writeln ("ff=", ff);
		//writeln ("fields.get (ff).items=", doc.getObjects(ff));
		
			foreach (field_i ; doc.getObjects(ff))
			{
				string field = field_i.literal;

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
			if (A == class__identifier)
			{
				templateIds.add (B);
				fields.add (class__identifier);
			}
			else			
				fields.add (A);
		
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
	
	