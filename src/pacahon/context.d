/**
  * Внешнее API
  */
module pacahon.context;

private import std.concurrency, std.datetime, std.json;

private import type; 
private import util.container;
private import search.vel;
private import onto.owl;
private import onto.individual;
private import pacahon.define;

private import bind.v8d_header;

enum CMD : byte
{
    STORE        = 1,
    PUT          = 1,
    FIND         = 2,
    GET          = 2,
    EXAMINE      = 4,
    AUTHORIZE    = 8,
    COMMIT       = 16,
    END_DATA     = 32,
    SET_TRACE    = 33,
    RELOAD       = 40,
    BACKUP       = 41,
    FREEZE       = 42,
    UNFREEZE     = 43,
    PUT_KEY2SLOT = 44,
    SET			 = 45,		
    NOP          = 64
}

/// имена процессов
public enum P_MODULE : byte
{
	/// выдача и проверка тикетов 
    ticket_manager             = 0,
    
    /// чтение и сохранение индивидуалов 
    subject_manager            = 1,
    
    /// индексирование прав, проверка прав
    acl_manager                = 2,
    
    /// полнотекстовое индексирование 
    xapian_thread_context      = 3,
    
    /// полнотекстовое индексирование 
    fulltext_indexer           = 4,
    
    /// сбор статистики
    statistic_data_accumulator = 5,
    
    /// запуск внешних скриптов
    condition                  = 6,
    
    /// сохранение накопленных данных в полнотекстовом индексаторе
    commiter                   = 7,
    
    /// вывод статистики
    print_statistic            = 8,
    
    /// межпроцессные сигналы
    interthread_signals        = 9,
    
    /// загрузка из файлов
    file_reader                = 10,
    
    zmq_listener               = 11,
    nop                        = 99
}

/**
  * Коды результата выполнения
  */
public enum ResultCode
{
	/// 0
    zero                  = 0,
    
    /// 200 
    OK                    = 200,

    /// 201 
    Created               = 201,

    /// 204 
    No_Content            = 204,
    
    /// 400
    Bad_Request           = 400,
    
    /// 403
    Forbidden             = 403,
    
    /// 404
    Not_Found             = 404,
    
    /// 422 
    Unprocessable_Entity  = 422,
    
    /// 471
    Ticket_expired        = 471,
    
    /// 472
    Not_Authorized        = 472,
    
    /// 473
    Authentication_Failed = 473,
    
    /// 474
    Not_Ready             = 474,
    
    /// 475
    Fail_Open_Transaction = 475,
    
    /// 476
    Fail_Commit           = 476,
    
    /// 477
    Fail_Store            = 477,
    
    /// 500
    Internal_Server_Error = 500,
    
    /// 501
    Not_Implemented       = 501,
    
    /// 503
    Service_Unavailable   = 503,
    
    /// 1021
    Disk_Full             = 1021,
    
    /// 1022
    Duplicate_Key         = 1022
}

/**
  * Обьект - сессионный тикет
  */
public struct Ticket
{
	/// ID
    string     id;
    
    /// uri пользователя
    string     user_uri;
    
    /// код результата, если тикет не валидный != $(D ResultCode.Ok)  
    ResultCode result;
//    string[] parentUnitIds = new string[ 0 ];

	/// время жизни тикета в миллисекундах
    long       end_time;

    /// конструктор
    immutable this(string _id, string _user_uri, long _end_time)
    {
        id       = _id;
        user_uri = _user_uri;
        end_time = _end_time;
    }

    /// создание $(D immutable) копии
    immutable(Ticket) idup()
    {
        immutable(Ticket) result = immutable Ticket(id, user_uri, end_time);
        return result;
    }
}

/**
  * Внешнее API - Интерфейс
  */
interface Context
{
    string get_name();

    ScriptVM get_ScriptVM();

    Property *get_property(string ur);

    JSONValue get_props();

    Tid getTid(P_MODULE tid_name);

    @property search.vql.VQL vql();

    ref string[ string ] get_prefix_map();

    int[ string ] get_key2slot();
    long get_last_update_time();

//    void store_subject(Subject ss, bool prepareEvents = true);
    public bool check_for_reload(string interthread_signal_id, void delegate() load);

//    /////////////////////////////////////////// <- oykumena -> ///////////////////////////////////////////////
     
    void push_signal(string key, long value);
    void push_signal(string key, string value);
    long look_integer_signal(string key);
    string look_string_signal(string key);
    void set_reload_signal_to_local_thread(string interthread_signal_id);
    bool authorize(string uri, Ticket *ticket, ubyte request_acess);
    Individual[] get_individuals_via_query(Ticket *ticket, string query_str);
    public string get_individual_from_storage(string uri);
    
    // *************************************************** external api *********************************** //
    public string[ 2 ] execute_script(string str);

//    //////////////////////////////////////////////////// ONTO //////////////////////////////////////////////

    public immutable(Class)[ string ] iget_owl_classes();
    public immutable(Individual)[ string ] get_onto_as_map_individuals();
    public immutable(Class) * iget_class(string ur);

// //////////////////////////////////////////////////// TICKET //////////////////////////////////////////////    
    /**
     аутентификация
     Params: 
    		login = имя пользователя
    		password = хэш пароля
    
     Returns: 
    		экземпляр структуры Ticket
	*/
    public Ticket authenticate(string login, string password);
    
    /**
      Получить обьект Ticket по Id
     */
    public Ticket *get_ticket(string ticket_id);

    /**
      проверить сессионный билет
     */
    public bool is_ticket_valid(string ticket_id);

    // ////////////////////////////////////////////// INDIVIDUALS IO ////////////////////////////////////////////
    /**
     получить индивидуалов согласно заданному запросу      
     Params: 
     		ticket = указатель на экземпляр Ticket
     		query_str = строка содержащая VQL запрос
      
     Returns: 
    		список авторизованных uri 
	*/
    public immutable(string)[]     get_individuals_ids_via_query(Ticket *ticket, string query_str);

    /**
     получить индивидуала по его uri      
     Params: 
     		 ticket = указатель на обьект Ticket
    		 Uri
    
     Returns: 
    		авторизованный экземпляр Individual 
	*/
    public Individual               get_individual(Ticket *ticket, Uri uri);

    /**
     получить список индивидуалов по списку uri      
     Params: 
     		ticket = указатель на обьект Ticket
    		uris   = список содержащий заданные uri
    
     Returns: 
    		авторизованные экземпляры Individual 
	*/
    public Individual[]             get_individuals(Ticket *ticket, string[] uris);

    /**
     получить индивидуала(CBOR) по его uri      
     Params: 
     		 ticket = указатель на обьект Ticket
    		 uri
    
     Returns: 
    		авторизованный индивид в виде строки CBOR
	*/
    public string               	 get_individual_as_cbor(Ticket *ticket, string uri);

    /**
    * получить список индивидуалов(CBOR) по списку uri      
     Params: 
     		ticket = указатель на обьект Ticket
    		uris   = список содержащий заданные uri
    
     Returns: 
    		авторизованные индивиды в виде массива CBOR строк 
	*/
    public immutable(string)[]     get_individuals_as_cbor(Ticket *ticket, string[] uris);

    /**
    * сохранить индивидуал      
     Params: 
     		 ticket = указатель на обьект Ticket
    		 indv   = указатель на экземпляр Individual, сохраняется если !is null
    		 ss_as_cbor = индивидуал в виде строки, сохраняется если $(D indv is null)
    
     Returns: 
    		Код результата операции
	*/
    public ResultCode store_individual(Ticket *ticket, Individual *indv, string ss_as_cbor, bool prepareEvents = true);

    /**
     сохранить индивидуал, по указанному uri      
     Params: 
     		 ticket = указатель на обьект Ticket
    		 indv   = указатель на экземпляр Individual, сохраняется если !is null
    		 uri    = uri, по которому сохраняется индивидула
    
     Returns: 
    		Код результата операции
	*/
    public ResultCode put_individual(Ticket *ticket, string uri, Individual individual);
    public ResultCode post_individual(Ticket *ticket, Individual individual);

    // ////////////////////////////////////////////// AUTHORIZATION ////////////////////////////////////////////
    /**
     получить список доступных прав для пользователя на указанномый uri      
     Params: 
     		 ticket = указатель на обьект Ticket
    		 uri   = uri субьекта
    
     Returns: 
    		байт содержащий установленные биты (type.Access)    
	*/

    public ubyte get_rights (Ticket *ticket, string uri);
    public void get_rights_origin (Ticket *ticket, string uri, void delegate(string resource_group, string subject_group, string right) trace);

    // ////////////////////////////////////////////// TOOLS ////////////////////////////////////////////

    public void wait_thread(P_MODULE thread_id);
    public void set_trace(int idx, bool state);

    public long count_individuals();

    public bool backup(int level = 0);
    public void freeze();
    public void unfreeze();
}