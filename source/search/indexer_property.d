/**
 * indexer property
 */

module search.indexer_property;

private import pacahon.context, pacahon.log_msg;
private import onto.resource, onto.lang, onto.individual;

// ////// logger ///////////////////////////////////////////
private import util.logger;
logger _log;
logger log()
{
    if (_log is null)
        _log = new logger("pacahon", "log", "search");
    return _log;
}
// ////// ////// ///////////////////////////////////////////

class IndexerProperty
{
    private Context context;

    private         Individual[ string ] class_property__2__indiviual;
    private         string[ string ] class__2__database;
    private         Individual[ string ] uri__2__indiviual;
    private         bool[ string ]  database__2__true;

    this(Context _context)
    {
        context = _context;
    }

    bool[ string ] get_dbnames()
    {
        return database__2__true.dup;
    }

    string get_dbname_of_class(string uri)
    {
        return class__2__database.get(uri, "base");
    }

    Individual get_index(string uri)
    {
        return uri__2__indiviual.get(uri, Individual.init);
    }

    Individual get_index(string uri, string predicate)
    {
        return class_property__2__indiviual.get(uri ~ predicate, Individual.init);
    }

    Individual get_index_of_property(string predicate)
    {
        return class_property__2__indiviual.get(predicate, Individual.init);
    }

    void load()
    {
        if (class_property__2__indiviual.length == 0)
        {
   	        context.reopen_ro_subject_storage_db();
        	context.reopen_ro_fulltext_indexer_db();

            Individual[] l_individuals;
//            context.vql().reopen_db();
            context.vql().get(null, "return { '*' } filter { 'rdf:type' == 'vdi:ClassIndex' }", l_individuals, true);

            foreach (indv; l_individuals)
            {
                uri__2__indiviual[ indv.uri ] = indv;
                Resources forClasses    = indv.resources.get("vdi:forClass", Resources.init);
                Resources forProperties = indv.resources.get("vdi:forProperty", Resources.init);

                Resources indexed_to = indv.resources.get("vdi:indexed_to", Resources.init);

                if (forClasses.length == 0)
                    forClasses ~= Resource.init;

                if (forProperties.length == 0)
                    forProperties ~= Resource.init;

                foreach (forClass; forClasses)
                {
                    if (indexed_to.length > 0)
                    {
//                      writeln ("@1 indexed_as_system=", indexed_as_system, ", indexed_as_system[0]=", indexed_as_system[0]);
                        class__2__database[ forClass.uri ]              = indexed_to[ 0 ].get!string;
                        database__2__true[ indexed_to[ 0 ].get!string ] = true;
                    }

                    foreach (forProperty; forProperties)
                    {
                        string key = forClass.uri ~ forProperty.uri;
                        class_property__2__indiviual[ key ] = indv;

                        if (trace_msg[ 214 ] == 1)
                            log.trace("search indexes, key=%s, uri=%s", key, indv.uri);
                    }
                }
            }
            database__2__true[ "base" ] = true;
            std.stdio.writeln ("@@1 class__2__database=", class__2__database);
        }
    }
}

