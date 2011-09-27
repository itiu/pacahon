// D import file generated from 'dmdscript/darguments.d'
module dmdscript.darguments;
import dmdscript.script;
import dmdscript.dobject;
import dmdscript.identifier;
import dmdscript.value;
import dmdscript.text;
import dmdscript.property;
class Darguments : Dobject
{
    Dobject actobj;
    Identifier*[] parameters;
    const int isDarguments()
{
return true;
}
    this(Dobject caller, Dobject callee, Dobject actobj, Identifier*[] parameters, Value[] arglist);
    Value* Get(d_string PropertyName)
{
d_uint32 index;
return StringToIndex(PropertyName,index) && index < parameters.length ? actobj.Get(index) : Dobject.Get(PropertyName);
}
    Value* Get(d_uint32 index)
{
return index < parameters.length ? actobj.Get(index) : Dobject.Get(index);
}
    Value* Get(d_uint32 index, Value* vindex)
{
return index < parameters.length ? actobj.Get(index,vindex) : Dobject.Get(index,vindex);
}
    Value* Put(string PropertyName, Value* value, uint attributes)
{
d_uint32 index;
if (StringToIndex(PropertyName,index) && index < parameters.length)
return actobj.Put(PropertyName,value,attributes);
else
return Dobject.Put(PropertyName,value,attributes);
}
    Value* Put(Identifier* key, Value* value, uint attributes)
{
d_uint32 index;
if (StringToIndex(key.value.string,index) && index < parameters.length)
return actobj.Put(key,value,attributes);
else
return Dobject.Put(key,value,attributes);
}
    Value* Put(string PropertyName, Dobject o, uint attributes)
{
d_uint32 index;
if (StringToIndex(PropertyName,index) && index < parameters.length)
return actobj.Put(PropertyName,o,attributes);
else
return Dobject.Put(PropertyName,o,attributes);
}
    Value* Put(string PropertyName, d_number n, uint attributes)
{
d_uint32 index;
if (StringToIndex(PropertyName,index) && index < parameters.length)
return actobj.Put(PropertyName,n,attributes);
else
return Dobject.Put(PropertyName,n,attributes);
}
    Value* Put(d_uint32 index, Value* vindex, Value* value, uint attributes)
{
if (index < parameters.length)
return actobj.Put(index,vindex,value,attributes);
else
return Dobject.Put(index,vindex,value,attributes);
}
    Value* Put(d_uint32 index, Value* value, uint attributes)
{
if (index < parameters.length)
return actobj.Put(index,value,attributes);
else
return Dobject.Put(index,value,attributes);
}
    int CanPut(d_string PropertyName)
{
d_uint32 index;
return StringToIndex(PropertyName,index) && index < parameters.length ? actobj.CanPut(PropertyName) : Dobject.CanPut(PropertyName);
}
    int HasProperty(d_string PropertyName)
{
d_uint32 index;
return StringToIndex(PropertyName,index) && index < parameters.length ? actobj.HasProperty(PropertyName) : Dobject.HasProperty(PropertyName);
}
    int Delete(d_string PropertyName)
{
d_uint32 index;
return StringToIndex(PropertyName,index) && index < parameters.length ? actobj.Delete(PropertyName) : Dobject.Delete(PropertyName);
}
}
