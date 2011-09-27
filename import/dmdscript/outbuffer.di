// D import file generated from 'dmdscript/outbuffer.d'
module dmdscript.outbuffer;
private 
{
    import core.memory;
    import std.string;
    import std.c.stdio;
    import std.c.stdlib;
    import std.c.stdarg;
}
class OutBuffer
{
    void[] data;
    uint offset;
        this()
{
}
    void[] toBytes()
{
return data[0..offset];
}
    void reserve(size_t nbytes);
    void write(const(ubyte)[] bytes)
{
reserve(bytes.length);
(cast(ubyte[])data)[offset..offset + bytes.length] = bytes[0..$];
offset += bytes.length;
}
    void write(in wchar[] chars)
{
write(cast(ubyte[])chars);
}
    void write(const(dchar)[] chars)
{
write(cast(ubyte[])chars);
}
    void write(ubyte b)
{
reserve((ubyte).sizeof);
*cast(ubyte*)&data[offset] = b;
offset += (ubyte).sizeof;
}
    void write(byte b)
{
write(cast(ubyte)b);
}
    void write(char c)
{
write(cast(ubyte)c);
}
    void write(dchar c)
{
write(cast(uint)c);
}
    void write(ushort w)
{
reserve((ushort).sizeof);
*cast(ushort*)&data[offset] = w;
offset += (ushort).sizeof;
}
    void write(short s)
{
write(cast(ushort)s);
}
    void write(wchar c)
{
reserve((wchar).sizeof);
*cast(wchar*)&data[offset] = c;
offset += (wchar).sizeof;
}
    void write(uint w)
{
reserve((uint).sizeof);
*cast(uint*)&data[offset] = w;
offset += (uint).sizeof;
}
    void write(int i)
{
write(cast(uint)i);
}
    void write(ulong l)
{
reserve((ulong).sizeof);
*cast(ulong*)&data[offset] = l;
offset += (ulong).sizeof;
}
    void write(long l)
{
write(cast(ulong)l);
}
    void write(float f)
{
reserve((float).sizeof);
*cast(float*)&data[offset] = f;
offset += (float).sizeof;
}
    void write(double f)
{
reserve((double).sizeof);
*cast(double*)&data[offset] = f;
offset += (double).sizeof;
}
    void write(real f)
{
reserve((real).sizeof);
*cast(real*)&data[offset] = f;
offset += (real).sizeof;
}
    void write(in char[] s)
{
write(cast(ubyte[])s);
}
    void write(OutBuffer buf)
{
write(cast(ubyte[])buf.toBytes());
}
    void fill0(uint nbytes)
{
reserve(nbytes);
*cast(ubyte*)&data[offset..offset + nbytes] = 0;
offset += nbytes;
}
    void alignSize(uint alignsize)
in
{
assert(alignsize && (alignsize & alignsize - 1) == 0);
}
out
{
assert((offset & alignsize - 1) == 0);
}
body
{
uint nbytes;
nbytes = offset & alignsize - 1;
if (nbytes)
fill0(alignsize - nbytes);
}
    void align2()
{
if (offset & 1)
write(cast(byte)0);
}
    void align4();
    override string toString()
{
return cast(string)data[0..offset].idup;
}

    void vprintf(string format, va_list args);
    void printf(string format,...);
    void spread(size_t index, size_t nbytes);
}
