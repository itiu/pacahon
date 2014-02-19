module util.lmultidigraph;

private import std.algorithm, std.stdio;
private import dgraph.graph;
private import util.cbor;
private import util.container;

enum LANG : ubyte
{
    NONE = 0,
    RU   = 1,
    EN   = 2
}

enum ResourceType : ubyte
{
    Individual,
    String,
    Integer,
    Datetime,
    Float
}

struct Resource
{
	size_t idx;
    ResourceType type = ResourceType.Individual;
    string       data;
    LANG         lang = LANG.NONE;
}

struct HeadTail
{
    size_t head;
    size_t tail;
}

static size_t NONE = size_t.max;

class LabeledMultiDigraph
{
    Resource[] elements;
    size_t[ string ] idx_2_individual;
    size_t[][ HeadTail ] ledges_2_head_tail;

    IndexedEdgeList!true graph;

    this()
    {
        graph = new IndexedEdgeList!true;
    }

    Set!Resource getHeads()
    {
        Set!Resource res;

        foreach (hh ; idx_2_individual.values)
        {
        	res ~= elements[ hh ];
        }
    	
    	return res;
    }

    bool isExsistsEdge (Resource head, string edge_str, string tail_str)
    {
    	size_t     idx_edge = idx_2_individual.get(edge_str, NONE);
    	size_t     idx_tail = idx_2_individual.get(tail_str, NONE);
    	
    	HeadTail ht;
        ht.head = head.idx;
        ht.tail = idx_tail;
        
        size_t[] edge_idxs = ledges_2_head_tail.get(ht, size_t[].init);

        return canFind(edge_idxs, idx_edge);    	
    }

    Set!Resource getTail(Resource head, string edge_str)
    {
        Set!Resource res;

    	size_t     idx_edge = idx_2_individual.get(edge_str, NONE);
        auto nb = graph.neighboursOut(head.idx);

        HeadTail ht;
        ht.head = head.idx;

        int idx;
        foreach (nn; nb)
        {
        	//writeln ("@1, nn=", elements[ nn ]);
        	
                ht.tail = nn;
                
                size_t[] edge_idxs = ledges_2_head_tail.get(ht, size_t[].init);
                
                if (canFind(edge_idxs, idx_edge))
                {
                	res ~= elements[ nn ];
                }
        }
            
        return res;
    }
    Set!Resource getTail(size_t head_idx, string edge_str)
    {
        Set!Resource res;
    	size_t     idx_edge = idx_2_individual.get(edge_str, NONE);
        auto nb = graph.neighboursOut(head_idx);

        HeadTail ht;
        ht.head = head_idx;

        int idx;
        foreach (nn; nb)
        {
                ht.tail = nn;
                
                size_t[] edge_idxs = ledges_2_head_tail.get(ht, size_t[].init);
                
                if (canFind(edge_idxs, idx_edge))
                	res ~= elements[ nn ];
        }
            
        return res;
    }


    Resource[] getEdges1(string head_str)
    {
        Resource[] res;

        size_t     idx_head = idx_2_individual.get(head_str, NONE);

        if (idx_head != NONE)
        {
            writeln("#idx_head=>", idx_head);
            auto nb = graph.neighboursOut(idx_head);

            res = new Resource[ nb.length() ];
            
            HeadTail ht;
            ht.head = idx_head;

            int idx;
            foreach (nn; nb)
            {
                res[ idx++ ] = elements[ nn ];
                ht.tail = nn;
                writeln ("@=", elements[ledges_2_head_tail[ht][0]]);
                writeln("#neighbours=>", elements[ nn ]);
            }
        }
        return res;
    }
/*
    void addEdge(size_t idx_head, string edge_str, string tail_str)
    {
        size_t idx_edge = idx_2_individual.get(edge_str, NONE);

        if (idx_edge == NONE)
        {
            Resource edge;
            edge.data = edge_str;
            elements ~= edge;
            idx_edge = elements.length - 1;

            idx_2_individual[ edge_str ] = idx_edge;
        }

        size_t idx_tail = idx_2_individual.get(tail_str, NONE);
        if (idx_tail == NONE)
        {
            Resource tail;
            tail.data = tail_str;
            elements ~= tail;
            idx_tail = elements.length - 1;

            if (tail.type == ResourceType.Individual)
                idx_2_individual[ tail_str ] = idx_tail;
        }

        HeadTail ht;
        ht.head = idx_head;
        ht.tail = idx_tail;

        size_t[] edge_idxs = ledges_2_head_tail.get(ht, size_t[].init);

        if (canFind(edge_idxs, idx_edge) == false)
            edge_idxs ~= idx_edge;
        ledges_2_head_tail[ ht ] = edge_idxs;

        graph.vertexCount = graph.vertexCount + 2;
        writeln("addEdge ", idx_head, ":", idx_tail);
        graph.addEdge(idx_head, idx_tail);
    }
*/
/*    
    void addEdge(size_t idx_head, string edge_str, size_t idx_tail)
    {
        size_t idx_edge = idx_2_individual.get(edge_str, NONE);

        if (idx_edge == NONE)
        {
            Resource edge;
            edge.data = edge_str;
            elements ~= edge;
            idx_edge = elements.length - 1;

            idx_2_individual[ edge_str ] = idx_edge;
        }

        HeadTail ht;
        ht.head = idx_head;
        ht.tail = idx_tail;

        size_t[] edge_idxs = ledges_2_head_tail.get(ht, size_t[].init);

        if (canFind(edge_idxs, idx_edge) == false)
            edge_idxs ~= idx_edge;
        ledges_2_head_tail[ ht ] = edge_idxs;

        graph.vertexCount = graph.vertexCount + 2;
        writeln("addEdge ", idx_head, ":", idx_tail);
        graph.addEdge(idx_head, idx_tail);
    }
*/
    size_t addEdge(size_t idx_head, size_t idx_edge, string tail_str, ResourceType type = ResourceType.Individual, LANG lang = LANG.NONE)
    {
//        writeln ("@1 lmg=,", cast(void*)this, ", graph=", cast(void*)graph);

        size_t idx_tail = idx_2_individual.get(tail_str, NONE);

        if (idx_tail == NONE)
        {
            Resource tail;
            tail.data = tail_str;
            tail.type = type;
            tail.lang = lang;
            tail.idx = elements.length;  
            elements ~= tail;
            idx_tail = elements.length - 1;
            if (tail.type == ResourceType.Individual)
                idx_2_individual[ tail_str ] = idx_tail;
        }
//        writeln ("@2");

        HeadTail ht;
        ht.head = idx_head;
        ht.tail = idx_tail;

//        writeln ("@3");
        size_t[] edge_idxs = ledges_2_head_tail.get(ht, size_t[].init);

//        writeln ("@4 edge_idxs=", edge_idxs);

        if (edge_idxs.length == 0 || (edge_idxs.length > 0 && canFind(edge_idxs, idx_edge) == false))
            edge_idxs ~= idx_edge;
            
        ledges_2_head_tail[ ht ] = edge_idxs;
//        writeln ("@4.1");

        size_t curr_count_vertex = graph.vertexCount;
//      writeln ("@5 idx_head=", idx_head, ", idx_tail=", idx_tail, ", graph.vertexCount=", graph.vertexCount);

        graph.vertexCount = max(idx_tail, idx_head, curr_count_vertex) + 1;
//        writeln ("addEdge ", idx_head, ":", idx_tail);
        graph.addEdge(idx_head, idx_tail);
//      writeln ("@6");
        
        return idx_tail;
    }

    size_t addResource(string rr_str, ResourceType type = ResourceType.Individual)
    {
        size_t idx_resource = NONE;

        if (type == ResourceType.Individual)
        {
            idx_resource = idx_2_individual.get(rr_str, NONE);

            if (idx_resource == NONE)
            {
                Resource rr;
                rr.data = rr_str;
                rr.type = type;
                rr.idx = elements.length;

                elements ~= rr;
                idx_resource = elements.length - 1;

                idx_2_individual[ rr_str ] = idx_resource;
            }
        }

        return idx_resource;
    }

    size_t addResource(Resource rr)
    {
        size_t idx_rr = idx_2_individual.get(rr.data, NONE);

        if (idx_rr == NONE)
        {
        	rr.idx = elements.length; 
            elements ~= rr;
            idx_2_individual[ rr.data ] = elements.length - 1;
        }
        return idx_rr;
    }

    size_t addResource()
    {
    	Resource rr = Resource.init;
    	rr.idx = elements.length; 
        elements ~= rr;
        
        return elements.length - 1;
    }

    void setIndividual(size_t idx_rr, Resource rr)
    {
        if (rr.type == ResourceType.Individual)
            idx_2_individual[ rr.data ] = idx_rr;
    }

    void setResource(size_t idx_rr, string rr_str, ResourceType type = ResourceType.Individual)
    {
        Resource rr;

        rr.data = rr_str;
        rr.type = type;
        rr.idx = idx_rr;
        if (rr.type == ResourceType.Individual)
            idx_2_individual[ rr.data ] = idx_rr;
    }
}