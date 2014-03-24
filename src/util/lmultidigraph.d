module util.lmultidigraph;

private import std.stdio, std.string;
private import onto.resource;
private import onto.lang;
private import dgraph.graph;
private import util.cbor;
private import util.container;

struct HeadTail
{
    size_t head;
    size_t tail;
}

static size_t NONE = size_t.max;

class LabeledMultiDigraph
{
    Resource[] elements;
    size_t[ string ] idx_2_uri;
    size_t[][ HeadTail ] ledges_2_head_tail;

    IndexedEdgeList!true graph;

    this()
    {
        graph = new IndexedEdgeList!true;
    }

    size_t getIdxOfResource (string uri)
    {
    	return idx_2_uri.get (uri, NONE);
    }

    Set!Resource getHeads()
    {
        Set!Resource res;

        foreach (hh; idx_2_uri.values)
        {
            res ~= elements[ hh ];
        }

        return res;
    }

    bool isExsistsEdge(Resource head, string edge_str, string tail_str)
    {
        size_t   idx_edge = idx_2_uri.get(edge_str, NONE);
        size_t   idx_tail = idx_2_uri.get(tail_str, NONE);

        HeadTail ht;

        ht.head = head.get_idx ();
        ht.tail = idx_tail;

        size_t[] edge_idxs = ledges_2_head_tail.get(ht, size_t[].init);

        return std.algorithm.canFind(edge_idxs, idx_edge);
    }

    Set!Resource getTail(Resource head, string edge_str)
    {
        Set!Resource res;

        size_t   idx_edge = idx_2_uri.get(edge_str, NONE);
        auto     nb       = graph.neighboursOut(head.get_idx ());

        HeadTail ht;
        ht.head = head.get_idx ();

        int idx;
        foreach (nn; nb)
        {
            //writeln ("@1, nn=", elements[ nn ]);

            ht.tail = nn;

            size_t[] edge_idxs = ledges_2_head_tail.get(ht, size_t[].init);

            if (std.algorithm.canFind(edge_idxs, idx_edge))
            {
                res ~= elements[ nn ];
            }
        }

        return res;
    }
    Set!Resource getTail(size_t head_idx, string edge_str)
    {
        Set!Resource res;
        size_t   idx_edge = idx_2_uri.get(edge_str, NONE);
        auto     nb       = graph.neighboursOut(head_idx);

        HeadTail ht;
        ht.head = head_idx;

        int idx;
        foreach (nn; nb)
        {
            ht.tail = nn;

            size_t[] edge_idxs = ledges_2_head_tail.get(ht, size_t[].init);

            if (std.algorithm.canFind(edge_idxs, idx_edge))
                res ~= elements[ nn ];
        }

        return res;
    }

    size_t addEdge(size_t idx_head, size_t idx_edge, string tail_str, ResourceType type = ResourceType.Uri, LANG lang = LANG.NONE)
    {
//        writeln ("@1 lmg=,", cast(void*)this, ", graph=", cast(void*)graph);

        size_t idx_tail = idx_2_uri.get(tail_str, NONE);

        if (idx_tail == NONE)
        {
            Resource tail;
            tail.data = tail_str;
            tail.type = type;
            if (tail.type == ResourceType.Uri)
            {
            	if (tail.data.indexOf ('/') > 0)
            		tail.origin = ResourceOrigin.external;
            }
            
            tail.lang = lang;
            tail.set_idx (elements.length);
            elements ~= tail;
            idx_tail = elements.length - 1;
            if (tail.type == ResourceType.Uri)
                idx_2_uri[ tail_str ] = idx_tail;
        }
        
        //writeln ("@3 head=", elements[idx_head].uri);
        //writeln ("@3 edge=", elements[idx_edge].uri);
        //writeln ("@3 tail=", tail_str);

        HeadTail ht;
        ht.head = idx_head;
        ht.tail = idx_tail;

//        writeln ("@3");
        size_t[] edge_idxs = ledges_2_head_tail.get(ht, size_t[].init);

//        writeln ("@4 edge_idxs=", edge_idxs);

        if (edge_idxs.length == 0 || (edge_idxs.length > 0 && std.algorithm.canFind(edge_idxs, idx_edge) == false))
            edge_idxs ~= idx_edge;

        ledges_2_head_tail[ ht ] = edge_idxs;
//        writeln ("@4.1");

        size_t curr_count_vertex = graph.vertexCount;
//      writeln ("@5 idx_head=", idx_head, ", idx_tail=", idx_tail, ", graph.vertexCount=", graph.vertexCount);

        graph.vertexCount = std.algorithm.max(idx_tail, idx_head, curr_count_vertex) + 1;
//        writeln ("addEdge ", idx_head, ":", idx_tail);
        graph.addEdge(idx_head, idx_tail);
//      writeln ("@6");

        return idx_tail;
    }

    size_t addResource(string rr_str, ResourceType type = ResourceType.Uri)
    {
        size_t idx_resource = NONE;

        if (type == ResourceType.Uri)
        {
            idx_resource = idx_2_uri.get(rr_str, NONE);

            if (idx_resource == NONE)
            {
                Resource rr;
                rr.data = rr_str;
                rr.type = type;
            if (rr.type == ResourceType.Uri)
            {
            	if (rr.data.indexOf ('/') > 0)
            		rr.origin = ResourceOrigin.external;
            }                
                rr.set_idx(elements.length);

                elements ~= rr;
                idx_resource = elements.length - 1;

                idx_2_uri[ rr_str ] = idx_resource;
            }
        }

        return idx_resource;
    }

//------------------------------------------------------------------------------------------------ 8><

    size_t addResource1(Resource rr)
    {
        size_t idx_rr = idx_2_uri.get(rr.uri, NONE);

        if (idx_rr == NONE)
        {
            rr.set_idx (elements.length);
            elements ~= rr;
            idx_2_uri[ rr.uri ] = elements.length - 1;
        }
        return idx_rr;
    }

    size_t addResource1()
    {
        Resource rr = Resource.init;

        rr.set_idx (elements.length);
        elements ~= rr;

        return elements.length - 1;
    }

    void setIndividual1(size_t idx_rr, Resource rr)
    {
        if (rr.type == ResourceType.Uri)
            idx_2_uri[ rr.uri ] = idx_rr;
    }

    void setResource1(size_t idx_rr, string rr_str, ResourceType type = ResourceType.Uri)
    {
        Resource rr;

        rr.data = rr_str;
        rr.type = type;
        rr.set_idx (idx_rr);
        if (rr.type == ResourceType.Uri)
            idx_2_uri[ rr.uri ] = idx_rr;
    }
}
