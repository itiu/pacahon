module mmf.graph;

import std.mmfile;
import std.stdio;
import libchash_h;
import trioplax.Logger;
import core.memory;
import std.c.string;
import tango.text.convert.Integer;
import std.file;

const byte p_count_allocated_vertex = 1;

Logger log;

static this()
{
	log = new Logger("graph", "log", "server");
}

bool trace = false;
const size_t K = 1024;
int size_hash_file = 2 * K * K * K - 1024;

struct Iterator
{
	GraphIO* gio;
	uint offset = 0;
	byte last_alloc_mmfile = 0;
	uint count = 0;
}

struct MmFileInfo
{
	uint allocate_bytes = 0;
	uint allocate_vertex = 0;
	MmFile array;

	void init()
	{
		allocate_bytes = *cast(uint*) array[0 .. uint.sizeof];
		allocate_vertex = *cast(uint*) array[p_count_allocated_vertex * uint.sizeof .. p_count_allocated_vertex * uint.sizeof + uint.sizeof];

		writeln("init mmfile, length=", array.length, ", total_allocated_bytes=", allocate_bytes,
				", count_allocated_vertex=", allocate_vertex);
	}
}

struct GraphIO
{
	const size_t K = 1024;
	size_t win = 64 * K; // assume the page size is 64K

	short last_alloc_mmfile = -1;
	uint data_length;
	string file_name_prefix;

	private MmFileInfo chunk[256];
	HashTable* ht;

	private bool allocate_new_file()
	{
		if(last_alloc_mmfile + 1 < 256)
			last_alloc_mmfile++;
		else
			return false;

		// откроем новый файл
		MmFileInfo mmfi;
		mmfi.array = new MmFile(file_name_prefix ~ "." ~ cast(string) toString(last_alloc_mmfile),
				MmFile.Mode.readWriteNew, size_hash_file, null, win);
		chunk[last_alloc_mmfile] = mmfi;

		writeln("last_alloc_mmfile=", last_alloc_mmfile);

		return true;
	}

	public void open_mmfiles(string _file_name_prefix)
	{
		file_name_prefix = _file_name_prefix;

		version(Win32)
		{
			/+ these aren't defined in std.c.windows.windows so let's use default
			 SYSTEM_INFO sysinfo;
			 GetSystemInfo(&sysinfo);
			 win = sysinfo.dwAllocationGranularity;
			 +/
		} else version(linux)
		{
			// getpagesize() is not defined in the unix D headers so use the guess
		}

		ht = AllocateHashTable(0, 0);
		log.trace("open mmfiles...");

		// нужно найти и открыть файлы с именем [file_name_prefix.NN]
		uint total_count_vertex = 0;
		byte found_alloc_file = 0;

		foreach(string name; dirEntries(".", SpanMode.shallow))
		{
			string nfile = "./" ~ file_name_prefix ~ "." ~ cast(string) toString(found_alloc_file);

			if(trace)
				writeln("@1 nfile=", nfile);

			if(name == nfile)
			{
				log.trace("open mmfile: %s", name);

				if(trace)
					writeln("@2 name=", name);

				chunk[found_alloc_file].array = new MmFile(nfile, MmFile.Mode.read, 0, null, win);
				chunk[found_alloc_file].init();
				total_count_vertex += chunk[found_alloc_file].allocate_vertex;
				found_alloc_file++;
			}
		}

		log.trace("total_count_vertex: %d", total_count_vertex);

		if(trace)
			writeln("@3");

		if(found_alloc_file > 0)
		{
			uint count = 0;
			// загрузим в память ключи и смещения узлов графа
			try
			{
				if(trace)
					writeln("@4");
				found_alloc_file--;
				last_alloc_mmfile = found_alloc_file;

				if(trace)
					writeln("@6");

				char*[] keys;

				keys = new char*[total_count_vertex + 1];

				Iterator it1;

				while(next(it1))
				{
					if(count > 2_100_000)
						break;
											

					if(it1.count % 100_000 == 0)
					{
						log.trace("load %d", it1.count);
					}

					Vertex_vmm* vv = getNext(it1);
					string label = vv.getLabel;
					
//					log.trace ("count: %d label: [%s]", count, label);
					
					if(label.length > 256)
					{
						log.trace("count=%d, label.length(%d):%s", count, label.length, label);
						break;
					}

					keys[count] = cast(char*) GC.malloc(label.length + 1);

					*(keys[count] + label.length) = 0;

					strncpy(keys[count], cast(char*) label, label.length);

					HashInsert(ht, cast(uint) cast(char*) keys[count], vv.getOffset);
					
					count++;
				}
			} catch(Exception ex)
			{
				log.trace("ex! count=%d", count);
				throw ex;
			}

		} else
		{
			if(trace)
				writeln("@5 allocate_new_file");

			allocate_new_file();
		}
		log.trace("done");
	}

	private bool allocate(in uint _size, out MmFileInfo* ch, out uint offset)
	{
		// выравниваем до размера блока в 256 байт, для общей адресации = 2^24 вершин в одном файле * 256 файлов 
		if(trace)
			writeln("allocate:", _size, ", last_alloc_mmfile=", last_alloc_mmfile);
		ch = &chunk[last_alloc_mmfile];

		if(trace)
			printf("ch:%X", ch);

		if(ch is null)
		{
			writeln("allocate:", _size, ". filed, mmfile is null");
			return false;
		}

		if(ch.allocate_bytes + _size > ch.array.length - ch.allocate_vertex * uint.sizeof)
		{
			if(allocate_new_file() == false)
			{
				writeln("allocate:", _size, ". filed, data[", last_alloc_mmfile, "].length=", ch.array.length);
				return false;
			}
			ch = &chunk[last_alloc_mmfile];
		}

		uint new_block_ptr = (256 + ch.allocate_bytes) & 0xFFFFFF00;
		if(trace)
			printf("new_block_ptr=%X\n", new_block_ptr);

		// сохраним ch.allocated_bytes
		ch.allocate_bytes = new_block_ptr + _size;
		uint* buf = cast(uint*) ch.array[0 .. uint.sizeof];
		*buf = ch.allocate_bytes;

		// сохраним выделенный указатель в список, распределенных блоков, находящийся в xвосте файла 
		uint pos = cast(uint) (cast(uint) ch.array.length - ch.allocate_vertex * uint.sizeof - uint.sizeof);
		buf = cast(uint*) ch.array[pos .. pos + uint.sizeof];
		*buf = new_block_ptr;

		// сохраним count_allocated_vertex
		ch.allocate_vertex++;
		buf = cast(uint*) ch.array[p_count_allocated_vertex * uint.sizeof .. p_count_allocated_vertex * uint.sizeof + uint.sizeof];
		*buf = ch.allocate_vertex;

		if(trace)
			writeln("allocate:", _size, ". ok");

		offset = new_block_ptr;
		return true;
	}

	bool next(ref Iterator iterator)
	{
		if(iterator.count < chunk[iterator.last_alloc_mmfile].allocate_vertex)
		{
			return true;
		}

		if(iterator.last_alloc_mmfile + 1 <= last_alloc_mmfile)
		{
			return true;
		}

		return false;
	}

	Vertex_vmm* getNext(ref Iterator iterator)
	{
		if(iterator.count > chunk[iterator.last_alloc_mmfile].allocate_vertex)
		{
			iterator.last_alloc_mmfile++;
		}

		uint
				pos = cast(uint) (cast(uint) chunk[iterator.last_alloc_mmfile].array.length - iterator.count * uint.sizeof - uint.sizeof);
		uint ptr = *cast(uint*) chunk[iterator.last_alloc_mmfile].array[pos .. pos + uint.sizeof];

		if(trace)
			printf("ptr=%X\n", ptr);

		uint
				len = *cast(uint*) chunk[iterator.last_alloc_mmfile].array[ptr + uint.sizeof .. ptr + uint.sizeof + uint.sizeof];

		if(trace)
			printf("len=%X\n", len);

		Vertex_vmm* vv = null;
		bind_vertex(vv, iterator.last_alloc_mmfile, ptr);

		iterator.count++;
		return vv;
	}

	bool findVertex(string label, ref Vertex_vmm* vv)
	{
		HTItem* bck;

		bck = HashFind1(ht, cast(uint) cast(char*) label, cast(uint) label.length);

		if(bck !is null)
		{
			byte file_number = bck.data & 0x000000FF >> 24;
			uint pos_in_file = bck.data & 0xFFFFFF00;

			bind_vertex(vv, file_number, pos_in_file);
			return true;
		}
		return false;
	}

	bool bind_vertex(ref Vertex_vmm* vv, byte file_number, uint _offset)
	{
		if(vv is null)
			vv = new Vertex_vmm;

		MmFile _array = chunk[file_number].array;

		vv.size = *cast(uint*) _array[uint.sizeof .. uint.sizeof + uint.sizeof];
		vv.ch = &chunk[file_number];
		vv.gio = &this;

		vv.offset = _offset;

		uint ptr = _offset + cast(uint) uint.sizeof * 2;

		vv.offset_label = SIZE_HEADER_VERTEX;

		if(trace)
		{
			printf("ptr=%X\n", ptr);

			printf("vv.offset=%X\n", vv.offset);

			printf("vv.offset_label=%X\n", vv.offset_label);

			printf("vv.offset_label + vv.offset = %X\n", vv.offset_label + vv.offset);
		}

		vv.length_label = *cast(uint*) _array[ptr .. ptr + uint.sizeof];
		ptr += uint.sizeof;

		if(trace)
			printf("vv.length_label=%X\n", vv.length_label);

		vv.offset_properties = *cast(uint*) _array[ptr .. ptr + uint.sizeof];
		ptr += uint.sizeof;
		//		printf("vv.offset_properties=%X\n", vv.offset_properties);

		vv.length_properties = *cast(uint*) _array[ptr .. ptr + uint.sizeof];
		ptr += uint.sizeof;

		vv.offset_out_edges = *cast(uint*) _array[ptr .. ptr + uint.sizeof];
		ptr += uint.sizeof;

		vv.length_out_edges = *cast(uint*) _array[ptr .. ptr + uint.sizeof];
		ptr += uint.sizeof;

		return true;
	}

}

int SIZE_HEADER_VERTEX = 7 * uint.sizeof;

struct Vertex_vmm
{
	private
	{
		// header in mmfile		
		uint size;

		uint length_label = 0;

		uint offset_properties;
		uint length_properties = 0;

		uint offset_out_edges;
		uint length_out_edges = 0;

		// local
		uint offset_label;
		uint offset;

		// data
		string label;
	}

	MmFileInfo* ch;
	GraphIO* gio;

	string[][string] properties;
	string[][string] out_edges;

	public uint getOffset()
	{
		return offset;
	}

	string getLabel()
	{
		if(label !is null)
			return label;

		label = cast(string) ch.array[offset + offset_label .. offset + offset_label + length_label];

		return label;
	}

	void setLabel(ref string str)
	{
		label = str;
	}

	bool store()
	{
		// вычислить размер сохраняемой структуры
		uint len = SIZE_HEADER_VERTEX;

		len += label.length + uint.sizeof;

		len += uint.sizeof;
		foreach(key; properties.keys)
		{
			len += key.length + uint.sizeof;

			len += uint.sizeof;
			string[] values = properties.get(key, []);
			foreach(value; values)
			{
				len += value.length + uint.sizeof;
			}
		}

		len += uint.sizeof;
		foreach(key; out_edges.keys)
		{
			len += key.length + uint.sizeof;

			len += uint.sizeof;
			string[] values = out_edges.get(key, []);
			foreach(value; values)
			{
				len += value.length + uint.sizeof;
			}
		}

		if(trace)
			printf("LEN=%X\n", len);

		bool isAllocate = gio.allocate(len, ch, offset);

		if(isAllocate == true)
		{
			uint* buf;

			if(trace)
				printf("OFFSET:=%X\n", offset);

			uint ptr = offset;
			uint header_ptr = offset;

			// сохранить marker начала
			//			printf("store marker:%X\n", header_ptr);
			buf = cast(uint*) ch.array[header_ptr .. header_ptr + uint.sizeof];
			*buf = 0xF0F1F2F3;
			header_ptr += uint.sizeof;

			// сохранить размер Vertex
			//			printf("store size vertex:%X\n", header_ptr);
			buf = cast(uint*) ch.array[header_ptr .. header_ptr + uint.sizeof];
			*buf = len;
			header_ptr += uint.sizeof;

			// сохранить label
			ptr += SIZE_HEADER_VERTEX;
			//			printf("store label:%X\n", ptr);
			offset_label = SIZE_HEADER_VERTEX;
			ubyte[] data = cast(ubyte[]) ch.array[ptr .. ptr + label.length];
			ubyte[] bstr = cast(ubyte[]) label;
			data[] = bstr[];
			length_label = cast(uint) bstr.length;
			ptr += length_label;

			// сохранить length_label
			//			printf("store len label:[%X]=%X\n", header_ptr, length_label);
			buf = cast(uint*) ch.array[header_ptr .. header_ptr + uint.sizeof];
			*buf = length_label;
			header_ptr += uint.sizeof;

			// сохранить properties
			offset_properties = ptr - offset;
			length_properties = cast(uint) properties.length;

			//			writeln("properties=", properties);

			// сохранить offset_properties
			buf = cast(uint*) ch.array[header_ptr .. header_ptr + uint.sizeof];
			//			printf("offset_properties [%X]=%X\n", header_ptr, offset_properties);
			*buf = offset_properties;
			header_ptr += uint.sizeof;

			// сохранить length_properties
			buf = cast(uint*) ch.array[header_ptr .. header_ptr + uint.sizeof];
			*buf = length_properties;
			header_ptr += uint.sizeof;
			//			printf("count properties: [%X]=[%X]\n", header_ptr, length_properties);

			ptr = store_elements(properties, ptr);

			offset_out_edges = ptr - offset;
			//			printf("offset_out_edges [%X]=%X\n", header_ptr, offset_out_edges);
			length_out_edges = cast(uint) out_edges.length;

			// сохранить offset_out_edges
			buf = cast(uint*) ch.array[header_ptr .. header_ptr + uint.sizeof];
			*buf = offset_out_edges;
			header_ptr += uint.sizeof;

			// сохранить length_out_edges
			buf = cast(uint*) ch.array[header_ptr .. header_ptr + uint.sizeof];
			*buf = length_out_edges;
			header_ptr += uint.sizeof;

			ptr = store_elements(out_edges, ptr);
		} else
		{
			return false;
		}

		return true;
	}

	private uint store_elements(ref string[][string] properties, uint ptr)
	{
		uint* buf;
		ubyte[] data;
		ubyte[] bstr;

		foreach(key; properties.keys)
		{
			string[] values = properties.get(key, []);

			// сохраним размер label
			buf = cast(uint*) ch.array[ptr .. ptr + uint.sizeof];
			*buf = cast(uint) key.length;
			ptr += uint.sizeof;

			// сохраним label
			data = cast(ubyte[]) ch.array[ptr .. ptr + key.length];
			bstr = cast(ubyte[]) key;
			data[] = bstr[];
			ptr += key.length;

			// сохраним количество значений в values
			buf = cast(uint*) ch.array[ptr .. ptr + uint.sizeof];
			*buf = cast(uint) values.length;
			//			printf("count values: [%X]=[%X]\n", ptr, values.length);
			ptr += uint.sizeof;

			// сохраним значения
			foreach(value; values)
			{
				// сохраним размер value   
				buf = cast(uint*) ch.array[ptr .. ptr + uint.sizeof];
				*buf = cast(uint) value.length;
				//				printf("length value: [%X]=[%X]\n", ptr, value.length);
				//				writeln("value=[", value, "]");
				ptr += uint.sizeof;

				// сохраним содержимое value   
				data = cast(ubyte[]) ch.array[ptr .. ptr + value.length];
				bstr = cast(ubyte[]) value;
				data[] = bstr[];
				ptr += value.length;
			}
		}

		return ptr;
	}

	string[] getProperty(string _label)
	{
		string[] res;
		if(length_properties > 0 && properties.length == 0)
		{
			//			printf("length_properties=%X\n", length_properties);

			// init
			uint i_ptr = offset + offset_properties;
			//			printf("i_ptr=%X\n", i_ptr);

			for(int ii = 0; ii < length_properties; ii++)
			{
				uint length = *cast(uint*) ch.array[i_ptr .. i_ptr + uint.sizeof];
				//				printf("length element of property=%X\n", length);
				i_ptr += uint.sizeof;

				string label = cast(string) ch.array[i_ptr .. i_ptr + length];
				i_ptr += length;
				//				writeln("label element of property=", label);

				uint count_values = *cast(uint*) ch.array[i_ptr .. i_ptr + uint.sizeof];
				i_ptr += uint.sizeof;
				//				printf("count_values element of property=%X\n", count_values);

				if(i_ptr > offset + offset_out_edges)
				{
					writeln("#1 i_ptr > offset_out_edges");
					return [];
				}

				string[] values = new string[count_values];
				for(int jj = 0; jj < count_values; jj++)
				{
					length = *cast(uint*) ch.array[i_ptr .. i_ptr + uint.sizeof];
					//					printf("length value of element of property[%X]=%X\n", i_ptr, length);
					i_ptr += uint.sizeof;

					string value = cast(string) ch.array[i_ptr .. i_ptr + length];
					i_ptr += length;
					//					writeln("value element of property=", value);

					if(i_ptr > offset + offset_out_edges)
					{
						writeln("#2 i_ptr > offset_out_edges");
						return [];
					}

					values[jj] = value;
				}

				properties[label] = values;
			}

		}

		res = properties.get(_label, []);
		return res;
	}

	string[] get_OutEdge_values_use_cache(string _label)
	{
		string[] res;
		if(length_out_edges > 0 && out_edges.length == 0)
		{
			// init
			uint i_ptr = offset + offset_out_edges;

			for(int ii = 0; ii < length_out_edges; ii++)
			{
				uint length = *cast(uint*) ch.array[i_ptr .. i_ptr + uint.sizeof];
				i_ptr += uint.sizeof;

				string label = cast(string) ch.array[i_ptr .. i_ptr + length];
				i_ptr += length;

				uint count_values = *cast(uint*) ch.array[i_ptr .. i_ptr + uint.sizeof];
				i_ptr += uint.sizeof;

				if(i_ptr > offset + size)
					return [];

				string[] values = new string[count_values];
				for(int jj = 0; jj < count_values; jj++)
				{
					length = *cast(uint*) ch.array[i_ptr .. i_ptr + uint.sizeof];
					i_ptr += uint.sizeof;

					string value = cast(string) ch.array[i_ptr .. i_ptr + length];
					i_ptr += length;

					if(i_ptr > offset + size)
						return [];

					values[jj] = value;
				}

				out_edges[label] = values;
			}

		}

		res = out_edges.get(_label, []);
		return res;
	}

	string[] get_OutEdge_values(string _label)
	{
		if(length_out_edges > 0)
		{
			// init
			uint i_ptr = offset + offset_out_edges;

			for(int ii = 0; ii < length_out_edges; ii++)
			{
				uint length = *cast(uint*) ch.array[i_ptr .. i_ptr + uint.sizeof];
				i_ptr += uint.sizeof;

				string label = cast(string) ch.array[i_ptr .. i_ptr + length];
				i_ptr += length;

				uint count_values = *cast(uint*) ch.array[i_ptr .. i_ptr + uint.sizeof];
				i_ptr += uint.sizeof;

				if(i_ptr > offset + size)
					return [];

				string[] values = new string[count_values];
				for(int jj = 0; jj < count_values; jj++)
				{
					length = *cast(uint*) ch.array[i_ptr .. i_ptr + uint.sizeof];
					i_ptr += uint.sizeof;

					string value = cast(string) ch.array[i_ptr .. i_ptr + length];
					i_ptr += length;

					if(i_ptr > offset + size)
						return [];

					values[jj] = value;
				}

				if(label == _label)
					return values;
			}

		}

		return [];
	}

	string get_OutEdge_value(string _label)
	{
		if(length_out_edges > 0 && out_edges.length == 0)
		{
			// init
			uint i_ptr = offset + offset_out_edges;

			for(int ii = 0; ii < length_out_edges; ii++)
			{
				uint length = *cast(uint*) ch.array[i_ptr .. i_ptr + uint.sizeof];
				i_ptr += uint.sizeof;

				string label = cast(string) ch.array[i_ptr .. i_ptr + length];
				i_ptr += length;

				uint count_values;
				count_values = *cast(uint*) ch.array[i_ptr .. i_ptr + uint.sizeof];
				i_ptr += uint.sizeof;

				if(i_ptr > offset + size)
					return "";

				for(int jj = 0; jj < count_values; jj++)
				{
					length = *cast(uint*) ch.array[i_ptr .. i_ptr + uint.sizeof];
					i_ptr += uint.sizeof;

					if(label == _label)
					{
						string value = cast(string) ch.array[i_ptr .. i_ptr + length];
						return value;
					}
					i_ptr += length;

					if(i_ptr > offset + size)
						return "";

				}
			}

		}

		return "";
	}

}
