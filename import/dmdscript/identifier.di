// D import file generated from 'dmdscript/identifier.d'
module dmdscript.identifier;
import dmdscript.script;
import dmdscript.value;
struct Identifier
{
    Value value;
    d_string toString()
{
return value.string;
}
    const bool opEquals(ref const(Identifier) id)
{
return this is id || value.string == id.value.string;
}

    static Identifier* build(d_string s)
{
Identifier* id = new Identifier;
id.value.putVstring(s);
id.value.toHash();
return id;
}

    uint toHash()
{
return value.hash;
}
}
