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
 * функции: 
 * - сборка графа из фактов или их частей
 * - навигация по графу
 * - серилизации графа в строку
 * - серилизации графа в BSON
 */

private import std.c.string;
private import std.string;
private import std.outbuffer;
private import std.conv;
private import std.stdio;
private import util.utils;

private import pacahon.know_predicates;

enum OBJECT_TYPE: byte
{
	LITERAL = 0,
	SUBJECT = 1, 
	URI = 2,
	CLUSTER = 3
}

//enum DATA_TYPE: byte
//{
//	STRING = 0,
//	INTEGER = 1,
//	DOUBLE = 2,
//	DATETIME = 3
//}

enum LANG: byte
{
	NONE = 0,
	RU = 1,
	EN = 2
}

enum STRATEGY: byte
{
	NOINDEXED = 0,
	INDEXED = 1
}

final class GraphCluster
{
	private byte type;
	private Subject[string][string] i1PO;
	private Subject[string] graphs_of_subject;

	// if STRATEGY.NOINDEXED
	private Subject[] graphs;
	private int count_of_graphs = 0;

	this(byte _type = STRATEGY.INDEXED)
	{
		type = _type;
	}

	Subject[] getArray()
	{
		if(type == STRATEGY.NOINDEXED)
		{
			return graphs[0 .. count_of_graphs];
		} else
		{
			return graphs_of_subject.values;
		}
	}

	Subject addTriple(string s, string p, string o, byte lang = 0)
	{
		if(o is null)
			return null;

		Subject ss = graphs_of_subject.get(s, null);

		if(ss is null)
		{
			ss = new Subject;
			ss.subject = s;
		}
		graphs_of_subject[cast(string) s] = ss;
		ss.addPredicate(p, o, lang);

		return ss;
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
		if(type == STRATEGY.NOINDEXED)
		{
			count_of_graphs++;
			if(graphs.length <= count_of_graphs)
				graphs.length += 128;
			graphs[count_of_graphs-1] = ss;
		} else
		{
			if(ss !is null && ss.subject !is null)
			{
				graphs_of_subject[ss.subject] = ss;
			}
		}
	}

	int length()
	{
		if(type == STRATEGY.NOINDEXED)
			return count_of_graphs;
		else
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

	Predicate find_subject_and_get_predicate(string s_predicate, string s_literal, string p_predicate)
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
				Predicate pr = fs.getPredicate(p_predicate);

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
				Predicate pp = subject.edges[jj];

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
	string subject = null;
	private bool needReidex = false;
	private Predicate[] edges;
	private short _count_edges = 0;
	private Predicate[string] edges_of_predicate;
	
	// если субьект = документ
	Predicate exportPredicates; // список экспортируемых предикатов
	Subject	docTemplate; 		// шаблон документа

	short count_edges ()
	{
		return _count_edges;
	}
	
	Predicate[] getPredicates()
	{
		return edges[0 .. _count_edges];
	}

	string getFirstLiteral(string pname)
	{
		if(needReidex == true || edges_of_predicate.length != edges.length)
			reindex_predicate();

		Predicate pp = edges_of_predicate.get(pname, null);
		if(pp !is null)
			return pp.getFirstLiteral();
		return null;
	}

	Objectz[] getObjects(string pname)
	{
		if(needReidex == true || edges_of_predicate.length != edges.length)
			reindex_predicate();

		Predicate pp = edges_of_predicate.get(pname, null);
		if(pp !is null)
			return pp.getObjects();
		return null;
	}

	Objectz getObject(string pname, string literal)
	{
		if(needReidex == true || edges_of_predicate.length != edges.length)
			reindex_predicate();

		Predicate pp = edges_of_predicate.get(pname, null);
		if(pp !is null)
			return pp.getObject(literal);

		return null;
	}

	bool isExsistsPredicate(string pname)
	{
		if(needReidex == true || edges_of_predicate.length != edges.length)
			reindex_predicate();

		Predicate pp = edges_of_predicate.get(pname, null);

		if(pp !is null)
			return true;
		else
			return false;
	}

	bool isExsistsPredicate(string pname, string _object)
	{
		if(needReidex == true || edges_of_predicate.length != edges.length)
			reindex_predicate();

		Predicate pp = edges_of_predicate.get(pname, null);

		if(pp !is null)
		{
			if(pp.getObject(_object) !is null)
				return true;
		}

		return false;
	}

	Predicate getPredicate(string pname)
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

		if(edges.length == _count_edges)
			edges.length += 16;
		edges[_count_edges] = new Predicate;
		edges[_count_edges].predicate = predicate;
		edges[_count_edges].objects = new Objectz[1];
		edges[_count_edges].count_objects = 1;
		edges[_count_edges].objects[0] = new Objectz();
		edges[_count_edges].objects[0].literal = object;
		edges[_count_edges].objects[0].type = OBJECT_TYPE.URI;
		_count_edges++;

		needReidex = true;
	}

	void addPredicate(string predicate, string object, Subject _metadata, Subject _reification, byte lang = LANG.NONE)
	{
		if(object is null)
			return;

		Predicate pp;
		for(int i = 0; i < _count_edges; i++)
		{
			if(edges[i].predicate == predicate)
			{
				pp = edges[i];
				break;
			}
		}

		if(pp !is null)
		{
			pp.addLiteral(object, _reification, lang);
		} else
		{
			if(edges.length == 0)
				edges = new Predicate[16];

			if(edges.length == _count_edges)
				edges.length += 16;

			edges[_count_edges] = new Predicate;
			edges[_count_edges].predicate = predicate;
			edges[_count_edges].objects = new Objectz[1];
			edges[_count_edges].count_objects = 1;
			edges[_count_edges].objects[0] = new Objectz();
			edges[_count_edges].objects[0].literal = object;
			edges[_count_edges].objects[0].lang = lang;
			edges[_count_edges].objects[0].reification = _reification;
			edges[_count_edges].metadata = _metadata;
			_count_edges++;
		}
		needReidex = true;
	}

	Objectz addPredicate(string predicate, string object, byte lang = LANG.NONE)
	{
		if(object is null)
			return null;

		Predicate pp;
		for(int i = 0; i < _count_edges; i++)
		{
			if(edges[i].predicate == predicate)
			{
				pp = edges[i];
				break;
			}
		}

		if(pp !is null)
		{
			needReidex = true;
			return pp.addLiteral(object, lang);
		} else
		{
			if(edges.length == 0)
				edges = new Predicate[16];

			if(edges.length == _count_edges)
				edges.length += 16;

			edges[_count_edges] = new Predicate();
			edges[_count_edges].predicate = predicate;
			edges[_count_edges].objects = new Objectz[1];
			edges[_count_edges].count_objects = 1;
			edges[_count_edges].objects[0] = new Objectz();
			edges[_count_edges].objects[0].literal = object;
			edges[_count_edges].objects[0].lang = lang;
			_count_edges++;

			needReidex = true;
			return edges[_count_edges-1].objects[0];
		}
	}

	void addPredicate(string predicate, GraphCluster cluster)
	{
		if(cluster is null)
			return;

		Predicate pp;
		for(int i = 0; i < _count_edges; i++)
		{
			if(edges[i].predicate == predicate)
			{
				pp = edges[i];
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

			if(edges.length == _count_edges)
				edges.length += 16;

			edges[_count_edges] = new Predicate;
			edges[_count_edges].predicate = predicate;
			edges[_count_edges].objects = new Objectz[1];
			edges[_count_edges].count_objects = 1;
			edges[_count_edges].objects[0] = new Objectz();
			edges[_count_edges].objects[0].cluster = cluster;
			edges[_count_edges].objects[0].type = OBJECT_TYPE.CLUSTER;
			_count_edges++;
		}
		needReidex = true;
	}

	void addPredicate(string predicate, Subject subject)
	{
		if(subject is null)
			return;

		Predicate pp;
		for(int i = 0; i < _count_edges; i++)
		{
			if(edges[i].predicate == predicate)
			{
				pp = edges[i];
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

			if(edges.length == _count_edges)
				edges.length += 16;

			edges[_count_edges] = new Predicate;
			edges[_count_edges].predicate = predicate;
			edges[_count_edges].objects = new Objectz[1];
			edges[_count_edges].count_objects = 1;
			edges[_count_edges].objects[0] = new Objectz();
			edges[_count_edges].objects[0].subject = subject;
			edges[_count_edges].objects[0].type = OBJECT_TYPE.SUBJECT;
			_count_edges++;
		}
		needReidex = true;
	}

	void addPredicate(string predicate, Objectz oo)
	{
		Predicate pp;
		for(int i = 0; i < _count_edges; i++)
		{
			if(edges[i].predicate == predicate)
			{
				pp = edges[i];
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

			if(edges.length == _count_edges)
				edges.length += 16;

			edges[_count_edges] = new Predicate;
			edges[_count_edges].predicate = predicate;
			edges[_count_edges].objects = new Objectz[1];
			edges[_count_edges].objects[0] = oo;
			edges[_count_edges].count_objects = 1;
			_count_edges++;
		}
		needReidex = true;
	}

	void addPredicate(Predicate pp)
	{
		if(edges.length == 0)
			edges = new Predicate[16];

		if(edges.length == _count_edges)
			edges.length += 16;

		edges[_count_edges] = pp;
		_count_edges++;
		
		needReidex = true;
	}

	void addPredicate(string predicate, Objectz[] oo)
	{
		Predicate pp;
		for(int i = 0; i < _count_edges; i++)
		{
			if(edges[i].predicate == predicate)
			{
				pp = edges[i];
				break;
			}
		}
		if(pp !is null)
		{
			pp.addObjectzs(oo);
		} else
		{
			if(edges.length == 0)
				edges = new Predicate[16];

			if(edges.length == _count_edges)
				edges.length += 16;

			edges[_count_edges] = new Predicate;
			edges[_count_edges].predicate = predicate;
			edges[_count_edges].objects = oo;
			edges[_count_edges].count_objects = cast(ushort) oo.length;
			_count_edges++;
		}
		needReidex = true;
	}

	Predicate addPredicate()
	{
		if(edges.length == 0)
			edges = new Predicate[16];

		if(edges.length == _count_edges)
			edges.length += 16;

		_count_edges++;

		needReidex = true;

		edges[_count_edges - 1] = new Predicate;
		return edges[_count_edges - 1];
	}

	private void reindex_predicate()
	{
		for(short jj = 0; jj < this._count_edges; jj++)
		{
			Predicate pp = this.edges[jj];

			this.edges_of_predicate[pp.predicate] = pp;

			foreach(oo; pp.getObjects())
			{
				if(oo.type == OBJECT_TYPE.SUBJECT)
				{
					oo.subject.reindex_predicate();
				} else if(oo.type == OBJECT_TYPE.LITERAL || oo.type == OBJECT_TYPE.URI)
				{
					pp.objects_of_value[oo.literal] = oo;
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
		new_subj.exportPredicates = this.exportPredicates;
		new_subj.edges = this.edges.dup;
		new_subj._count_edges = this._count_edges;
		new_subj.edges_of_predicate = this.edges_of_predicate.dup;

		return new_subj;
	}

	override string toString()
	{
		string res = this.subject ~ "\n  ";

		for(int i = 0; i < _count_edges; i++)
		{
			res ~= "  " ~ edges[i].toString() ~ "\n";
		}

		return res;
	}
	
	Subject[] get_metadata ()
	{
		Subject[] array = new Subject[_count_edges]; 
		for(int i = 0; i < _count_edges; i++)
		{
			array[i] = edges[i].metadata;
		}		
		return array;
	}

	string toBSON()
	{
		OutBuffer outbuff = new OutBuffer();
		toBSON(outbuff);
		return outbuff.toString;//.toBytes;
	}
	
	void toBSON(ref OutBuffer outbuff, bool is_reification = false)
	{
		int start_pos = cast(int)outbuff.offset;
		outbuff.write ("\0\0\0\0");
		outbuff.write (cast(byte)0x2);
		outbuff.write ("@");
		outbuff.write (cast(byte)0);
		outbuff.write ("\0\0\0\0");
//		writeln (subject, ":", cast(void*)outbuff);
		int_to_buff (outbuff.data, cast(int)outbuff.offset - 4, cast(int)subject.length);
		outbuff.write (subject);
		outbuff.write (cast(byte)0);

		for(int i = 0; i < _count_edges; i++)
		{
			if ((is_reification == true) && (edges[i].predicate == rdf__predicate ||  edges[i].predicate == rdf__subject || edges[i].predicate == rdf__object))
				continue;

			edges[i].toBSON (outbuff);			
		}
//		writeln (subject, ":", cast(void*)outbuff);
//		writeln (outbuff.data);
		int_to_buff (outbuff.data, start_pos, cast(int)(outbuff.offset - start_pos - 4));
		//writeln ("TO BSON ", subject);
		outbuff.write (cast(byte)0);
	}
	
	private static int prepare_bson_element (string bson, Subject subject, int pos, Predicate pp)
	{
//				writeln ("fromBSON #1 bson.len=", bson.length);
		Objectz oo;
		while (pos < bson.length)
		{
			byte type = bson[pos];
//				writeln ("fromBSON:type", type);
			pos++;

			if (type == 0x02 || type == 0x03 || type == 0x04)
			{
				int bp = pos;
				while (bson[pos] != 0)
					pos++;
					
				string key = bson[bp..pos];
				//writeln ("key=",bson[bp..pos]); 
				pos++;
				
				bp = pos;
				int len = int_from_buff (bson, pos);
				//writeln ("LEN:", len);
				
				if (len > bson.length)
				{
					writeln ("!@!#!@#!@%#$@!&% len > bson.length, len=", len, ", bson.length=", bson.length);					
				}
				
				
				if (type == 0x03)
				{
//					    writeln ("*1:key=", key);
					    pos += 4;
											
					Subject inner = new Subject ();
					//writeln ("		!!!!!!!!! read subject of metadata, len=", len, ", pos=", pos, ", bson.len=", bson.length);
					pos += prepare_bson_element (bson[pos..pos+len], inner, 4, null);
					//writeln ("		!!!!!!!! ok, len=", len);
					if (key == "M")
					{
					    if (pp !is null)
						pp.metadata = inner;
					}
					else if (key == "R")
					{
					    //writeln ("INNER:", inner, ", oo=", oo);
					    if (oo !is null)
						oo.reification = inner;
					}    						
				}
				else 
				if (type == 0x02)
				{										
					bp = pos + 4;					
					if (bp+len > bson.length)
						len = cast(int)bson.length - bp;
			
					//writeln ("LEN2:", len);			
					if (subject.subject is null && key == "@")
						subject.subject = bson[bp..bp+len];
					else
					{
						string val = bson[bp..bp+len-1];
						byte lang = bson[bp+len];
						
//						writeln ("val:", val);
//						print_dump (bp+len, bson);						
						
						//writeln ("lang:", cast(byte)bson[bp+len+2]);
					 	if (pp !is null)
					 		oo = pp.addLiteral (val, lang);
					 	else	
					 		oo = subject.addPredicate (key, val, lang);
					}
					
					//writeln (bson[bp..bp+len]);	
					pos=bp+len+1;		
				}
				else if (type == 0x04)
				{
					pos += 4;
			
					Predicate npp = subject.addPredicate();
					npp.predicate = key;
				
					pos += prepare_bson_element (bson[pos..pos+len], subject, 0, npp);
				}
			}
		}
		
		return pos;		
	}
	
	public static Subject fromBSON (string bson)
	{
//		writeln ("fromBSON:bson.length=", bson.length);
		Subject res = new Subject ();
		
		prepare_bson_element (bson, res, 4, null);
		
		return res;
	}
	
}

class Predicate
{
	string predicate = null;
	private Objectz[] objects; // начальное количество значений objects.length = 1, если необходимо иное, следует создавать новый массив objects 
	short count_objects = 0;
	Subject metadata = null; // свойства данного предиката в виде owl:Restriction

	Objectz[string] objects_of_value;

	Objectz[] getObjects()
	{
		return objects[0 .. count_objects];
	}

	Objectz getObject(string literal)
	{
		foreach(oo; objects[0 .. count_objects])
		{
			if(oo.literal == literal)
				return oo;
		}
		return null;
	}

	string getFirstLiteral()
	{
		if(count_objects > 0)
			return objects[0].literal;
		return null;
	}

	bool isExistLiteral(string value)
	{
		Objectz ooo = objects_of_value.get(value, null);

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

	Objectz addLiteral(string val, Subject reification, byte lang = LANG.NONE)
	{
		if(val is null)
			return null;

		if(objects.length == count_objects)
			objects.length += 16;
		objects[count_objects] = new Objectz;
		objects[count_objects].literal = val;
		objects[count_objects].reification = reification;
		objects[count_objects].lang = lang;
		count_objects++;
		return objects[count_objects-1];
	}

	Objectz addLiteral(string val, byte lang = LANG.NONE)
	{
		if(val is null)
			return null;

		if(objects.length == count_objects)
			objects.length += 16;
		objects[count_objects] = new Objectz;
		objects[count_objects].literal = val;
		objects[count_objects].lang = lang;
		count_objects++;
		return objects[count_objects-1];
	}

	void addCluster(GraphCluster cl)
	{
		if(cl is null)
			return;

		if(objects.length == count_objects)
			objects.length += 16;
		objects[count_objects] = new Objectz;
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
		objects[count_objects] = new Objectz;
		objects[count_objects].subject = ss;
		objects[count_objects].type = OBJECT_TYPE.SUBJECT;
		count_objects++;
	}

	void addObjectz(Objectz oo)
	{
		if(objects.length == count_objects)
			objects.length += 16;
		objects[count_objects] = new Objectz;
		objects[count_objects] = oo;
		count_objects++;
	}

	void addObjectzs(Objectz[] oo)
	{
		objects = oo;
		count_objects = cast(ushort) oo.length;
	}

	override string toString()
	{
		string res = this.predicate;
	
		if (objects.length > 0)
		{
			res ~= ":";
			if (objects.length == 1)
			{
				res ~= objects[0].literal;
			}
			else
			{
				res ~= "[";
				bool zpt = false;
				foreach (objz ; getObjects())
				{
					if (objz.literal !is null)
					{
						if (zpt == true)
							res ~= ", ";
						
						res ~= objz.literal;
						zpt = true;
					}
				}
				res ~= "]";
			}
		}
		
		return res;
	}
	
	void toBSON (OutBuffer outbuff)
	{
		ulong offset_length_value;
		
		bool as_array = count_objects > 1 || metadata !is null;
		
		if (as_array)
			outbuff.write (cast(byte)0x04);
		else	
			outbuff.write (cast(byte)0x02);

		outbuff.write (predicate);
		outbuff.write (cast(byte)0);
				
		if (as_array)
		{
			offset_length_value = outbuff.offset;			
			outbuff.write (0xFFFFFFFF);
		}	
		
		int idx = 0;		
		foreach(oo; objects[0 .. count_objects])
		{
			if (as_array)
			{
				outbuff.write (cast(byte)0x02);
				outbuff.write (text(idx));
				outbuff.write (cast(byte)0);
			}
			oo.toBSON (outbuff);
			outbuff.write (cast(byte)0);
			idx++;
		}
		if	(metadata !is null)
		{
			outbuff.write (cast(byte)0x03);
			outbuff.write ("M");
			outbuff.write (cast(byte)0);
			metadata.toBSON (outbuff);
//			writeln (metadata);
			outbuff.write (cast(byte)0);
		}
		
		if (as_array)
		{
			int value_length = 0;
			value_length = cast(int)(outbuff.offset - offset_length_value - 4);	
				
//			if (metadata !is null)
//				value_length += 3;
				
			//writeln ("TO BSON ", " ", predicate, ", value_length=", value_length);
			int_to_buff (outbuff.data, cast(int)offset_length_value, value_length);
		}
		outbuff.write (cast(byte)0);
	}
}

private int int_from_buff (string buff, int pos)
{
	int res = buff[pos+0] + ((cast(uint)buff[pos+1]) << 8) + ((cast(uint)buff[pos+2]) << 16) + ((cast(uint)buff[pos+3]) << 24);
	 
	return res;
}

private void int_to_buff (ref ubyte[] buff, int pos, int dd)
{
	ubyte* value_length_ptr = cast(ubyte*)&dd;
	buff[pos+0] = *(value_length_ptr + 0); 
	buff[pos+1] = *(value_length_ptr + 1); 
	buff[pos+2] = *(value_length_ptr + 2); 
	buff[pos+3] = *(value_length_ptr + 3); 		
}

class Objectz
{
	string literal; 		// если type == LITERAL
	Subject subject; 		// если type == SUBJECT
	GraphCluster cluster; 	// если type == CLUSTER

	Subject reification = null; // реификация для данного значения

	byte type = OBJECT_TYPE.LITERAL;
	//	byte data_type = DATA_TYPE.STRING;
	byte lang;

	override string toString()
	{
		return literal;
	}
	
	void toBSON (OutBuffer outbuff)
	{
		if (type == OBJECT_TYPE.LITERAL && literal !is null)
		{
			int value_length = cast(int)(literal.length + 1);
			int offset_length_value = cast(int)outbuff.offset;
			outbuff.write (0xFFFFFFFF);
			outbuff.write (literal);
			outbuff.write (lang);
			outbuff.write (cast(byte)0);
			 
			int_to_buff (outbuff.data, offset_length_value, value_length);
			
			if	(reification !is null)
			{
				outbuff.write (cast(byte)0x03);
				outbuff.write ("R");
				outbuff.write (cast(byte)0);
				reification.toBSON (outbuff, true);
//				writeln (metadata);
				outbuff.write (cast(byte)0);
			}
			
		}
	}	
}

private static void print_dump (int bp, string bson)
{				
	writeln ("*******");

	long ep = bp + 8;
	long sp = bp - 8;
	
	if (sp < 0) sp = 0;
	if (ep > bson.length) ep = bson.length -1; 			
				
	for (long i = sp; i < ep; i++)
		writeln ("bson ", (i - bp) , "[", i, "]:", bson[i], ", ", cast(uint)bson[i]);
						
	writeln ("*******");
}			

