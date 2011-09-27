// D import file generated from 'dmdscript/iterator.d'
module dmdscript.iterator;
import dmdscript.script;
import dmdscript.dobject;
import dmdscript.value;
import dmdscript.property;
Dobject getPrototype(Dobject o);
struct Iterator
{
    Value[] keys;
    size_t keyindex;
    Dobject o;
    Dobject ostart;
    debug (1)
{
    const uint ITERATOR_VALUE = 26814518;

    uint foo = ITERATOR_VALUE;
}
        void ctor(Dobject o);
    Value* next();
}
