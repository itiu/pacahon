module bind.v8d_header;

import std.stdio, std.conv;
import onto.individual;
import onto.resource;
import onto.lang;
import pacahon.context;

////////////////////////////  call D from C //////////////////////////////////////////

string[ string ] g_prop;
Context g_context;

_Buff   g_individual;
_Buff   tmp_individual;

_Buff   g_script_result;
_Buff   g_script_out;

//Individual[int] individual_2_idx;
//int[string] idx_2_uri;
//int counter;

//void clear_script_data_cache ()
//{
//	individual_2_idx = (Individual[int]).init;
//	idx_2_uri = (int[string]).init;
//	counter = 0;
//}

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

extern (C++) ResultCode put_individual(const char *_ticket, int _ticket_length, const char *_cbor, int _cbor_length)
{
    if (g_context !is null)
    {
        string cbor   = cast(string)_cbor[ 0.._cbor_length ];
        string ticket = cast(string)_ticket[ 0.._ticket_length ];

//      writeln ("@Q ticket=", ticket);
//      writeln ("@Q cbor=", cbor);

        return g_context.store_individual(ticket, null, cbor.dup);
    }
    return ResultCode.Service_Unavailable;
}

extern (C++)_Buff * read_individual(const char *_ticket, int _ticket_length, const char *_uri, int _uri_length)
{
    string uri    = cast(string)_uri[ 0.._uri_length ];
    string ticket = cast(string)_ticket[ 0.._ticket_length ];

/*
    int idx = idx_2_uri.get (uri, -1);
    if (idx < 0)
    {
        idx = counter++;
        idx_2_uri[uri] = idx;
 */
    if (uri != "$document")
    {
//          individual_2_idx[idx] = Individual.init;
        if (g_context !is null)
        {
            string icb = g_context.get_subject_as_cbor(uri);
            tmp_individual.data   = cast(char *)icb;
            tmp_individual.length = cast(int)icb.length;
            return &tmp_individual;
        }
        return null;
    }
    else
    {
//          individual_2_idx[idx] = g_individual;
        return &g_individual;
    }
//    }
}

////////////////////////////  call C from D //////////////////////////////////////////

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


