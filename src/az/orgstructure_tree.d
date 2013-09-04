module az.orgstructure_tree;

private
{
	import std.stdio;
	import std.string;
	import std.array;
	import util.utils;
	import util.Logger;
	import pacahon.vql;
	import trioplax.mongodb.TripleStorage;
	import pacahon.graph;
	import pacahon.context;
}

Logger log;

static this()
{
	log = new Logger("pacahon", "log", "OrgStructureTree");
}

class OrgStructureTree: BusEventListener
{
	//  по узлу можем получить его родителей
	string[][string] node_4_parents;

	TripleStorage ts;
	VQL vql;

	this(TripleStorage _ts)
	{
		ts = _ts;
		vql = new VQL(ts);
	}

	void bus_event(event_type et)
	{
	}

	public void load()
	{
		log.trace_log_and_console("start load org structure links");

		GraphCluster res = new GraphCluster();
		vql.get(null, "return { 'docs:parentUnit'} filter { 'a' == 'docs:unit_card' }", res, null);

		foreach(ss; res.getArray())
		{
			Objectz[] parents = ss.getObjects("docs:parentUnit");
			//writeln ("# PARENTS:", parents);
			string[] parent_ids = new string[parents.length];

			foreach(idx, parent; parents)
			{
				// TODO убрать корректировки ссылок в organization: временная коррекция ссылок
				char[] sscc = parent.literal.dup;
				if(sscc[7] == '_')
					sscc = sscc[8..$];
				else if(sscc[8] == '_')
					sscc = sscc[9..$];

				parent_ids[idx] = cast(string) sscc;
			}
			
			
			// TODO убрать корректировки ссылок в organization: временная коррекция ссылок
			char[] sscc = ss.subject.dup;
			if (ss.subject.length > 10)
			{
				// ссылки на реификации игнорируем
				if(sscc[7] == '_')
					sscc = sscc[8..$];
				else if(sscc[8] == '_')
					sscc = sscc[9..$];
				
				node_4_parents[cast(string)sscc] = parent_ids;
			}
			
			//writeln ("# [", cast(string)sscc, "]=", parent_ids);
		}

		log.trace_log_and_console("end load org structure links, count = %d", res.length);
	}

	public string[] get_parents(string uid)
	{
		return node_4_parents.get(uid, null);
	}

}
