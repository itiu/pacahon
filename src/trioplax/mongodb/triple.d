module trioplax.mongodb.triple;

private import std.array;
private import std.stdio;
private import std.array: appender;
private import std.format;

private import util.Logger;

Logger log;

static this()
{
	log = new Logger("trioplax", "log", "");
}

public static const byte _NONE = 0;
public static const byte _RU = 1;
public static const byte _EN = 2;

class Triple
{
	string S;
	string P;
	string O;
//	int hhh;

	byte lang;
	
	this(string _S, string _P, string _O)
	{
		S = cast(string)new char[_S.length];
		P = cast(string)new char[_P.length];
		
		(cast(char[])S)[] = _S[];
		(cast(char[])P)[] = _P[];
		
		if (_O.length > 2 && _O[$-3] == '@')
		{
			O = cast(string)new char[_O.length - 3];
			(cast(char[])O)[] = _O[0..$-3];
			
			if (_O[$-2] == 'r')
				lang = _RU;
			else if (_O[$-2] == 'e')
				lang = _EN;			
		}
		else
		{
			O = cast(string)new char[_O.length];
			(cast(char[])O)[] = _O[];
		}
	}

	this(string _S, string _P, string _O, byte _lang)
	{
		S = cast(string)new char[_S.length];
		P = cast(string)new char[_P.length];
		O = cast(string)new char[_O.length];
		
		(cast(char[])S)[] = _S[];
		(cast(char[])P)[] = _P[];
		(cast(char[])O)[] = _O[];
		
//		S = _S;
//		P = _P;
//		O = _O;
		lang = _lang;
		
//		log.trace ("create triple %s", this);
	}

	~this ()
	{
//		log.trace ("destroy triple %s", this);
	}
	
	override string toString()
	{
		string sS = S;
		string sP = P;
		string sO = O;
		
		if (sS is null)
			sS = "";
		
		if (sP is null)
			sP = "";
		
		if (sO is null)
			sO = "";
		
		auto writer = appender!string();

//		formattedWrite(writer, "%X %d %d<%s>%d<%s>%d<%s>", cast(void*)this, hhh, sS.length, sS, sP.length, sP, sO.length, sO);
		formattedWrite(writer, "<%s><%s><%s>", sS, sP, sO);
		
		return writer.data;		
//		return "<" ~ sS ~ ">"~sS.length~"<" ~ sP ~ "><" ~ sO ~ ">";
	}

}
