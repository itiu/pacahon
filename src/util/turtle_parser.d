module util.turtle_parser;

private import std.string;
private import std.c.stdlib;
private import std.c.string;
private import std.stdio;
private import std.datetime;
private import std.outbuffer;

private import pacahon.graph;
private import util.utils;

/*
 *  src - С-шная строка содержащая факты в формате n3,
 *  len - длинна исходной строки,
 */

public Subject[] parse_turtle_string(char *src, int len)
{
//	StopWatch sw;
//	sw.start();

    if (src is null)
        return null;

    if (len == 0)
        return null;

    char         *ptr          = src - 1;
    char         *new_line_ptr = src;
    char         ch            = *src;
    char         prev_ch       = 0;

    GraphCluster res = new GraphCluster();

    Subject[]    subject_level = new Subject[ 3 ];
    char         prev_el;
    Subject      ss;
    Predicate    pp;
    int          level = 0;
    byte         state = 0;

    while (ch != 0 && ptr - src < len)
    {
//				writeln ("0 BEGIN CH:", *ptr);
        prev_ch = ch;
        ptr++;
        if (ptr - src > len)
            break;

        ch = *ptr;

        if (ptr == src || prev_ch == '\n' || prev_ch == '\r')
        {
            if (ch == '\n' || ch == '\r')
            {
                continue;
            }

            // new line
            new_line_ptr = ptr;

            //			printf("!NewLine!%s\n", new_line_ptr);

            if (ch == '@')
            {
                // это блок назначения префиксов

                // пропускаем строку
                while (ch != '\n' && ch != '\r' && ptr - src < len)
                {
                    ptr++;
                    ch      = *ptr;
                    prev_ch = ch;
                }
                continue;
            }

            if (ch == '#')
            {
                // это комментарий

                // пропускаем строку
                while (ch != '\n' && ch != '\r' && ptr - src < len)
                {
                    ptr++;
                    ch      = *ptr;
                    prev_ch = ch;
                }
                continue;
            }

            while (ch != '\n' && ch != '\r' && ch != 0)
            {
//				writeln ("1 BEGIN CH:", *ptr);

                // пропустим пробелы и tab
                while ((ch == ' ' || ch == '\t') && ptr - src < len)
                {
                    ptr++;
                    ch = *ptr;
                }

                // это начало элемента
                char *start_el = ptr;
                char *end_el   = ptr;
//				writeln ("2 CH0 [", *start_el, "]");

                // пропускаем термы в кавычках (" или """)
                bool is_multiline_quote = false;
                if (*start_el == '"')
                {
                    if (*(start_el + 1) == '"' && *(start_el + 2) == '"')
                    {
                        start_el          += 2;
                        end_el             = start_el;
                        is_multiline_quote = true;
                    }

                    ch = *end_el;
                    while (end_el - src < len)
                    {
                        if (ch == '"')
                        {
                            if (end_el - src < len - 2 && *(end_el + 1) == '"' && *(end_el + 2) == '"')
                            {
                                break;
                            }

                            if (is_multiline_quote == false)
                                break;
                        }

                        end_el++;
                        ch = *end_el;
                    }
                }

                int length_el;

//				writeln("CH1:", ch, ", ", cast(int)ch);
                if (ch == ']' || ch == ';')
                {
//				writeln("CH1:", ch, ", ", cast(int)ch);
//					writeln ("!!!!1");
                    length_el = 1;
                }
                else if (ch == ',' || ch == '.' || ch == '[')
                {
                    length_el = 1;
                }
                else
                {
                    while (end_el - src < len - 1)
                    {
//						writeln("CH2:", ch, ", ", cast(int)ch);
                        if (ch == ';' || ch == ' ' || ch == '\r')
                            break;
                        if (ch == '\n' || ch == ',')
                            break;
                        if (ch == '.' || ch == '[' || ch == ']')
                            break;

                        end_el++;
                        ch = *end_el;
                    }

                    length_el = cast(int)(end_el - start_el);
                    if (is_multiline_quote)
                        length_el -= 3;
                }

                if (length_el > 0)
                {
                    ptr = end_el;

                    if (ss is null)
                        ss = new Subject();

                    prev_el = next_element(start_el, length_el, ss, pp, &state);
                    if (prev_el == '.')
                    {
//						writeln ("@ add to res:", ss);
                        res.addSubject(ss);
                        pp = null;
                    }
                    else if (prev_el == '[')
                    {
                        subject_level[ level ] = ss;
                        level++;
//					writeln ("@ ++ level !!!:", level);
                        Subject sub_subj = new Subject();
                        sub_subj.subject = "";
                        pp.addSubject(sub_subj);
                        ss    = sub_subj;
                        state = 1;
                    }
                    else if (prev_el == ']')
                    {
                        level--;
                        ss = subject_level[ level ];
//						writeln ("@ -- level !!!:", level, ", ss=", ss);
                    }
                    else if (prev_el == ';')
                    {
//						writeln ("*1");
                        state = 1;
                    }

                    if (state == 1)
                    {
//					writeln ("@ new empty predicate");
                        pp = new Predicate();
                    }
                }
//				writeln ("1 END CH:", *ptr);

//				writeln ("0 END CH:", *ptr);
                ptr++;
                if (ptr - src > len - 2)
                    break;
                ch = *ptr;
//				writeln ("1 END CH:", ch);

//						writeln ("----");
                //				printf("[%s]\n", element);
            }
        }
    }

//	 sw.stop();
//	 long t = cast(long) sw.peek().usecs;
//	 writeln ("turtle parser [µs] ", t);

    return res.getArray();
}

private char next_element(char *element, int el_length, Subject ss, Predicate pp, byte *state)
{
    if (element is null)
        return 0;

//	writeln ("el:", element[0..el_length], ", el_length:", el_length);

    char ch = *element;

    if (el_length == 1 && (ch == '[' || ch == ','))
        return *element;

    if (el_length == 1 && (ch == ']' || ch == ';' || ch == '.'))
        return *element;

    bool is_quoted = false;
    if (*element == '"')
    {
        element++;
        el_length -= 2;
    }

    if (ss.subject is null)
    {
        ss.subject = cast(immutable)element[ 0..el_length ];
//	    writeln ("@ add new subject");
        *state = 1;
        return 0;
    }

    if (*state == 1)
    {
//	    writeln ("@ add predicate");
        *state       = 2;
        pp.predicate = cast(immutable)element[ 0..el_length ];
        ss.addPredicate(pp);
        return 0;
    }

    if (*state == 2)
    {
//	    writeln ("@ set object");
        pp.addLiteral(cast(immutable)element[ 0..el_length ]);
        return 0;
    }

    return 0;
}


void toTurtle(Subject ss, ref OutBuffer outbuff, int level = 0, bool asCluster = false)
{
    for (int i = 0; i < level; i++)
        outbuff.write(cast(char[])"  ");

    if (ss.subject !is null)
        outbuff.write(ss.subject);

    foreach (pp; ss.getPredicates())
    {
        for (int i = 0; i < level; i++)
            outbuff.write(cast(char[])" ");

        outbuff.write(cast(char[])"  ");
        outbuff.write(pp.predicate);

        int jj = 0;
        foreach (oo; pp.getObjects())
        {
            for (int i = 0; i < level; i++)
                outbuff.write(cast(char[])" ");

            if (oo.type == OBJECT_TYPE.LITERAL)
            {
                if (asCluster)
                    outbuff.write(cast(char[])"   \\\"");
                else
                    outbuff.write(cast(char[])"   \"");


                // заменим все неэкранированные кавычки на [\"]
                char   prev_ch;
                char[] new_str        = new char[ oo.literal.length * 2 ];
                int    pos_in_new_str = 0;
                int    len            = cast(uint)oo.literal.length;

                for (int i = 0; i < len; i++)
                {
                    // если подряд идут "", то пропустим их
                    if (len > 4 && (i == 0 || i == len - 2) && oo.literal[ i ] == '"' && oo.literal[ i + 1 ] == '"')
                    {
                        for (byte hh = 0; hh < 2; hh++)
                        {
                            new_str[ pos_in_new_str ] = oo.literal[ i ];
                            pos_in_new_str++;
                            i++;
                        }
                    }

                    if (i >= len)
                        break;

                    char ch = oo.literal[ i ];

                    if (ch == '"' && len > 4)
                    {
                        new_str[ pos_in_new_str ] = '\\';
                        pos_in_new_str++;
                        new_str[ pos_in_new_str ] = '\\';
                        pos_in_new_str++;
                    }

                    new_str[ pos_in_new_str ] = ch;
                    pos_in_new_str++;

                    prev_ch = ch;
                }
                new_str.length = pos_in_new_str;

                outbuff.write(new_str);

                if (asCluster)
                    outbuff.write(cast(char[])"\\\"");
                else
                    outbuff.write(cast(char[])"\"");

                if (oo.lang == LANG.RU)
                {
                    outbuff.write(cast(char[])"@ru");
                }
                else if (oo.lang == LANG.EN)
                {
                    outbuff.write(cast(char[])"@en");
                }
            }
            else if (oo.type == OBJECT_TYPE.URI)
            {
                outbuff.write(cast(char[])"   ");
                outbuff.write(oo.literal);
            }
            else if (oo.type == OBJECT_TYPE.SUBJECT)
            {
                outbuff.write(cast(char[])"\n  [\n");
                toTurtle(oo.subject, outbuff, level + 1);
                outbuff.write(cast(char[])"\n  ]");
            }
            else if (oo.type == OBJECT_TYPE.CLUSTER)
            {
                outbuff.write(cast(char[])" \"\"\"");
                foreach (s; oo.cluster.getArray())
                {
                    toTurtle(s, outbuff, 0, true);
                }
                outbuff.write(cast(char[])"\"\"\"");
            }

            if (jj == ss.count_edges - 1)
            {
                if (level == 0)
                    outbuff.write(cast(char[])" .");
            }
            else
            {
                outbuff.write(cast(char[])" ;\n");
            }

            jj++;
        }
    }

    return;
}

void toTurtle(Subject[] results, ref OutBuffer outbuff, int level = 0)
{
    for (int ii = 0; ii < results.length; ii++)
    {
        Subject out_message = results[ ii ];

        if (out_message !is null)
        {
            toTurtle(out_message, outbuff);
        }
    }
}

/*
   char* toTurtle(GraphCluster gcl)
   {
   OutBuffer outbuff = new OutBuffer();

   outbuff.write(cast(char[]) "\"\"");
   foreach(s; gcl.graphs_of_subject)
   {
   toTurtle(s, outbuff, true);
   }
   outbuff.write(cast(char[]) "\"\"");

   outbuff.write(0);

   //		printf ("***:%s\n", cast(char*) outbuff.toBytes());

   return cast(char*) outbuff.toBytes();
   }
 */


