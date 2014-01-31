module util.graph;

/*
 * набор структур и методов для работы с фактами
 *
 * модель:
 *
 * GraphCluster
 *  └─Subject[]
 *      └─Predicate[]
 *          └─Objectz[]
 *
 * функции:
 * - сборка графа из фактов или их частей
 * - навигация по графу
 * - серилизации графа в строку
 */

private import std.c.string;
private import std.string;
private import std.outbuffer;
private import std.conv;
private import std.stdio;

private import util.utils;
private import util.json_ld.parser;
private import util.container;

private import pacahon.know_predicates;

enum OBJECT_TYPE : byte
{
    TEXT_STRING  = 0,
    LINK_SUBJECT =  10,
    LINK_CLUSTER  = 20,
    URI = 30,
    UNSIGNED_INTEGER = 31,
    STANDARD_DATE_TIME = 32    
}


enum STRATEGY : byte
{
    NOINDEXED = 0,
    INDEXED   = 1
}

final class Subjects
{
//    private byte type;
//    private      Subject[ string ][ string ] i1PO;
//    private      Subject[ string ] graphs_of_subject;

    private Set!Subject graphs;

    Subject[] data()
    {
            return graphs.items;
    }

    Subject addSubject(string subject_id)
    {
        Subject ss = new Subject;

        ss.subject = subject_id;

        graphs ~= ss;

        return ss;
    }

    void addSubject(Subject ss)
    {
        graphs ~= ss;
    }

    int length()
    {
            return cast(uint)graphs.length;
    }

    override string toString()
    {
        string res = "[\n";

        foreach (el; this.graphs.items)
        {
            res ~= " " ~ el.toString() ~ ",\n";
        }
        return res ~ "]";
    }
}

final class Subject
{
    string              subject    = null;
    private bool        needReidex = false;
    private Predicate[] edges;
    private short       _count_edges = 0;
    private             Predicate[ string ] edges_of_predicate;

    // если субьект = документ
    Predicate exportPredicates;     // список экспортируемых предикатов
    Subject   docTemplate;          // шаблон документа

    short count_edges()
    {
        return _count_edges;
    }

    short length()
    {
        return _count_edges;
    }

    int opApply(int delegate(ref Predicate) dg)
    {
    	int result = 0;

    	foreach (val; edges[ 0 .. _count_edges ])
    	{
    		result = dg(val);
    		if (result)
    			break;
    	}

    	return result;
    }
  
    Predicate[] getPredicates()
    {
        return edges[ 0 .. _count_edges ];
    }

    string getFirstLiteral(string pname)
    {
        if (needReidex == true || edges_of_predicate.length != edges.length)
            reindex_predicate();

        Predicate pp = edges_of_predicate.get(pname, null);
        if (pp !is null)
            return pp.getFirstLiteral();

        return null;
    }

    Objectz[] getObjects(string pname)
    {
        if (needReidex == true || edges_of_predicate.length != edges.length)
            reindex_predicate();

        Predicate pp = edges_of_predicate.get(pname, null);
        if (pp !is null)
            return pp.getObjects();

        return null;
    }

    Objectz getObject(string pname, string literal)
    {
        if (needReidex == true || edges_of_predicate.length != edges.length)
            reindex_predicate();

        Predicate pp = edges_of_predicate.get(pname, null);
        if (pp !is null)
            return pp.getObject(literal);

        return null;
    }

    bool isExsistsPredicate(string pname)
    {
        if (needReidex == true || edges_of_predicate.length != edges.length)
            reindex_predicate();

        Predicate pp = edges_of_predicate.get(pname, null);

        if (pp !is null)
            return true;
        else
            return false;
    }

    bool isExsistsPredicate(string pname, string _object)
    {
        if (needReidex == true || edges_of_predicate.length != edges.length)
            reindex_predicate();

        Predicate pp = edges_of_predicate.get(pname, null);

        if (pp !is null)
        {
            if (pp.getObject(_object) !is null)
                return true;
        }

        return false;
    }

    Predicate getPredicate(string pname)
    {
        if (needReidex == true || edges_of_predicate.length != edges.length)
            reindex_predicate();

        //		writeln ("edges_of_predicate=", edges_of_predicate, ", edges=", edges);

        return edges_of_predicate.get(pname, null);
    }

    void addPredicate(string predicate, string object, Subject _metadata, Subject _reification, LANG lang = LANG.NONE)
    {
        if (object is null)
            return;

        Predicate pp;
        for (int i = 0; i < _count_edges; i++)
        {
            if (edges[ i ].predicate == predicate)
            {
                pp = edges[ i ];
                break;
            }
        }

        if (pp !is null)
        {
            pp.addLiteral(object, _reification, lang);
        }
        else
        {
            if (edges.length == 0)
                edges = new Predicate[ 16 ];

            if (edges.length == _count_edges)
                edges.length += 16;

            edges[ _count_edges ]                          = new Predicate;
            edges[ _count_edges ].predicate                = predicate;
            edges[ _count_edges ].objects                  = new Objectz[ 1 ];
            edges[ _count_edges ].count_objects            = 1;
            edges[ _count_edges ].objects[ 0 ]             = new Objectz();
            edges[ _count_edges ].objects[ 0 ].literal     = object;
            edges[ _count_edges ].objects[ 0 ].lang        = lang;
            edges[ _count_edges ].objects[ 0 ].reification = _reification;
            edges[ _count_edges ].metadata                 = _metadata;
            _count_edges++;
        }
        needReidex = true;
    }
    
    Objectz addResource(string predicate, string object)
    {
        if (object is null)
            return null;

        if (edges.length == 0)
            edges = new Predicate[ 16 ];

        if (edges.length == _count_edges)
            edges.length += 16;
        edges[ _count_edges ]                      = new Predicate;
        edges[ _count_edges ].predicate            = predicate;
        edges[ _count_edges ].objects              = new Objectz[ 1 ];
        edges[ _count_edges ].count_objects        = 1;
        edges[ _count_edges ].objects[ 0 ]         = new Objectz();
        edges[ _count_edges ].objects[ 0 ].literal = object;
        edges[ _count_edges ].objects[ 0 ].type    = OBJECT_TYPE.URI;
        _count_edges++;

        needReidex = true;
        
        return edges[ _count_edges - 1 ].objects[ 0 ];
    }
    
    Objectz addPredicate(string predicate, string object, LANG lang = LANG.NONE)
    {
        if (object is null)
            return null;

        Predicate pp;
        for (int i = 0; i < _count_edges; i++)
        {
            if (edges[ i ].predicate == predicate)
            {
                pp = edges[ i ];
                break;
            }
        }

        if (pp !is null)
        {
            needReidex = true;
            return pp.addLiteral(object, lang);
        }
        else
        {
            if (edges.length == 0)
                edges = new Predicate[ 16 ];

            if (edges.length == _count_edges)
                edges.length += 16;

            edges[ _count_edges ]                      = new Predicate();
            edges[ _count_edges ].predicate            = predicate;
            edges[ _count_edges ].objects              = new Objectz[ 1 ];
            edges[ _count_edges ].count_objects        = 1;
            edges[ _count_edges ].objects[ 0 ]         = new Objectz();
            edges[ _count_edges ].objects[ 0 ].literal = object;
            edges[ _count_edges ].objects[ 0 ].lang    = lang;
            _count_edges++;

            needReidex = true;
            return edges[ _count_edges - 1 ].objects[ 0 ];
        }
    }

    void addPredicate(string predicate, Subjects cluster)
    {
        if (cluster is null)
            return;

        Predicate pp;
        for (int i = 0; i < _count_edges; i++)
        {
            if (edges[ i ].predicate == predicate)
            {
                pp = edges[ i ];
                break;
            }
        }

        if (pp !is null)
        {
            pp.addCluster(cluster);
        }
        else
        {
            if (edges.length == 0)
                edges = new Predicate[ 16 ];

            if (edges.length == _count_edges)
                edges.length += 16;

            edges[ _count_edges ]                      = new Predicate;
            edges[ _count_edges ].predicate            = predicate;
            edges[ _count_edges ].objects              = new Objectz[ 1 ];
            edges[ _count_edges ].count_objects        = 1;
            edges[ _count_edges ].objects[ 0 ]         = new Objectz();
            edges[ _count_edges ].objects[ 0 ].cluster = cluster;
            edges[ _count_edges ].objects[ 0 ].type    = OBJECT_TYPE.LINK_CLUSTER;
            _count_edges++;
        }
        needReidex = true;
    }

    void addPredicate(string predicate, Subject subject)
    {
        if (subject is null)
            return;

        Predicate pp;
        for (int i = 0; i < _count_edges; i++)
        {
            if (edges[ i ].predicate == predicate)
            {
                pp = edges[ i ];
                break;
            }
        }
        if (pp !is null)
        {
            pp.addSubject(subject);
        }
        else
        {
            if (edges.length == 0)
                edges = new Predicate[ 16 ];

            if (edges.length == _count_edges)
                edges.length += 16;

            edges[ _count_edges ]                      = new Predicate;
            edges[ _count_edges ].predicate            = predicate;
            edges[ _count_edges ].objects              = new Objectz[ 1 ];
            edges[ _count_edges ].count_objects        = 1;
            edges[ _count_edges ].objects[ 0 ]         = new Objectz();
            edges[ _count_edges ].objects[ 0 ].subject = subject;
            edges[ _count_edges ].objects[ 0 ].type    = OBJECT_TYPE.LINK_SUBJECT;
            _count_edges++;
        }
        needReidex = true;
    }

    void addPredicate(string predicate, Objectz oo)
    {
        Predicate pp;

        for (int i = 0; i < _count_edges; i++)
        {
            if (edges[ i ].predicate == predicate)
            {
                pp = edges[ i ];
                break;
            }
        }
        if (pp !is null)
        {
            pp.addObjectz(oo);
        }
        else
        {
            if (edges.length == 0)
                edges = new Predicate[ 16 ];

            if (edges.length == _count_edges)
                edges.length += 16;

            edges[ _count_edges ]               = new Predicate;
            edges[ _count_edges ].predicate     = predicate;
            edges[ _count_edges ].objects       = new Objectz[ 1 ];
            edges[ _count_edges ].objects[ 0 ]  = oo;
            edges[ _count_edges ].count_objects = 1;
            _count_edges++;
        }
        needReidex = true;
    }

    void addPredicate(Predicate pp)
    {
        if (edges.length == 0)
            edges = new Predicate[ 16 ];

        if (edges.length == _count_edges)
            edges.length += 16;

        edges[ _count_edges ] = pp;
        _count_edges++;

        needReidex = true;
    }

    void addPredicate(string predicate, Objectz[] oo)
    {
        Predicate pp;

        for (int i = 0; i < _count_edges; i++)
        {
            if (edges[ i ].predicate == predicate)
            {
                pp = edges[ i ];
                break;
            }
        }
        if (pp !is null)
        {
            pp.addObjectzs(oo);
        }
        else
        {
            if (edges.length == 0)
                edges = new Predicate[ 16 ];

            if (edges.length == _count_edges)
                edges.length += 16;

            edges[ _count_edges ]               = new Predicate;
            edges[ _count_edges ].predicate     = predicate;
            edges[ _count_edges ].objects       = oo;
            edges[ _count_edges ].count_objects = cast(ushort)oo.length;
            _count_edges++;
        }
        needReidex = true;
    }

    Predicate addPredicate()
    {
        if (edges.length == 0)
            edges = new Predicate[ 16 ];

        if (edges.length == _count_edges)
            edges.length += 16;

        _count_edges++;

        needReidex = true;

        edges[ _count_edges - 1 ] = new Predicate;
        return edges[ _count_edges - 1 ];
    }

    private void reindex_predicate()
    {
        for (short jj = 0; jj < this._count_edges; jj++)
        {
            Predicate pp = this.edges[ jj ];

            this.edges_of_predicate[ pp.predicate ] = pp;

            foreach (oo; pp.getObjects())
            {
                if (oo.type == OBJECT_TYPE.LINK_SUBJECT)
                {
                    oo.subject.reindex_predicate();
                }
                else if (oo.type == OBJECT_TYPE.TEXT_STRING || oo.type == OBJECT_TYPE.URI)
                {
                    pp.objects_of_value[ oo.literal ] = oo;
                }
            }
        }
        needReidex = false;
    }

    Subject dup()
    {
        Subject new_subj = new Subject();

        new_subj.needReidex         = this.needReidex;
        new_subj.subject            = this.subject;
        new_subj.exportPredicates   = this.exportPredicates;
        new_subj.edges              = this.edges.dup;
        new_subj._count_edges       = this._count_edges;
        new_subj.edges_of_predicate = this.edges_of_predicate.dup;

        return new_subj;
    }

    override string toString()
    {
    	OutBuffer ou = new OutBuffer (); 
    	toJson_ld(this, ou, false);
    	return ou.toString ();
    }

    Subject[] get_metadata()
    {
        Subject[] array = new Subject[ _count_edges ];
        for (int i = 0; i < _count_edges; i++)
        {
            array[ i ] = edges[ i ].metadata;
        }
        return array;
    }

}

class Predicate
{
    string            predicate = null;
    private Objectz[] objects;              // начальное количество значений objects.length = 1, если необходимо иное, следует создавать новый массив objects
    short             count_objects = 0;
    Subject           metadata      = null; // свойства данного предиката в виде owl:Restriction

    Objectz[ string ] objects_of_value;

    Objectz[] getObjects()
    {
        return objects[ 0 .. count_objects ];
    }
    

    short length()
    {
        return count_objects;
    }
        
  int opApply(int delegate(ref Objectz) dg)
  {
    int result = 0;

    for (int i = 0; i < count_objects; i++)
    {
      result = dg(objects[i]);
      if (result)
        break;
    }
    return result;
  }    

    Objectz getObject(string literal)
    {
        foreach (oo; objects[ 0 .. count_objects ])
        {
            if (oo.literal == literal)
                return oo;
        }
        return null;
    }

    string getFirstLiteral()
    {
        if (count_objects > 0)
            return objects[ 0 ].literal;

        return null;
    }

    bool isExistLiteral(string value)
    {
        Objectz ooo = objects_of_value.get(value, null);

        if (ooo !is null)
            return true;

        return false;
    }

    Subject getFirstSubject()
    {
        if (count_objects > 0)
        {
            if (objects[ 0 ].type == OBJECT_TYPE.LINK_CLUSTER && objects[ 0 ].cluster.length == 1)
            {
                return objects[ 0 ].cluster.data[ 0 ];
            }

            return objects[ 0 ].subject;
        }
        return null;
    }

    Objectz addLiteral(string val, Subject reification, LANG lang = LANG.NONE)
    {
        if (val is null)
            return null;

        if (objects.length == count_objects)
            objects.length += 16;
        objects[ count_objects ]             = new Objectz;
        objects[ count_objects ].literal     = val;
        objects[ count_objects ].reification = reification;
        objects[ count_objects ].lang        = lang;
        count_objects++;
        return objects[ count_objects - 1 ];
    }

    Objectz addLiteral(string val, LANG lang = LANG.NONE)
    {
        if (val is null)
            return null;

        if (objects.length == count_objects)
            objects.length += 16;
        objects[ count_objects ]         = new Objectz;
        objects[ count_objects ].literal = val;
        objects[ count_objects ].lang    = lang;
        count_objects++;
        return objects[ count_objects - 1 ];
    }
       
    Objectz addLiteral(string val, OBJECT_TYPE type)
    {
        if (val is null)
            return null;

        if (objects.length == count_objects)
            objects.length += 16;
        objects[ count_objects ]         = new Objectz;
        objects[ count_objects ].literal = val;
        objects[ count_objects ].type    = type;
        count_objects++;
        return objects[ count_objects - 1 ];
    }   

    void addCluster(Subjects cl)
    {
        if (cl is null)
            return;

        if (objects.length == count_objects)
            objects.length += 16;
        objects[ count_objects ]         = new Objectz;
        objects[ count_objects ].cluster = cl;
        objects[ count_objects ].type    = OBJECT_TYPE.LINK_CLUSTER;
        count_objects++;
    }

    void addSubject(Subject ss)
    {
        if (ss is null)
            return;

        if (objects.length == count_objects)
            objects.length += 16;
        objects[ count_objects ]         = new Objectz;
        objects[ count_objects ].subject = ss;
        objects[ count_objects ].type    = OBJECT_TYPE.LINK_SUBJECT;
        count_objects++;
    }

    void addObjectz(Objectz oo)
    {
        if (objects.length == count_objects)
            objects.length += 16;
        objects[ count_objects ] = new Objectz;
        objects[ count_objects ] = oo;
        count_objects++;
    }

    void addObjectzs(Objectz[] oo)
    {
        objects       = oo;
        count_objects = cast(ushort)oo.length;
    }

	void opOpAssign(string OP)(Objectz item)
		if (OP=="~")
	{
		addObjectz(item);
	}

	void opOpAssign(string OP)(string item)
		if (OP=="~")
	{
		addLiteral(item);
	}

    override string toString()
    {
        string res = this.predicate;

        if (objects.length > 0)
        {
            res ~= ":";
            if (objects.length == 1)
            {
                res ~= objects[ 0 ].literal;
            }
            else
            {
                res ~= "[";
                bool zpt = false;
                foreach (objz; getObjects())
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

}

class Objectz
{
    string       literal;            // если type == LITERAL | RESOURCE | UNSIGNED_INTEGER | STANDARD_DATE_TIME
    Subject      subject;            // если type == LINK_SUBJECT
    Subjects 	 cluster;            // если type == LINK_CLUSTER

    Subject      reification = null; // реификация для данного значения

    byte         type = OBJECT_TYPE.TEXT_STRING;
    LANG         lang;

    override string toString()
    {
        return literal;
    }
}


