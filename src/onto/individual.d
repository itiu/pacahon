module onto.individual;

private import onto.resource;

private
{
    import std.stdio, std.typecons, std.conv, std.exception : assumeUnique;

    import onto.owl;

    import pacahon.know_predicates;
    import pacahon.context;
    import util.utils;
    import util.container;
    import util.cbor8individual;
}

alias Individual[] Individuals;

struct Individual
{
    string uri;
    Resources[ string ]    resources;
    Individuals[ string ]  individuals;

    immutable this(string _uri, immutable(Resources[ string ]) _resources, immutable(Individuals[ string ]) _individuals)
    {
        uri         = _uri;
        resources   = _resources;
        individuals = _individuals;
    }

    immutable(Individual) idup()
    {
        resources.rehash();
        immutable Resources[ string ]    tmp1 = assumeUnique(resources);

        individuals.rehash();
        immutable Individuals[ string ]    tmp2 = assumeUnique(individuals);

        immutable(Individual) result = immutable Individual(uri, tmp1, tmp2);
        return result;
    }
}

class Individual_IO
{
    Context context;

    public this(Context _context)
    {
        context = _context;
    }

    immutable(Individual)[] getIndividualsViaQuery(string query_str, Ticket ticket, byte level = 0)
    {
        immutable(Individual)[] res;
        context.vql.get(&ticket, query_str, res);
        return res;
    }

    Individual getIndividual(string uri, Ticket ticket, byte level = 0)
    {
        string     individual_as_cbor = context.get_subject_as_cbor(uri);

        Individual individual = Individual();

        cbor_to_individual(&individual, individual_as_cbor);

        while (level > 0)
        {
            foreach (key, values; individual.resources)
            {
                Individuals ids;
                foreach (ruri; values)
                {
                    ids ~= getIndividual(ruri.uri, ticket, level);
                }
                individual.individuals[ key ] = ids;
            }

            level--;
        }

        return individual;
    }

    string putIndividual(string uri, Individual individual, Ticket ticket)
    {
        return null;
    }

    string postIndividual(Individual individual, Ticket ticket)
    {
        return null;
    }
}
