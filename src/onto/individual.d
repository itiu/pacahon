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

    bool isExist(string predicate, string object)
    {
        Resources rss;

        rss = resources.get(predicate, rss);
        foreach (rs; rss)
        {
            if (rs.data == object)
                return true;
        }
        return false;
    }

    bool anyExist(string predicate, string[] objects)
    {
        Resources rss;

        rss = resources.get(predicate, rss);
        foreach (rs; rss)
        {
            foreach (object; objects)
            {
                if (rs.data == object)
                    return true;
            }
        }
        return false;
    }
}
