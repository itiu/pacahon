module pacahon.know_predicates;

public const string owl__Ontology    = "owl:Ontology";
public const string owl__versionInfo = "owl:versionInfo";
public const string rdf__Property    = "rdf:Property";
//public const string       owl__imports = "owl:imports";
public const string owl__Restriction = "owl:Restriction";
//public const string       owl__hasPart        = "owl:hasPart";
public const string owl__onProperty       = "owl:onProperty";
public const string owl__allValuesFrom    = "owl:allValuesFrom";
public const string owl__someValuesFrom   = "owl:someValuesFrom";
public const string owl__maxCardinality   = "owl:maxCardinality";
public const string owl__minCardinality   = "owl:minCardinality";
public const string owl__ObjectProperty   = "owl:ObjectProperty";
public const string owl__DatatypeProperty = "owl:DatatypeProperty";
public const string owl__unionOf          = "owl:unionOf";
public const string owl__Thing            = "owl:Thing";
public const string owl__Class            = "owl:Class";

//public const string veda__mandat	= "veda:mandat";
public const string veda_schema__script              = "veda-schema:script";
public const string veda_schema__login               = "veda-schema:login";
public const string veda_schema__password            = "veda-schema:password";
public const string veda_schema__PermissionStatement = "veda-schema:PermissionStatement";
public const string veda_schema__canCreate           = "veda-schema:canCreate";
public const string veda_schema__canDelete           = "veda-schema:canDelete";
public const string veda_schema__canRead             = "veda-schema:canRead";
public const string veda_schema__canUpdate           = "veda-schema:canUpdate";
public const string veda_schema__created             = "veda-schema:created";
public const string veda_schema__permissionObject    = "veda-schema:permissionObject";
public const string veda_schema__permissionSubject   = "veda-schema:permissionSubject";
public const string veda_schema__AllResourcesGroup   = "veda-schema:AllResourcesGroup";

public const string veda_schema__resource   = "veda-schema:resource";
public const string veda_schema__memberOf   = "veda-schema:memberOf";
public const string veda_schema__Membership = "veda-schema:Membership";
public const string veda_schema__owner      = "veda-schema:owner";

public string[]     owl_tags = [ rdf__Property, owl__Restriction, owl__ObjectProperty, owl__DatatypeProperty ];
//--------------------------------------------------------------------------------

public const string rdf__type      = "rdf:type";
public const string rdf__subject   = "rdf:subject";
public const string rdf__predicate = "rdf:predicate";
public const string rdf__object    = "rdf:object";
public const string rdf__Statement = "rdf:Statement";
//public const string rdf__datatype  = "rdf:datatype";

public const string rdfs__Class      = "rdfs:Class";
public const string rdfs__subClassOf = "rdfs:subClassOf";
public const string rdfs__label      = "rdfs:label";
public const string rdfs__comment    = "rdfs:comment";
public const string rdfs__domain     = "rdfs:domain";


//http://www.w3.org/TR/2001/REC-xmlschema-2-20010502/#datatype
public const string xsd__string   = "xsd:string";
public const string xsd__boolean  = "xsd:boolean";
public const string xsd__dateTime = "xsd:dateTime";
public const string xsd__decimal  = "xsd:decimal";

// http://www.daml.org/services/owl-s/1.0/Process.owl
//public const string process__Input         = "process:Input";
//public const string process__Output        = "process:Output";
//public const string process__parameterType = "process:parameterType";

public const string dc__creator = "dc:creator";
//public const string dc__dateSubmitted = "dc:dateSubmitted";
public const string dc__modified   = "dc:modified";
public const string dc__created    = "dc:created";
public const string dc__identifier = "dc:identifier";
//public const string dc__subject       = "dc:subject";
public const string dc__title = "dc:title";
//public const string dc__type = "dc:type";
//public const string dc__description = "dc:description";
public const string dc__hasPart = "dc:hasPart";

// swrc
//public const string swrc__Employee   = "swrc:Employee";
//public const string swrc__Person     = "swrc:Person";
//public const string swrc__Department = "swrc:Department";
//public const string swrc__lastName   = "swrc:lastName";
//public const string swrc__firstName  = "swrc:firstName";
//public const string swrc__name       = "swrc:name";
//public const string swrc__email      = "swrc:email";
//public const string swrc__phone      = "swrc:phone";

public const string msg__Message     = "msg:Message";
public const string msg__args        = "msg:args";
public const string msg__reciever    = "msg:reciever";
public const string msg__ticket      = "msg:ticket"; // TODO оставить один, или msg:ticket или auth:ticket
public const string msg__sender      = "msg:sender";
public const string msg__command     = "msg:command";
public const string msg__status      = "msg:status";
public const string msg__reason      = "msg:reason";
public const string msg__result      = "msg:result";
public const string msg__in_reply_to = "msg:in-reply-to";

public const string ticket__Ticket               = "ticket:Ticket";
public const string ticket__accessor             = "ticket:accessor";
public const string ticket__parentUnitOfAccessor = "ticket:parentUnitOfAccessor";
public const string ticket__when                 = "ticket:when";
public const string ticket__duration             = "ticket:duration";

public const string auth__Authenticated = "auth:Authenticated";
//public const string auth__ticket        = "auth:ticket";
public const string auth__credential = "auth:credential";
public const string auth__login      = "auth:login";

public const string pacahon__on_trace_msg  = "pacahon:on-trace-msg";
public const string pacahon__off_trace_msg = "pacahon:off-trace-msg";

public const string query__all_predicates = "query:all_predicates";
public const string query__get_reifed     = "query:get_reifed";
public const string query__get            = "query:get";

public const string event__Event = "event:Event";               // субьект типа Событие
//public const string event__autoremove   = "event:autoremove";   // если == "yes", фильтр должен будет удален после исполнения
//public const string event__subject_type = "event:subject_type"; // тип отслеживаемого субьекта
//public const string event__when         = "event:when";         // after/before
//public const string event__condition    = "event:condition";    // условие связанное с содержимым отслеживаемого субьекта
//public const string event__to           = "event:to";           // кому отсылать сообщение - алиас для адреса сервиса - получателя сообщений
//public const string event__msg_template = "event:msg_template"; // шаблон для сборки отправляемого сообщения

