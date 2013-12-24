module pacahon.know_predicates;

public static const byte _NONE = 0;
public static const byte _RU   = 1;
public static const byte _EN   = 2;

public const string owl__Ontology 	  	= "owl:Ontology";
public const string owl__versionInfo 	= "owl:versionInfo";






//classes
public const static string prefix_tmpl        = "uo:template_";
public const static string prefix_restriction = "uo:rstr_";

// individuals
public const static string prefix_doc = "zdb:doc_";
//public const static string prefix_person = "zdb:person_";
//public const static string prefix_department = "zdb:dep_";

public const string rdf__type      = "a"; // TODO a == rdf:type
public const string rdf__subject   = "rdf:subject";
public const string rdf__predicate = "rdf:predicate";
public const string rdf__object    = "rdf:object";
public const string rdf__Statement = "rdf:Statement";
public const string rdf__datatype  = "rdf:datatype";

public const string rdfs__Class      = "rdfs:Class";
public const string rdfs__subClassOf = "rdfs:subClassOf";
public const string rdfs__label      = "rdfs:label";
public const string rdfs__comment    = "rdfs:comment";

//public const string owl__imports = "owl:imports";
public const string owl__Restriction    = "owl:Restriction";
public const string owl__hasPart        = "owl:hasPart";
public const string owl__onProperty     = "owl:onProperty";
public const string owl__allValuesFrom  = "owl:allValuesFrom";
public const string owl__someValuesFrom = "owl:someValuesFrom";
public const string owl__maxCardinality = "owl:maxCardinality";
public const string owl__minCardinality = "owl:minCardinality";

//http://www.w3.org/TR/2001/REC-xmlschema-2-20010502/#datatype
public const string xsd__string   = "xsd:string";
public const string xsd__boolean  = "xsd:boolean";
public const string xsd__dateTime = "xsd:dateTime";
public const string xsd__decimal  = "xsd:decimal";

// http://www.daml.org/services/owl-s/1.0/Process.owl
public const string process__Input         = "process:Input";
public const string process__Output        = "process:Output";
public const string process__parameterType = "process:parameterType";

public const string dc__creator       = "dc:creator";
public const string dc__dateSubmitted = "dc:dateSubmitted";
public const string dc__modified      = "dc:modified";
public const string dc__created       = "dc:created";
public const string dc__identifier    = "dc:identifier";
public const string dc__subject       = "dc:subject";
public const string dc__title         = "dc:title";
//public const string dc__type = "dc:type";
public const string dc__description = "dc:description";
public const string dc__hasPart     = "dc:hasPart";

// swrc
public const string swrc__Employee   = "swrc:Employee";
public const string swrc__Person     = "swrc:Person";
public const string swrc__Department = "swrc:Department";
public const string swrc__lastName   = "swrc:lastName";
public const string swrc__firstName  = "swrc:firstName";
public const string swrc__name       = "swrc:name";
public const string swrc__email      = "swrc:email";
public const string swrc__phone      = "swrc:phone";

public const string gost19__middleName     = "gost19:middleName";
public const string gost19__internal_phone = "gost19:internal_phone";

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
public const string auth__ticket        = "auth:ticket";
public const string auth__credential    = "auth:credential";
public const string auth__login         = "auth:login";

public const string pacahon__on_trace_msg  = "pacahon:on-trace-msg";
public const string pacahon__off_trace_msg = "pacahon:off-trace-msg";

public const string query__all_predicates = "query:all_predicates";
public const string query__get_reifed     = "query:get_reifed";
public const string query__get            = "query:get";

public const string event__Event        = "event:Event";        // субьект типа Событие
public const string event__autoremove   = "event:autoremove";   // если == "yes", фильтр должен будет удален после исполнения
public const string event__subject_type = "event:subject_type"; // тип отслеживаемого субьекта
public const string event__when         = "event:when";         // after/before
public const string event__condition    = "event:condition";    // условие связанное с содержимым отслеживаемого субьекта
public const string event__to           = "event:to";           // кому отсылать сообщение - алиас для адреса сервиса - получателя сообщений
public const string event__msg_template = "event:msg_template"; // шаблон для сборки отправляемого сообщения

// TODO: TEMP
public const string ba2pacahon__Record  = "ba2pacahon:Record";  // запись о маппинге между словарями [ba] и [pacahon]
public const string ba2pacahon__ba      = "ba2pacahon:ba";      // термин из словаря [ba]
public const string ba2pacahon__pacahon = "ba2pacahon:pacahon"; // термин из словаря [pacahon]

public const string docs__Group             = "docs:Group";
public const string docs__Document          = "docs:Document";
public const string docs__document          = "docs:document";
public const string docs__label             = "docs:label";
public const string docs__source            = "docs:source";
public const string docs__FileDescription   = "docs:FileDescription"; // класс карточка файла
public const string docs__file              = "docs:file";            // тег - ссылка на файл ( используется в карточке файла)
public const string docs__attachment        = "docs:attachment";      // тег для использования в экземплярах документа
public const string docs__tumbnail          = "docs:tumbnail";
public const string docs__unit              = "docs:unit";
public const string docs__parentUnit        = "docs:parentUnit";
public const string docs__employee          = "docs:employee";
public const string docs__employee_card     = "docs:employee_card";             // карточка пользователя
public const string docs__organization_card = "docs:organization_card";         // карточка организации
public const string docs__unit_card         = "docs:unit_card";                 // карточка единицы орг структуры
public const string docs__department_card   = "docs:department_card";           // карточка подразделения
public const string docs__group_card        = "docs:group_card";                // карточка группы
public const string docs__carbon_copy       = "docs:carbon_copy";
public const string docs__dateInterval      = "docs:dateInterval";
public const string docs__contractor        = "docs:contractor";
public const string docs__link              = "docs:link";
public const string docs__content           = "docs:content";
public const string docs__from              = "docs:from";
public const string docs__to                = "docs:to";
public const string docs__position          = "docs:position";
public const string docs__active            = "docs:active";
public const string docs__actual            = "docs:actual";
public const string docs__kindOf            = "docs:kindOf";
public const string docs__defaultValue      = "docs:defaultValue";
public const string docs__modifier          = "docs:modifier";
//public const string docs__middleName = "docs:middleName";
public const string docs__version = "docs:version";
//public const string docs__templateName = "docs:templateName";
public const string docs__full_text_search = "docs:full-text-search"; // если docs:full-text-search = 0, то полнотекстовая индексация не выполняется

public const string link__importPredicates = "link:importPredicates";
public const string link__importClass      = "link:importClass";
public const string link__exportPredicates = "link:exportPredicates";

// класс документа (шаблон)
public const string class__identifier = "class:identifier";
public const string class__version    = "class:version";

public const string ba__systemInformation = "ba:systemInformation";
public const string ba__description       = "ba:description";
public const string ba__organizationTag   = "ba:organizationTag";
public const string ba__readOnly          = "ba:readOnly";
public const string ba__code              = "ba:code";
public const string ba__doctype           = "ba:doctype";

