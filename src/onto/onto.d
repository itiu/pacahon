/**
 * ONTO
 */

module onto.onto;

private
{
    import std.stdio, std.datetime, std.conv, std.exception : assumeUnique;

    import onto.resource, onto.individual;

    import util.utils, util.container, util.logger;

    import pacahon.know_predicates, pacahon.context, pacahon.interthread_signals, pacahon.log_msg;

    import search.vql;
}

logger log;

static this()
{
    log = new logger("pacahon", "log", "onto");
}

class Onto
{
    private Context context;

    Individual[ string ] individuals;
    immutable(Individual)[ string ] i_individuals;


    public this(Context _context)
    {
        //interthread_signal_id = "onto";
        context = _context;
    }

    immutable(Individual)[ string ] iget_individuals()
    {
        //writeln ("@$1");

        return i_individuals;
    }


    public void load()
    {
        Individual[] l_individuals;

        if (trace_msg[ 20 ] == 1)
            log.trace_log_and_console("[%s] load onto to graph..", context.get_name);

        context.vql().get(null,
                          "return { '*'}
            filter { 'rdf:type' == 'rdfs:Class' || 'rdf:type' == 'rdf:Property' || 'rdf:type' == 'owl:Class' || 'rdf:type' == 'owl:ObjectProperty' || 'rdf:type' == 'owl:DatatypeProperty' }",
                          l_individuals);

        if (trace_msg[ 20 ] == 1)
            log.trace_log_and_console("[%s] count individuals: %d", context.get_name, l_individuals.length);

        foreach (indv; l_individuals)
        {
            individuals[ indv.uri ]   = indv;
            i_individuals[ indv.uri ] = indv.idup;
        }

        if (trace_msg[ 20 ] == 1)
            log.trace_log_and_console("[%s] load onto to graph..Ok", context.get_name);
    }
}
