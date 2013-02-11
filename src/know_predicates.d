module pacahon.know_predicates;

public const string rdf__type = "rdf:type"; // TODO a == rdf:type 
public const string rdf__subject = "rdf:subject";
public const string rdf__predicate = "rdf:predicate";
public const string rdf__object = "rdf:object";
public const string rdf__Statement = "rdf:Statement";
public const string rdf__datatype = "rdf:datatype";

public const string rdfs__label = "rdfs:label";

public const string xsd__string = "xsd:string";

// http://www.daml.org/services/owl-s/1.0/Process.owl
public const string process__Input = "process:Input";
public const string process__Output = "process:Output";
public const string process__parameterType = "process:parameterType";

public const string dc__creator = "dc:creator";

public const string msg__Message = "msg:Message";
public const string msg__args = "msg:args";
public const string msg__reciever = "msg:reciever";
public const string msg__ticket = "msg:ticket";					 // TODO оставить один, или msg:ticket или auth:ticket
public const string msg__sender = "msg:sender";
public const string msg__command = "msg:command";
public const string msg__status = "msg:status";
public const string msg__reason = "msg:reason";
public const string msg__result = "msg:result";
public const string msg__in_reply_to = "msg:in-reply-to";

public const string ticket__Ticket = "ticket:Ticket";
public const string ticket__accessor = "ticket:accessor";
public const string ticket__when = "ticket:when";
public const string ticket__duration = "ticket:duration";

public const string auth__ticket = "auth:ticket";
public const string auth__credential = "auth:credential";
public const string auth__login = "auth:login";

public const string pacahon__on_trace_msg = "pacahon:on-trace-msg";
public const string pacahon__off_trace_msg = "pacahon:off-trace-msg";

public const string event__Event = "event:Event"; 					// субьект типа Событие
public const string event__autoremove = "event:autoremove"; 		// если == "yes", фильтр должен будет удален после исполнения
public const string event__subject_type = "event:subject_type"; 	// тип отслеживаемого субьекта 
public const string event__when = "event:when"; 					// after/before
public const string event__condition = "event:condition"; 			// условие связанное с содержимым отслеживаемого субьекта
public const string event__to = "event:to"; 						// кому отсылать сообщение - алиас для адреса сервиса - получателя сообщений
public const string event__msg_template = "event:msg_template"; 	// шаблон для сборки отправляемого сообщения

// TODO: TEMP
public const string ba2pacahon__Record = "ba2pacahon:Record";		// запись о маппинге между словарями [ba] и [pacahon]
public const string ba2pacahon__ba = "ba2pacahon:ba";				// термин из словаря [ba]
public const string ba2pacahon__pacahon = "ba2pacahon:pacahon";	// термин из словаря [pacahon]


