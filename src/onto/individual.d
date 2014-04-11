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

    immutable this(string _uri, immutable(Resources[ string ]) _resources)
    {
        uri       = _uri;
        resources = _resources;
    }

    immutable(Individual) idup()
    {
        resources.rehash();
        immutable Resources[ string ]    tmp1 = assumeUnique(resources);

        immutable(Individual) result = immutable Individual(uri, tmp1);
        return result;
    }

    Resource getFirstResource(string predicate)
    {
        Resources rss;

        rss = resources.get(predicate, rss);
        if (rss.length > 0)
            return rss[ 0 ];

        return Resource.init;
    }

    immutable Resource getFirstResource(string predicate)
    {
        immutable Resources rss = resources.get(predicate, (immutable Resources).init);

        if (rss.length > 0)
            return rss[ 0 ];

        return Resource.init;
    }

    Resources getResources(string predicate)
    {
        Resources rss;

        rss = resources.get(predicate, rss);
        return rss;
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
