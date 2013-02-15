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

enum LITERAL_LANG: byte
{
	NONE = 0,
	RU = 1,
	EN = 2
}

final class GraphCluster
{
	Subject[string] graphs_of_subject;

	void addTriple(string s, string p, string o, byte lang = 0)
	{
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

}

final class Subject
{
	bool needReidex = false;
	string subject = null;
	Predicate[] edges;
	short count_edges = 0;

	Predicate*[char[]] edges_of_predicate;

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
		/*		
		 Predicate* pp = null;
		 Predicate** ppp = (pname in edges_of_predicate);

		 if(ppp !is null)
		 {
		 pp = *ppp;

		 return pp;
		 }
		 return null;
		 */
	}

	void addPredicateAsURI(string predicate, string object)
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
		edges[count_edges].objects[0].type = OBJECT_TYPE.URI;
		count_edges++;

		needReidex = true;
	}

	void addPredicate(string predicate, string object, byte lang = LITERAL_LANG.NONE)
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

	void addLiteral(string val, byte lang = LITERAL_LANG.NONE)
	{
		if(objects.length == count_objects)
			objects.length += 16;

		objects[count_objects].literal = val;
		objects[count_objects].lang = lang;

		count_objects++;
	}

	void addCluster(GraphCluster cl)
	{
		if(objects.length == count_objects)
			objects.length += 16;

		objects[count_objects].cluster = cl;
		objects[count_objects].type = OBJECT_TYPE.CLUSTER;

		count_objects++;
	}

	void addSubject(Subject ss)
	{
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
