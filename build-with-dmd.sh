DMD=~/dmd2-053/linux/bin32/dmd

cp -v -r src/* build/src

git log -1 --pretty=format:"module myversion; public static char[] author=cast(char[])\"%an\"; public static char[] date=cast(char[])\"%ad\"; public static char[] hash=cast(char[])\"%h\";">myversion.d

rm Pacahon-D2-1
rm *.log
rm *.io

bf=build/src


#~/dmd/linux/bin/dmd -version=D1 -debug -g myversion.d build/src/trioplax/memory/*.d build/src/trioplax/mongodb/*.d build/src/trioplax/*.d build/src/*.d lib/libzmq.a lib/libstdc++.a lib/libuuid.a -ofPacahon-D1
#-version=trace_turtle_parser
$DMD -O -version=D2 -version=dmd2_053 -version=trace_turtle_parser0 -inline -d \
lib/dmdscriptlib.a lib/libzmq.a lib/libstdc++.a lib/libuuid.a lib/libmongoc.a \
myversion.d \
$bf/trioplax/mongodb/*.d $bf/trioplax/memory/*.d $bf/rt/util/*.d $bf/trioplax/*.d $bf/*.d \
$bf/tango/util/uuid/*.d  $bf/tango/core/*.d $bf/tango/text/convert/*.d $bf/tango/util/digest/*.d $bf/tango/math/random/*.d \
-ofPacahon-D2-1
rm *.o
