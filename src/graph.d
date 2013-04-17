module pacahon.graph;

/*
 * набор структур и методов для работы с фактами как с графом
 * 
 * модель:
 * 
 * GraphCluster 
 * 	└─Subject[]
 * 		└─Predicate[]
 * 			└─Objectz[]	
 * 
 * доступные возможности: 
 * - сборка графа из фактов или их частей
 * - навигация по графу
 * - серилизации графа в строку
 */

private import std.c.string;
private import std.string;
private import std.outbuffer;

version(D2)
{
//	import core.stdc.stdio;
}

import std.stdio;

import util.utils;

enum OBJECT_TYPE: byte
{
	LITERAL = 0,
	SUBJECT = 1,
	URI = 2,
	CLUSTER = 3
}

enum LANG: byte
{
	NONE = 0,
	RU = 1,
	EN = 2
}

final class GraphCluster
{
	Subject[string][string] i1PO;
	Subject[string] graphs_of_subject;

	void addTriple(string s, string p, string o, byte lang = 0)
	{
		if(o is null)
			return;

		Subject ss = graphs_of_subject.get(s, null);

		if(ss is null)
		{
			ss = new Subject;
			ss.subject = s;
		}
		graphs_of_subject[cast(string) s] = ss;
		ss.addPredicate(p, o, lang);
	}

	Subject addSubject(string subject_id)
	{
		Subject ss = new Subject;
		ss.subject = subject_id;

		graphs_of_subject[subject_id] = ss;

		return ss;
	}

	void addSubject(Subject ss)
	{
		if(ss.subject !is null)
		{
			graphs_of_subject[cast(string) ss.subject] = ss;
		}
	}

	int length()
	{
		return cast(uint) graphs_of_subject.length;
	}

	Subject find_subject(string predicate, string literal)
	{
		Subject[string] ss = i1PO.get(predicate, null);
		if(ss !is null)
		{
			return ss.get(literal, null);
		}
		return null;
	}

	Predicate* find_subject_and_get_predicate(string s_predicate, string s_literal, string p_predicate)
	{
//				writeln ("s_predicate=", s_predicate);
		Subject[string] ss = i1PO.get(s_predicate, null);
		if(ss !is null)
		{
//						writeln ("SS=", ss);
			Subject fs = ss.get(s_literal, null);

//			writeln ("fs=", fs);
			if(fs !is null)
			{
//				writeln ("edges_of_predicate=", fs.edges_of_predicate);
				Predicate* pr = fs.getPredicate(p_predicate);

				return pr;
			}
		}
		return null;
	}

	void reindex_i1PO(byte[string] indexedPredicates = null)
	{
		foreach(subject; graphs_of_subject.values)
		{
			for(short jj = 0; jj < subject.count_edges; jj++)
			{
				Predicate* pp = &subject.edges[jj];

				if(indexedPredicates !is null && indexedPredicates.get(pp.predicate, 0) == 0)
					continue;

				for(short kk = 0; kk < pp.count_objects; kk++)
				{
					if(pp.objects[kk].type == OBJECT_TYPE.LITERAL || pp.objects[kk].type == OBJECT_TYPE.URI)
					{
						i1PO[pp.predicate][cast(string) pp.objects[kk].literal] = subject;
					}
				}

			}

		}
	}

	void reindex_iXPO()
	{
		foreach(subject; graphs_of_subject.values)
		{
			subject.reindex_predicate();
		}
	}

	override string toString()
	{
		string res = "";

		foreach(el; this.graphs_of_subject.values)
		{
			res ~= " " ~ el.toString() ~ "\n";

		}
		return res;
	}
}

final class Subject
{
	bool needReidex = false;
	string subject = null;
	Predicate[] edges;
	short count_edges = 0;

	private Predicate*[char[]] edges_of_predicate;

	string getFirstObject(string pname)
	{
		if(needReidex == true || edges_of_predicate.length != edges.length)
			reindex_predicate();

		Predicate* pp = null;
		Predicate** ppp = (pname in edges_of_predicate);

		if(ppp !is null)
		{
			pp = *ppp;

			return pp.getFirstObject();
		}
		return null;
	}

	bool isExsistsPredicate(string pname)
	{
		if(needReidex == true || edges_of_predicate.length != edges.length)
			reindex_predicate();

		Predicate* pp = null;
		Predicate** ppp = (pname in edges_of_predicate);

		if(ppp !is null)
			return true;
		else
			return false;
	}

	Predicate* getPredicate(string pname)
	{
		if(needReidex == true || edges_of_predicate.length != edges.length)
			reindex_predicate();

		//		writeln ("edges_of_predicate=", edges_of_predicate, ", edges=", edges);

		return edges_of_predicate.get(pname, null);
	}

	void addPredicateAsURI(string predicate, string object)
	{
		if(object is null)
			return;

		if(edges.length == 0)
			edges = new Predicate[16];

		if(edges.length == count_edges)
		{
			edges.length += 16;
		}

		edges[count_edges].predicate = predicate;
		edges[count_edges].objects = new Objectz[1];
		edges[count_edges].count_objects = 1;
		edges[count_edges].objects[0].literal = object;
		edges[count_edges].objects[0].type = OBJECT_TYPE.URI;
		count_edges++;

		needReidex = true;
	}

	void addPredicate(string predicate, string object, byte lang = LANG.NONE)
	{
		if(object is null)
			return;

		Predicate* pp;
		for(int i = 0; i < count_edges; i++)
		{
			if(edges[i].predicate == predicate)
			{
				pp = &edges[i];
				break;
			}
		}

		if(pp !is null)
		{
			pp.addLiteral(object, lang);
		} else
		{
			if(edges.length == 0)
				edges = new Predicate[16];

			if(edges.length == count_edges)
			{
				edges.length += 16;
			}

			edges[count_edges].predicate = predicate;
			edges[count_edges].objects = new Objectz[1];
			edges[count_edges].count_objects = 1;
			edges[count_edges].objects[0].literal = object;
			edges[count_edges].objects[0].lang = lang;
			count_edges++;
		}
		needReidex = true;
	}

	void addPredicate(string predicate, GraphCluster cluster)
	{
		if(cluster is null)
			return;

		Predicate* pp;
		for(int i = 0; i < count_edges; i++)
		{
			if(edges[i].predicate == predicate)
			{
				pp = &edges[i];
				break;
			}
		}

		if(pp !is null)
		{
			pp.addCluster(cluster);
		} else
		{
			if(edges.length == 0)
				edges = new Predicate[16];

			if(edges.length == count_edges)
			{
				edges.length += 16;
			}

			edges[count_edges].predicate = predicate;
			edges[count_edges].objects = new Objectz[1];
			edges[count_edges].count_objects = 1;
			edges[count_edges].objects[0].cluster = cluster;
			edges[count_edges].objects[0].type = OBJECT_TYPE.CLUSTER;
			count_edges++;
		}
		needReidex = true;
	}

	void addPredicate(string predicate, Subject subject)
	{
		if(subject is null)
			return;

		Predicate* pp;
		for(int i = 0; i < count_edges; i++)
		{
			if(edges[i].predicate == predicate)
			{
				pp = &edges[i];
				break;
			}
		}
		if(pp !is null)
		{
			pp.addSubject(subject);
		} else
		{
			if(edges.length == 0)
				edges = new Predicate[16];

			if(edges.length == count_edges)
			{
				edges.length += 16;
			}

			edges[count_edges].predicate = predicate;
			edges[count_edges].objects = new Objectz[1];
			edges[count_edges].count_objects = 1;
			edges[count_edges].objects[0].subject = subject;
			edges[count_edges].objects[0].type = OBJECT_TYPE.SUBJECT;
			count_edges++;
		}
		needReidex = true;
	}

	void addPredicate(string predicate, Objectz oo)
	{
		Predicate* pp;
		for(int i = 0; i < count_edges; i++)
		{
			if(edges[i].predicate == predicate)
			{
				pp = &edges[i];
				break;
			}
		}
		if(pp !is null)
		{
			pp.addObjectz(oo);
		} else
		{
			if(edges.length == 0)
				edges = new Predicate[16];

			if(edges.length == count_edges)
			{
				edges.length += 16;
			}

			edges[count_edges].predicate = predicate;
			edges[count_edges].objects = new Objectz[1];
			edges[count_edges].objects[0] = oo;
			edges[count_edges].count_objects = 1;
			count_edges++;
		}
		needReidex = true;
	}

	Predicate* addPredicate()
	{
		if(edges.length == 0)
			edges = new Predicate[16];

		if(edges.length == count_edges)
		{
			edges.length += 16;
		}

		count_edges++;

		needReidex = true;

		return &edges[count_edges - 1];
	}

	private void reindex_predicate()
	{
		for(short jj = 0; jj < this.count_edges; jj++)
		{
			Predicate* pp = &this.edges[jj];

			this.edges_of_predicate[cast(string) pp.predicate] = pp;

			for(short kk = 0; kk < pp.count_objects; kk++)
			{
				if(pp.objects[kk].type == OBJECT_TYPE.SUBJECT)
				{
					pp.objects[kk].subject.reindex_predicate();
				} else if(pp.objects[kk].type == OBJECT_TYPE.LITERAL || pp.objects[kk].type == OBJECT_TYPE.URI)
				{
					pp.objects_of_value[cast(string) pp.objects[kk].literal] = &pp.objects[kk];
				}
			}

		}
		needReidex = false;
	}

	Subject dup()
	{
		Subject new_subj = new Subject();

		new_subj.needReidex = this.needReidex;
		new_subj.subject = this.subject;
		new_subj.edges = this.edges.dup;
		new_subj.count_edges = this.count_edges;

		return new_subj;
	}

	override string toString()
	{
		string res = this.subject ~ "\n  ";

		for(int i = 0; i < count_edges; i++)
		{
			res ~= "  " ~ edges[i].toString() ~ "\n";
		}

		return res;
	}
}

struct Predicate
{
	string predicate = null;
	Objectz[] objects; // начальное количество значений objects.length = 1, если необходимо иное, следует создавать новый массив objects 
	short count_objects = 0;

	Objectz*[char[]] objects_of_value;

	string getFirstObject()
	{
		if(count_objects > 0)
			return objects[0].literal;
		return null;
	}

	bool isExistLiteral(string value)
	{
		Objectz** ooo = (value in objects_of_value);

		if(ooo !is null)
			return true;

		return false;
	}

	Subject getFirstSubject()
	{
		if(count_objects > 0)
		{
			if(objects[0].type == OBJECT_TYPE.CLUSTER && objects[0].cluster.graphs_of_subject.length == 1)
			{
				return objects[0].cluster.graphs_of_subject.values[0];
			}

			return objects[0].subject;
		}
		return null;
	}

	void addLiteral(string val, byte lang = LANG.NONE)
	{
		if(val is null)
			return;

		if(objects.length == count_objects)
			objects.length += 16;

		objects[count_objects].literal = val;
		objects[count_objects].lang = lang;

		count_objects++;
	}

	void addCluster(GraphCluster cl)
	{
		if(cl is null)
			return;

		if(objects.length == count_objects)
			objects.length += 16;

		objects[count_objects].cluster = cl;
		objects[count_objects].type = OBJECT_TYPE.CLUSTER;

		count_objects++;
	}

	void addSubject(Subject ss)
	{
		if(ss is null)
			return;

		if(objects.length == count_objects)
			objects.length += 16;

		objects[count_objects].subject = ss;
		objects[count_objects].type = OBJECT_TYPE.SUBJECT;

		count_objects++;
	}

	void addObjectz(Objectz oo)
	{
		if(objects.length == count_objects)
			objects.length += 16;

		objects[count_objects] = oo;

		count_objects++;
	}

	string toString()
	{
		return this.predicate ~ " " ~ getFirstObject();
	}

}

struct Objectz
{
	//	union 
	//	{
	string literal; // если type == LITERAL
	Subject subject; // если type == SUBJECT
	GraphCluster cluster; // если type == CLUSTER
	//	}

	byte type = OBJECT_TYPE.LITERAL;
	byte lang;
}
