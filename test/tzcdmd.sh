rm test-turtle-parser
cd ..
mdir=$PWD
cd $mdir/test
#dmd -gc -debug $mdir/test/test-turtle-parser.d $mdir/src/triple.d $mdir/src/turtle-parser.d 
~/dmd2/linux/bin/dmd -version=D2 -debug -g $mdir/test/test-turtle-parser.d $mdir/src/graph.d $mdir/src/turtle-parser.d
#dmd -gc test-turtle-parser.d triple.d turtle-parser.d 
rm *.o