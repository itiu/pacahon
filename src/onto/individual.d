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
}

struct Individual
{
    string  name;
    Resources[ string ]    properties;
    Class[] classes;

    immutable this(string _name, immutable(Resources[ string ]) _properties, immutable(Class[]) _classes)
    {
        name       = _name;
        properties = _properties;
        classes    = _classes.idup;
    }

    immutable(Individual) idup()
    {
        immutable Resources[ string ]    tmp = assumeUnique(properties);

        immutable(Individual) result = immutable Individual(name, tmp, cast(immutable)classes);
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



    Individual getIndividual(string name, Ticket ticket)
    {
        return Individual.init;
    }

    string putIndividual(string name, Individual individual, Ticket ticket)
    {
        return null;
    }

    string postIndividual(Individual individual, Ticket ticket)
    {
        return null;
    }
}
