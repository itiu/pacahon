module pacahon.know_predicates;

public string rdf__type = "rdf:type";
public string rdf__subject = "rdf:subject";
public string rdf__predicate = "rdf:predicate";
public string rdf__object = "rdf:object";
public string rdf__Statement = "rdf:Statement";
public string rdf__datatype = "rdf:datatype";

public string rdfs__label = "rdfs:label";

public string xsd__string = "xsd:string";

// http://www.daml.org/services/owl-s/1.0/Process.owl
public string process__Input = "process:Input";
public string process__Output = "process:Output";
public string process__parameterType = "process:parameterType";

public string dc__creator = "dc:creator";

public string msg__Message = "msg:Message";
public string msg__args = "msg:args";
public string msg__reciever = "msg:reciever";
public string msg__ticket = "msg:ticket"; // TODO оставить один, или msg:ticket или auth:ticket
public string msg__sender = "msg:sender";
public string msg__command = "msg:command";
public string msg__status = "msg:status";
public string msg__reason = "msg:reason";
public string msg__result = "msg:result";
public string msg__in_reply_to = "msg:in-reply-to";

public string ticket__Ticket = "ticket:Ticket";
public string ticket__accessor = "ticket:accessor";
public string ticket__when = "ticket:when";
public string ticket__duration = "ticket:duration";

public string auth__ticket = "auth:ticket";
public string auth__credential = "auth:credential";
public string auth__login = "auth:login";

public string pacahon__on_trace_msg = "pacahon:on-trace-msg";
public string pacahon__off_trace_msg = "pacahon:off-trace-msg";
