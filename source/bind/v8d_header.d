/**
 * обвязка к v8d
 */
module bind.v8d_header;

import std.stdio, std.conv;
import type;
import onto.individual, onto.resource, onto.lang;
import pacahon.context;
import util.cbor8individual;

// //////////////////////////  call D from C //////////////////////////////////////////

string[ string ] g_prop;
Context g_context;

_Buff   g_document;
_Buff   g_user;

_Buff   tmp_individual;

_Buff   g_script_result;
_Buff   g_script_out;

extern (C++)
{
struct _Buff
{
    char *data;
    int  length;
    int  allocated_size;
}
}

extern (C++) char *get_global_prop(const char *prop_name, int prop_name_length)
{
    string pn  = cast(string)prop_name[ 0..prop_name_length ];
    string res = g_prop[ pn ];

    return cast(char *)res;
}

extern (C++) ResultCode put_individual(const char *_ticket, int _ticket_length, const char *_cbor, int _cbor_length, const char *_event_id,
                                       int _event_id_length)
{
    try
    {
        //writeln ("@p:v8d put_individual");

        if (g_context !is null)
        {
            string cbor      = cast(string)_cbor[ 0.._cbor_length ].dup;
            string ticket_id = cast(string)_ticket[ 0.._ticket_length ].dup;
            string event_id  = cast(string)_event_id[ 0.._event_id_length ].dup;

            Ticket *ticket = g_context.get_ticket(ticket_id);

            return g_context.store_individual(CMD.PUT, ticket, null, cbor, false, true, event_id);
        }
        return ResultCode.Service_Unavailable;
    }
    finally
    {
        //writeln ("@p:v8d end put_individual");
    }
}
extern (C++) ResultCode add_to_individual(const char *_ticket, int _ticket_length, const char *_cbor, int _cbor_length, const char *_event_id,
                                       int _event_id_length)
{
    try
    {
        //writeln ("@p:v8d put_individual");

        if (g_context !is null)
        {
            string cbor      = cast(string)_cbor[ 0.._cbor_length ].dup;
            string ticket_id = cast(string)_ticket[ 0.._ticket_length ].dup;
            string event_id  = cast(string)_event_id[ 0.._event_id_length ].dup;

            Ticket *ticket = g_context.get_ticket(ticket_id);

            return g_context.store_individual(CMD.ADD, ticket, null, cbor, false, true, event_id);
        }
        return ResultCode.Service_Unavailable;
    }
    finally
    {
        //writeln ("@p:v8d end put_individual");
    }
}

extern (C++) ResultCode set_in_individual(const char *_ticket, int _ticket_length, const char *_cbor, int _cbor_length, const char *_event_id,
                                       int _event_id_length)
{
    try
    {
        //writeln ("@p:v8d put_individual");

        if (g_context !is null)
        {
            string cbor      = cast(string)_cbor[ 0.._cbor_length ].dup;
            string ticket_id = cast(string)_ticket[ 0.._ticket_length ].dup;
            string event_id  = cast(string)_event_id[ 0.._event_id_length ].dup;

            Ticket *ticket = g_context.get_ticket(ticket_id);

            return g_context.store_individual(CMD.SET, ticket, null, cbor, false, true, event_id);
        }
        return ResultCode.Service_Unavailable;
    }
    finally
    {
        //writeln ("@p:v8d end put_individual");
    }
}

extern (C++) ResultCode remove_from_individual(const char *_ticket, int _ticket_length, const char *_cbor, int _cbor_length, const char *_event_id,
                                       int _event_id_length)
{
    try
    {
        //writeln ("@p:v8d put_individual");

        if (g_context !is null)
        {
            string cbor      = cast(string)_cbor[ 0.._cbor_length ].dup;
            string ticket_id = cast(string)_ticket[ 0.._ticket_length ].dup;
            string event_id  = cast(string)_event_id[ 0.._event_id_length ].dup;

            Ticket *ticket = g_context.get_ticket(ticket_id);

            return g_context.store_individual(CMD.REMOVE, ticket, null, cbor, false, true, event_id);
        }
        return ResultCode.Service_Unavailable;
    }
    finally
    {
        //writeln ("@p:v8d end put_individual");
    }
}

extern (C++)_Buff * get_env_str_var(const char *_var_name, int _var_name_length)
{
    try
    {
        string var_name    = cast(string)_var_name[ 0.._var_name_length ];
    	
    	if (var_name == "$user")
    	{
            return &g_user;    		
    	}
    	else
    		return null;
    }
    finally
    {
        //writeln ("@p:v8d end read_individual");
    }
}

extern (C++)_Buff * read_individual(const char *_ticket, int _ticket_length, const char *_uri, int _uri_length)
{
    try
    {
        string uri    = cast(string)_uri[ 0.._uri_length ];
        string ticket = cast(string)_ticket[ 0.._ticket_length ];

        //writeln ("@p:v8d read_individual, uri=[", uri, "],  ticket=[", ticket, "]");

        if (uri == "$document")
        {
            return &g_document;        	
        }
        else
        {    
            if (g_context !is null)
            {
                string icb = g_context.get_individual_from_storage(uri);
                if (icb !is null)
                {
                    tmp_individual.data   = cast(char *)icb;
                    tmp_individual.length = cast(int)icb.length;
                    return &tmp_individual;
                }
                else
                    return null;
            }
            return null;
        }
    }
    finally
    {
        //writeln ("@p:v8d end read_individual");
    }
}

void dump(char *data, int count)
{
    string res;

    for (int i = 0; i < count; i++)
        res ~= "[" ~ text(cast(uint)data[ i ]) ~ "]";

    writeln("@d dump cbor=", res);
}

// //////////////////////////  call C from D //////////////////////////////////////////

extern (C++)
{
interface WrappedContext
{
}

interface WrappedScript
{
}

bool InitializeICU();
WrappedContext new_WrappedContext();
WrappedScript new_WrappedScript(WrappedContext _context, char *src);
void run_WrappedScript(WrappedContext _context, WrappedScript ws, _Buff *_res = null, _Buff *_out = null);
}

alias new_WrappedContext new_ScriptVM;
alias WrappedContext     ScriptVM;
alias WrappedScript      Script;
alias run_WrappedScript  run;
alias new_WrappedScript  compile;


