module mmf.mmfgraph;

// изменение узла графа:
//		1. создание нового узла
// 	 	2. деактивация исходного
//		3. замена в индексе поиска по идентификатору, адреса узла на новый

// хранение реифицированных данных:
//
//			I вариант:
//				реификация сохраняется как одно из значений ребра, структура хранения - узел графа
//				если значение начинается с [0], то это реификация предыдущего по списку значения 
// 				реифицированные данные можно добавить к уже существующему
//
//		++ II вариант:
//				сохраняем как обычный узел, однако меняем значение @, на @ = S+P+O, реифицируемых фактов 

private
{
	import std.mmfile;
	import std.stdio;
	import libchash_h;
	import trioplax.Logger;
	import core.memory;
	import std.c.string;
	import std.file;
	import std.conv;
}

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

		writeln("init mmfile, length=", array.length, ", total_allocated_bytes=", allocate_bytes, ", count_allocated_vertex=",
				allocate_vertex);
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

	uint count_keys = 0;
	char*[] keys;

	private bool allocate_new_file()
	{
		if(last_alloc_mmfile + 1 < 256)
			last_alloc_mmfile++;
		else
			return false;

		// откроем новый файл
		MmFileInfo mmfi;
		mmfi.array = new MmFile(file_name_prefix ~ "." ~ text (last_alloc_mmfile), MmFile.Mode.readWriteNew,
				size_hash_file, null, win);
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
			string nfile = "./" ~ file_name_prefix ~ "." ~ text(found_alloc_file);

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
			// загрузим в память ключи и смещения узлов графа
			try
			{
				if(trace)
					writeln("@4");
				found_alloc_file--;
				last_alloc_mmfile = found_alloc_file;

				if(trace)
					writeln("@6");

				keys = new char*[total_count_vertex + 1];

				Iterator it1;

				while(next(it1))
				{
					if(count_keys > 2_100_000)
					{
						log.trace("debug break: count > 2_100_000 ");
						break;
					}

					if(it1.count % 100_000 == 0)
					{
						log.trace("load index into memory%d", it1.count);
					}

					Vertex_vmm* vv = getNext(it1);
					string label = vv.getLabel;

					//					log.trace ("count: %d label: [%s]", count, label);
					if(label.length > 5 && label[0] == '_' && label[1] == ':' && label[2] == 'R')
					{
						// это узел-реификация
						// сформируем для него идентификатор, @ = S + P + O

					}

					if(label.length > 65536)
					{
						log.trace("count=%d, label.length(%d):%s", count_keys, label.length, label);
						break;
					}

					//					keys[count] = cast(char*) GC.malloc(label.length + 1);					
					keys[count_keys] = cast(char*) core.sys.posix.stdlib.malloc(label.length + 1);

					*(keys[count_keys] + label.length) = 0;

					strncpy(keys[count_keys], cast(char*) label, label.length);

					HashInsert(ht, cast(uint) cast(char*) keys[count_keys], vv.getOffset);

					count_keys++;
				}
			} catch(Exception ex)
			{
				log.trace("ex! count_keys=%d", count_keys);
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

	private bool allocate(in uint _size, out MmFileInfo* ch, out uint offset, out uint pos_in_order)
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
		pos_in_order = pos;
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

		uint pos = cast(uint) (cast(uint) chunk[iterator.last_alloc_mmfile].array.length - iterator.count * uint.sizeof - uint.sizeof);
		uint ptr = *cast(uint*) chunk[iterator.last_alloc_mmfile].array[pos .. pos + uint.sizeof];

		if(trace)
			printf("ptr=%X\n", ptr);

		uint len = *cast(uint*) chunk[iterator.last_alloc_mmfile].array[ptr + uint.sizeof .. ptr + uint.sizeof + uint.sizeof];

		if(trace)
			printf("len=%X\n", len);

		Vertex_vmm* vv = null;
		bind_vertex(vv, iterator.last_alloc_mmfile, ptr);

		iterator.count++;
		return vv;
	}

	bool findVertex(ref string label, ref Vertex_vmm* vv)
	{
		//		printf("#1\n");

		HTItem* bck;
		//		writeln("#2, label=", label);

		bck = HashFind1(ht, cast(uint) cast(char*) label, cast(uint) label.length);
		//		printf("#3\n");

		if(bck !is null)
		{
			//			printf("#4\n");
			byte file_number = bck.data & 0x000000FF >> 24;
			uint pos_in_file = bck.data & 0xFFFFFF00;

			//			printf("#5\n");
			if(vv is null)
				vv = new Vertex_vmm;

			//			printf("#6\n");
			bind_vertex(vv, file_number, pos_in_file);
			//			printf("#7\n");
			return true;
		}
		//		printf("#8\n");
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

		vv.offset_edges = *cast(uint*) _array[ptr .. ptr + uint.sizeof];
		ptr += uint.sizeof;

		vv.length_edges = *cast(uint*) _array[ptr .. ptr + uint.sizeof];
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

		uint offset_edges;
		uint length_edges = 0;

		// local
		uint offset_label;
		uint offset;

		// data
		string label;

		//
		int key_idx;
		uint pos_in_order;
	}

	MmFileInfo* ch;
	GraphIO* gio;

	string[][string] edges;

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

	int update_from_file()
	{
		int res = remove_from_file();

		if(res > 0)
		{
			res = insert_to_file();

			return res;
		}
		return -2;
	}

	int remove_from_file()
	{
		// убираем указатель из индекса в памяти
		int res = HashDelete(gio.ht, cast(uint) cast(char*) gio.keys[key_idx]);

		if(res > 0)
		{
			// убираем ссылку на наш граф из файла (список всех графов в конце mmf-файла)
			uint* buf;
			buf = cast(uint*) ch.array[pos_in_order .. pos_in_order + uint.sizeof];
			*buf = 0x00000000;

			pos_in_order = 0;

			return 1;
		}

		return -1;
	}

	int insert_to_file()
	{
		if(label.length > 5 && label[0] == '_' && label[1] == ':' && label[2] == 'R')
		{
			label = "_" ~ edges["rdf:object"][0] ~ "~" ~ edges["rdf:predicate"][0] ~ "~" ~ edges["rdf:subject"][0];
		}

		// вычислить размер сохраняемой структуры
		uint len = SIZE_HEADER_VERTEX;

		len += label.length + uint.sizeof;

		len += uint.sizeof;
		foreach(key; edges.keys)
		{
			len += key.length + uint.sizeof;

			len += uint.sizeof;
			string[] values = edges.get(key, []);
			foreach(value; values)
			{
				len += value.length + uint.sizeof;
			}
		}

		if(trace)
			printf("LEN=%X\n", len);

		bool isAllocate = gio.allocate(len, ch, offset, pos_in_order);

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

			offset_edges = ptr - offset;
			//			printf("offset_out_edges [%X]=%X\n", header_ptr, offset_out_edges);
			length_edges = cast(uint) edges.length;

			// сохранить offset_edges
			buf = cast(uint*) ch.array[header_ptr .. header_ptr + uint.sizeof];
			*buf = offset_edges;
			header_ptr += uint.sizeof;

			// сохранить length_edges
			buf = cast(uint*) ch.array[header_ptr .. header_ptr + uint.sizeof];
			*buf = length_edges;
			header_ptr += uint.sizeof;

			ptr = store_elements(edges, ptr);
		} else
		{
			return -1;
		}

		// занесем указатель на сохраненный vertex в индекс (в пямяти) 		
		gio.keys[gio.count_keys] = cast(char*) core.sys.posix.stdlib.malloc(label.length + 1);
		*(gio.keys[gio.count_keys] + label.length) = 0;
		strncpy(gio.keys[gio.count_keys], cast(char*) label, label.length);

		HashInsert(gio.ht, cast(uint) cast(char*) gio.keys[gio.count_keys], offset);

		key_idx = gio.count_keys;
		gio.count_keys++;

		return 1;
	}

	private uint store_elements(ref string[][string] properties, uint ptr)
	{
		uint* buf;
		ubyte[] data;
		ubyte[] bstr;

		foreach(key; properties.keys)
		{
			string[] values = properties.get(key, []);

			// сохраним размер label, размер ограничен 64K
			buf = cast(uint*) ch.array[ptr .. ptr + ushort.sizeof];
			*buf = cast(ushort) key.length;
			ptr += ushort.sizeof;

			// сохраним label
			data = cast(ubyte[]) ch.array[ptr .. ptr + key.length];
			bstr = cast(ubyte[]) key;
			data[] = bstr[];
			ptr += key.length;

			// сохраним количество значений в values, количество значений ограниченно 64K
			buf = cast(uint*) ch.array[ptr .. ptr + ushort.sizeof];
			*buf = cast(ushort) values.length;
			//			printf("count values: [%X]=[%X]\n", ptr, values.length);
			ptr += ushort.sizeof;

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

	bool init_Edges_values_cache(bool is_create_copy = false)
	{
		uint i_ptr = offset + offset_edges;

		for(int ii = 0; ii < length_edges; ii++)
		{
			// размер label, размер ограничен 64K
			ushort length_label = *cast(ushort*) ch.array[i_ptr .. i_ptr + ushort.sizeof];
			i_ptr += ushort.sizeof;

			string label;

			if(is_create_copy)
			{
				void[] tmp = new void[length_label];
				tmp[] = ch.array[i_ptr .. i_ptr + length_label];
				label = cast(string) tmp;
			} else
			{
				label = cast(string) ch.array[i_ptr .. i_ptr + length_label];
			}

			i_ptr += length_label;

			// количество значений ограниченно 64K
			ushort count_values = *cast(ushort*) ch.array[i_ptr .. i_ptr + ushort.sizeof];
			i_ptr += ushort.sizeof;

			if(i_ptr > offset + size)
				return false;

			string[] values = new string[count_values];
			for(int jj = 0; jj < count_values; jj++)
			{
				uint length = *cast(uint*) ch.array[i_ptr .. i_ptr + uint.sizeof];
				i_ptr += uint.sizeof;

				string value;

				if(is_create_copy)
				{
					void[] tmp = new void[length];

					tmp[] = ch.array[i_ptr .. i_ptr + length];

					value = cast(string) tmp;
				} else
				{
					value = cast(string) ch.array[i_ptr .. i_ptr + length];
				}
				i_ptr += length;

				if(i_ptr > offset + size)
					return false;

				values[jj] = value;
			}

			edges[label] = values;
		}

		return true;
	}

	string[] get_Edge_values_use_cache(ref string _label)
	{
		string[] res;
		if(length_edges > 0 && edges.length == 0)
		{
			if(init_Edges_values_cache() == false)
				return [];
		}

		res = edges.get(_label, []);
		return res;
	}

	string[] get_Edge_values(ref string _label)
	{
		if(length_edges > 0)
		{
			// init
			uint i_ptr = offset + offset_edges;

			for(int ii = 0; ii < length_edges; ii++)
			{
				// размер label, размер ограничен 64K
				ushort length_label = *cast(ushort*) ch.array[i_ptr .. i_ptr + ushort.sizeof];
				i_ptr += ushort.sizeof;

				string label = cast(string) ch.array[i_ptr .. i_ptr + length_label];
				i_ptr += length_label;

				// количество значений ограниченно 64K
				ushort count_values = *cast(ushort*) ch.array[i_ptr .. i_ptr + ushort.sizeof];
				i_ptr += ushort.sizeof;

				if(i_ptr > offset + size)
					return [];

				string[] values = new string[count_values];
				for(int jj = 0; jj < count_values; jj++)
				{
					uint length = *cast(uint*) ch.array[i_ptr .. i_ptr + uint.sizeof];
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

	string get_Edge_first_value(ref string _label)
	{
		if(length_edges > 0 && edges.length == 0)
		{
			// init
			uint i_ptr = offset + offset_edges;

			for(int ii = 0; ii < length_edges; ii++)
			{
				// размер label, размер ограничен 64K
				ushort length_label = *cast(ushort*) ch.array[i_ptr .. i_ptr + ushort.sizeof];
				i_ptr += ushort.sizeof;

				string label = cast(string) ch.array[i_ptr .. i_ptr + length_label];
				i_ptr += length_label;

				// количество значений ограниченно 64K
				ushort count_values;
				count_values = *cast(ushort*) ch.array[i_ptr .. i_ptr + ushort.sizeof];
				i_ptr += ushort.sizeof;

				if(i_ptr > offset + size)
					return "";

				for(int jj = 0; jj < count_values; jj++)
				{
					uint length = *cast(uint*) ch.array[i_ptr .. i_ptr + uint.sizeof];
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

	bool OutEdge_is_exist_value(ref string _label, ref string _test_value)
	{
		if(length_edges > 0 && edges.length == 0)
		{
			// init
			uint i_ptr = offset + offset_edges;

			for(int ii = 0; ii < length_edges; ii++)
			{
				ushort length_label = *cast(ushort*) ch.array[i_ptr .. i_ptr + ushort.sizeof];
				i_ptr += ushort.sizeof;

				string label = cast(string) ch.array[i_ptr .. i_ptr + length_label];
				i_ptr += length_label;

				ushort count_values;
				count_values = *cast(ushort*) ch.array[i_ptr .. i_ptr + ushort.sizeof];
				i_ptr += ushort.sizeof;

				if(i_ptr > offset + size)
					return false;

				for(int jj = 0; jj < count_values; jj++)
				{
					uint length = *cast(uint*) ch.array[i_ptr .. i_ptr + uint.sizeof];
					i_ptr += uint.sizeof;

					if(label == _label)
					{
						string value = cast(string) ch.array[i_ptr .. i_ptr + length];

						if(_test_value == value)
							return true;
					}
					i_ptr += length;

					if(i_ptr > offset + size)
						return false;

				}
			}

		}

		return false;
	}

}
