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
    Property[ string ]  properties;
    Class[ string ] classes;

    immutable this(string _uri, immutable(Resources[ string ]) _resources, immutable(Individuals[ string ]) _individuals,
                   immutable(Property[ string ]) _properties,
                   immutable(Class[ string ]) _classes)
    {
        uri         = _uri;
        resources   = _resources;
        properties  = _properties;
        individuals = _individuals;
        classes     = _classes;
    }

    immutable(Individual) idup()
    {
        resources.rehash();
        immutable Resources[ string ]    tmp1 = assumeUnique(resources);

        individuals.rehash();
        immutable Individuals[ string ]    tmp2 = assumeUnique(individuals);

        properties.rehash();
        immutable Property[ string ]    tmp3 = assumeUnique(properties);

        classes.rehash();
        immutable Class[ string ]    tmp4 = assumeUnique(classes);

        immutable(Individual) result = immutable Individual(uri, tmp1, tmp2, tmp3, tmp4);
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

    Individual getIndividual(string uri, Ticket ticket, byte level = 0)
    {
        string     individual_as_cbor = context.get_subject_as_cbor(uri);

        Individual individual = Individual();

        cbor_to_individual(&individual, individual_as_cbor);

        Resource[] types = individual.resources.get(rdf__type, null);

        if (types !is null)
        {
            foreach (type; types)
            {
                individual.classes[ type.uri ] = *context.get_class(type.uri);
            }
        }

        foreach (resr; individual.resources.keys)
        {
            Property *pp = context.get_property(resr);
            if (pp !is null)
            {
        	individual.properties[ resr ] = *pp;
            }
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
