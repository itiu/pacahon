module util.lmultidigraph;

private import std.algorithm, std.stdio;
private import dgraph.graph;
private import util.cbor;

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
    size_t[ Resource ] idx_2_individual;
    size_t[][ HeadTail ] ledges_2_head_tail;

    IndexedEdgeList!true graph;
    
    this ()
    {
     	graph = new IndexedEdgeList!true;    	
    }

    void addEdge(size_t idx_head, string edge_str, string tail_str)
    {
        Resource edge;

        edge.data = edge_str;
        size_t idx_edge = idx_2_individual.get(edge, NONE);
        if (idx_edge == NONE)
        {
            elements ~= edge;
            idx_edge = elements.length - 1;            
            
            idx_2_individual[ edge ] = idx_edge;
        }

        Resource tail;
        tail.data = tail_str;
        size_t   idx_tail = idx_2_individual.get(tail, NONE);
        if (idx_tail == NONE)
        {
            elements ~= tail;
            idx_tail = elements.length - 1;            

            if (tail.type == ResourceType.Individual)
                idx_2_individual[ tail ] = idx_tail;
        }

        HeadTail ht;
        ht.head = idx_head;
        ht.tail = idx_tail;

        size_t[] edge_idxs = ledges_2_head_tail.get(ht, size_t[].init);

        if (canFind(edge_idxs, idx_edge) == false)
            edge_idxs ~= idx_edge;
        ledges_2_head_tail[ ht ] = edge_idxs;

        graph.vertexCount = graph.vertexCount + 2;
        graph.addEdge(idx_head, idx_tail);
    }

    void addEdge(size_t idx_head, string edge_str, size_t idx_tail)
    {
        Resource edge;

        edge.data = edge_str;
        size_t idx_edge = idx_2_individual.get(edge, NONE);
        if (idx_edge == NONE)
        {
            elements ~= edge;
            idx_edge = elements.length - 1;
            
            idx_2_individual[ edge ] = idx_edge;
        }

        HeadTail ht;
        ht.head = idx_head;
        ht.tail = idx_tail;

        size_t[] edge_idxs = ledges_2_head_tail.get(ht, size_t[].init);

        if (canFind(edge_idxs, idx_edge) == false)
            edge_idxs ~= idx_edge;
        ledges_2_head_tail[ ht ] = edge_idxs;

        graph.vertexCount = graph.vertexCount + 2;
        graph.addEdge(idx_head, idx_tail);
    }

    void addEdge(size_t idx_head, size_t idx_edge, string tail_str)
    {
        Resource tail;
        
//        writeln ("@1 lmg=,", cast(void*)this, "graph=", cast(void*)graph);
        
        tail.data = tail_str;
        size_t idx_tail = idx_2_individual.get(tail, NONE);
        if (idx_tail == NONE)
        {
            elements ~= tail;
            idx_tail = elements.length - 1;
            if (tail.type == ResourceType.Individual)
                idx_2_individual[ tail ] = idx_tail;
        }
//        writeln ("@2");

        HeadTail ht;
        ht.head = idx_head;
        ht.tail = idx_tail;

//        writeln ("@3");
        size_t[] edge_idxs = ledges_2_head_tail.get(ht, size_t[].init);

//        writeln ("@4 edge_idxs=", edge_idxs);
        
        if (edge_idxs.length > 0 && canFind(edge_idxs, idx_edge) == false)
            edge_idxs ~= idx_edge;
        ledges_2_head_tail[ ht ] = edge_idxs;
//        writeln ("@4.1");

//    	writeln ("@5 idx_head=", idx_head, ", idx_tail=", idx_tail, ", graph.vertexCount=", graph.vertexCount);
        graph.vertexCount = max (idx_tail, idx_head) + 1;
        graph.addEdge(idx_head, idx_tail);
//    	writeln ("@6");
    }

    size_t addResource(string rr_str, ResourceType type = ResourceType.Individual)
    {
        Resource rr;

        rr.data = rr_str;
        rr.type = type;

        elements ~= Resource.init;
        size_t idx_rr = elements.length - 1;

        if (rr.type == ResourceType.Individual)
            idx_2_individual[ rr ] = idx_rr;

        return idx_rr;
    }

    size_t addResource(Resource rr)
    {
        size_t idx_rr = idx_2_individual.get(rr, NONE);

        if (idx_rr == NONE)
        {
            elements ~= rr;
            idx_2_individual[ rr ] = elements.length - 1;
        }
        return idx_rr;
    }

    size_t addResource()
    {
        elements ~= Resource.init;
        return elements.length - 1;
    }

    void setIndividual(size_t idx_rr, Resource rr)
    {
        if (rr.type == ResourceType.Individual)
            idx_2_individual[ rr ] = idx_rr;
    }

    void setResource(size_t idx_rr, string rr_str, ResourceType type = ResourceType.Individual)
    {
        Resource rr;

        rr.data = rr_str;
        rr.type = type;
        if (rr.type == ResourceType.Individual)
            idx_2_individual[ rr ] = idx_rr;
    }
}
