module onto.rdf_base;

private import std.stdio;
private import std.uuid;
private import pacahon.know_predicates;
private import util.graph;

Subject create_reifed_info(string ss, string pp, string oo)
{
    Subject new_subj = new Subject();

    UUID    new_id = randomUUID();

    new_subj.subject = "r" ~ new_id.toString()[ 0..8 ];

    new_subj.addPredicate(rdf__type, rdf__Statement);
    new_subj.addPredicate(rdf__subject, ss);
    new_subj.addPredicate(rdf__predicate, pp);
    new_subj.addPredicate(rdf__object, oo);

//	writeln("create_reifed_info s=", ss, ", p=", pp, ", o=", oo);
    return new_subj;
}
