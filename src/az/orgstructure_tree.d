module pacahon.az.orgstructure_tree;

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

class OrgStructureTree : BusEventListener
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

	void bus_event (event_type et)
	{		
	}

	public void load()
	{
		log.trace_log_and_console("start load org structure links");

		GraphCluster res = new GraphCluster();
		vql.get("return { 'docs:parentUnit'}" " filter { 'a' == 'docs:unit_card' }", res, null);

		foreach(ss; res.getArray())
		{
			Objectz[] parents = ss.getObjects("docs:parentUnit");
			string[] parent_ids = new string[parents.length];

			foreach(idx, parent; parents)
			{
				parent_ids[idx] = parent.literal;
			}
			node_4_parents[ss.subject] = parent_ids;
		}

		log.trace_log_and_console("end load org structure links, count = %d", res.length);
	}

	public string[] get_parents(string uid)
	{
		return node_4_parents.get(uid, null);
	}

}
