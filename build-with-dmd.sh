cp -v -r src/* build/src

git log -1 --pretty=format:"module myversion; public static char[] author=cast(char[])\"%an\"; public static char[] date=cast(char[])\"%ad\"; public static char[] hash=cast(char[])\"%h\";">myversion.d

rm Pacahon-*
rm *.log
rm *.io

bf=build/src

#~/dmd/linux/bin/dmd -version=D1 -debug -g myversion.d build/src/trioplax/memory/*.d build/src/trioplax/mongodb/*.d build/src/trioplax/*.d build/src/*.d lib/libzmq.a lib/libstdc++.a lib/libuuid.a -ofPacahon-D1
#-version=trace_turtle_parser
~/dmd2/linux/bin/dmd -O -version=D2 -version=dmd2_051 -version=trace_turtle_parser0 myversion.d \
$bf/trioplax/mongodb/*.d $bf/trioplax/memory/*.d $bf/rt/util/*.d $bf/trioplax/*.d $bf/*.d \
$bf/tango/util/uuid/*.d  $bf/tango/core/*.d $bf/tango/text/convert/*.d $bf/tango/util/digest/*.d $bf/tango/math/random/*.d \
lib/libzmq.a lib/libstdc++.a lib/libuuid.a -ofPacahon-D2
rm *.o

 
