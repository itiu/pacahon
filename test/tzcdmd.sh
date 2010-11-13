rm test-turtle-parser-*
cd ..
mdir=$PWD
cd $mdir/test

~/dmd/linux/bin/dmd -version=D1 -debug -g $mdir/test/test-turtle-parser.d $mdir/src/graph.d $mdir/src/turtle-parser.d -oftest-turtle-parser-D1
~/dmd2/linux/bin/dmd -version=D2 -debug -g $mdir/test/test-turtle-parser.d $mdir/src/graph.d $mdir/src/turtle-parser.d -oftest-turtle-parser-D2

rm *.o