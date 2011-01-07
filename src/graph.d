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

struct GraphCluster
{
	Subject[char[]] graphs_of_subject;

	void addTriple(char[] s, char[] p, char[] o, byte lang)
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
		ss.subject = cast(char[])subject_id;

		graphs_of_subject[subject_id] = ss;
		
		return ss;
	}

	void addSubject(Subject ss)
	{
		graphs_of_subject[cast(immutable)ss.subject] = ss;
	}
}

class Subject
{
	char[] subject = null;
	Predicate[] edges;
	short count_edges = 0;

	Predicate*[char[]] edges_of_predicate;

	Predicate* getEdge(char[] pname)
	{
		Predicate* pp = null;
		Predicate** ppp = (pname in edges_of_predicate);

		if(ppp !is null)
			pp = *ppp;

		return pp;
	}

	Predicate* getEdge_brute_force(char[] pname)
	{
		for(int kk = 0; kk < count_edges; kk++)
		{
			if(edges[kk].predicate == pname)
			{
				return &edges[kk];
			}
		}

		return null;
	}

	void addPredicateAsURI(char[] predicate, char[] object)
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

	void addPredicate(char[] predicate, char[] object, byte lang = LITERAL_LANG.NONE)
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

	void addPredicate(char[] predicate, GraphCluster cluster)
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

	void addPredicate(char[] predicate, Subject subject)
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


//	char* toTurtle()
//	{
//		OutBuffer outbuff = new OutBuffer();
//
//		toTurtle(outbuff);
//		outbuff.write(0);
//
//		return cast(char*) outbuff.toBytes();
//	}
}

struct Predicate
{
	char[] predicate = null;
	Objectz[] objects; // начальное количество значений objects.length = 1, если необходимо иное, следует создавать новый массив objects 
	short count_objects = 0;

	Objectz*[char[]] objects_of_value;

	char[] getFirstObject()
	{
		if(count_objects > 0)
			return objects[0].object;
		return null;
	}
}

struct Objectz
{
	char[] object; // если type == LITERAL
	Subject subject; // если type == SUBJECT
	GraphCluster cluster; // если type == CLUSTER 

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
			else
			{
				pp.objects_of_value[cast(immutable) pp.objects[kk].object] = &pp.objects[kk];
			}
		}

	}
}
