module pacahon.graph;

/*
 * набор структур и методов для работы с фактами как с графом
 * 
 * модель:
 * 
 * GraphCluster 
 * 	└─Subject[]
 * 		└─Predicates[]
 * 			└─Objects[]	
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

import pacahon.utils;

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

	void addTriple(string s, string p, string o, byte lang)
	{
		Subject ss = graphs_of_subject.get(s, null);

		if(ss is null)
		{
			ss = new Subject;
			ss.subject = s;
		}
		graphs_of_subject[cast(immutable) s] = ss;
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
		if (ss.subject !is null)
		{
			graphs_of_subject[cast(immutable) ss.subject] = ss;
		}
	}
}

final class Subject
{
	string subject = null;
	Predicate[] edges;
	short count_edges = 0;

	Predicate*[char[]] edges_of_predicate;

	Predicate* getEdge(string pname)
	{
		Predicate* pp = null;
		Predicate** ppp = (pname in edges_of_predicate);

		if(ppp !is null)
			pp = *ppp;

		return pp;
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
		edges[count_edges].objects[0].object = object;
		edges[count_edges].objects[0].type = OBJECT_TYPE.URI;
		count_edges++;
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
		}
		else
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
			edges[count_edges].objects[0].object = object;
			edges[count_edges].objects[0].lang = lang;
			count_edges++;
		}
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
		}
		else
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
		}
		else
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
			return objects[0].object;
		return null;
	}
	
	void addLiteral(string val, byte lang = LITERAL_LANG.NONE)
	{
		if(objects.length == count_objects)
			objects.length += 16;

		objects[count_objects].object = val;
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
}

struct Objectz
{
//	union 
//	{
		string object; // если type == LITERAL
		Subject subject; // если type == SUBJECT
		GraphCluster cluster; // если type == CLUSTER
//	}

	byte type = OBJECT_TYPE.LITERAL;
	byte lang;
}

void set_hashed_data(Subject ss)
{
	for(short jj = 0; jj < ss.count_edges; jj++)
	{
		Predicate* pp = &ss.edges[jj];

		ss.edges_of_predicate[cast(immutable) pp.predicate] = pp;

		for(short kk = 0; kk < pp.count_objects; kk++)
		{
			if(pp.objects[kk].type == OBJECT_TYPE.SUBJECT)
			{
				set_hashed_data(pp.objects[kk].subject);
			}
			else if (pp.objects[kk].type == OBJECT_TYPE.LITERAL || pp.objects[kk].type == OBJECT_TYPE.URI)
			{
				pp.objects_of_value[cast(immutable) pp.objects[kk].object] = &pp.objects[kk];
			}
		}

	}
}
