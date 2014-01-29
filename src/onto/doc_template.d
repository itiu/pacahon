module onto.doc_template;

private import std.stdio;

private import pacahon.know_predicates;
private import util.utils; 
private import util.graph;

class DocTemplate
{
    Subject      main;
    Subjects data;

    this()
    {
        data = new Subjects();
    }
    Predicate get_export_predicates()
    {
        if (main is null)
            return null;

        Predicate pp = main.getPredicate(link__exportPredicates);
        return pp;
    }
}