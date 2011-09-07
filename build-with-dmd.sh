DMD=~/dmd2-054/linux/bin32/dmd

VERSION_MAJOR=1
VERSION_MINOR=14
VERSION_PATCH=1   

cp -v -r src/* build/src

git log -1 --pretty=format:"module myversion; public static string major=\"$VERSION_MAJOR\"; public static string minor=\"$VERSION_MINOR\"; public static string patch=\"$VERSION_PATCH\"; public static string author=\"%an\"; public static string date=\"%ad\"; public static string hash=\"%h\";">myversion.d

rm Pacahon-D2-1
rm *.log
rm *.io

bf=build/src


#~/dmd/linux/bin/dmd -version=D1 -debug -g myversion.d build/src/trioplax/memory/*.d build/src/trioplax/mongodb/*.d build/src/trioplax/*.d build/src/*.d lib/libzmq.a lib/libstdc++.a lib/libuuid.a -ofPacahon-D1
#-version=trace_turtle_parser
$DMD -O -version=D2 -version=dmd2_053 -version=trace_turtle_parser0 -inline -d \
lib/dmdscriptlib.a lib/libzmq.a lib/libstdc++.a lib/libuuid.a  \
myversion.d \
$bf/trioplax/mongodb/*.d $bf/trioplax/memory/*.d $bf/rt/util/*.d $bf/trioplax/*.d $bf/*.d \
$bf/tango/util/uuid/*.d  $bf/tango/core/*.d $bf/tango/text/convert/*.d $bf/tango/util/digest/*.d $bf/tango/math/random/*.d \
-ofPacahon-D2-1
rm *.o
