DMD=dmd
#~/dmd2-055/linux/bin32/dmd

VERSION_MAJOR=1
VERSION_MINOR=18
VERSION_PATCH=0   

cp -v -r src/* build/src

git log -1 --pretty=format:"module myversion; public static string major=\"$VERSION_MAJOR\"; public static string minor=\"$VERSION_MINOR\"; public static string patch=\"$VERSION_PATCH\"; public static string author=\"%an\"; public static string date=\"%ad\"; public static string hash=\"%h\";">myversion.d

rm Pacahon-$VERSION_MAJOR-$VERSION_MINOR-$VERSION_PATCH
rm *.log
rm *.io

bf=build/src


#~/dmd/linux/bin/dmd -version=D1 -debug -g myversion.d build/src/trioplax/memory/*.d build/src/trioplax/mongodb/*.d build/src/trioplax/*.d build/src/*.d lib/libzmq.a lib/libstdc++.a lib/libuuid.a -ofPacahon-D1
#-version=trace_turtle_parser
$DMD -ignore -m32 -O -Iimport -version=D2 -version=dmd2_053 -version=trace_turtle_parser0 -inline -d -L-Llib -L-lluad -L-llua -L-ldl \
lib/libluad.a \
lib/libzmq.a lib/libstdc++.a lib/libuuid.a  \
myversion.d \
$bf/trioplax/mongodb/*.d $bf/trioplax/memory/*.d $bf/rt/util/*.d $bf/trioplax/*.d $bf/*.d \
$bf/tango/util/uuid/*.d  $bf/tango/core/*.d $bf/tango/text/convert/*.d $bf/tango/util/digest/*.d $bf/tango/math/random/*.d \
-ofPacahon-$VERSION_MAJOR-$VERSION_MINOR-$VERSION_PATCH
rm *.o

#lib/dmdscriptlib.a \
#dmdscript/*.d \
