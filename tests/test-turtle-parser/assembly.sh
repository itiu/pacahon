rm test-turtle-parser-*
mdir=$PWD
cd ..
cd .. 
pr_dir=$PWD
cd $mdir

~/dmd/linux/bin/dmd -version=D1 -debug -g $mdir/test-turtle-parser.d $pr_dir/src/graph.d $pr_dir/src/turtle-parser.d -oftest-turtle-parser-D1
~/dmd2/linux/bin/dmd -version=D2 -debug -g $mdir/test-turtle-parser.d $pr_dir/src/graph.d $pr_dir/src/turtle-parser.d -oftest-turtle-parser-D2

rm *.o