module bind.v8d_header;

import std.stdio, std.conv;
//import onto.individual;
//import onto.resource;

////////////////////////////  call D from C //////////////////////////////////////////

string[string] g_prop;

//Individual cur_individual;

extern (C++) char* get_global_prop (const char* prop_name, int prop_name_length) 
{
    string pn = cast(string)prop_name[0..prop_name_length];
    string res = g_prop[pn]; 
    return cast(char*)res;
}

extern (C++) void read_individual (const char* _uri, int _uri_length) 
{
    string uri = cast(string)_uri[0.._uri_length];

    if (uri != "$document")
    {
	
    }
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
     WrappedScript new_WrappedScript (WrappedContext _context, char* src);
     void run_WrappedScript (WrappedContext _context, WrappedScript ws);
}

alias new_WrappedContext new_ScriptVM;
alias WrappedContext ScriptVM;
alias WrappedScript Script;
alias run_WrappedScript run;
alias new_WrappedScript compile;


