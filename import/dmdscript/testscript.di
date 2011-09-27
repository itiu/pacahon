// D import file generated from 'testscript.d'
module testscript;
import std.path;
import std.file;
import std.stdio;
import std.exception;
import std.c.stdlib;
import core.memory;
import dmdscript.script;
import dmdscript.program;
import dmdscript.errmsgs;
enum 
{
EXITCODE_INIT_ERROR = 1,
EXITCODE_INVALID_ARGS = 2,
EXITCODE_RUNTIME_ERROR = 3,
}
int main(string[] args);
class SrcFile
{
    string srcfile;
    string[] includes;
    Program program;
    tchar[] buffer;
    this(string srcfilename, string[] includes)
{
srcfile = std.path.defaultExt(srcfilename,"ds");
this.includes = includes;
}
    void read();
    void compile()
{
program = new Program;
program.compile(srcfile,assumeUnique(buffer),null);
}
    void execute()
{
program.execute(null);
}
}
