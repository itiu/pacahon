mongo_d_driver__hash=2f60737
trioplax__hash=9aaeb3f
zeromq__hash=1aab186

trioplax__project_name=itiu-trioplax
mongo_d_driver__project_name=itiu-mongo-d-driver
zeromq__project_name=itiu-zeromq-connector

mkdir build
rm -r build/src
mkdir build/src


mdir=$PWD

cp -v -r src/* build/src
cp -v -r build/$trioplax__project_name-$trioplax__hash/src/* build/src
cp -v -r build/$mongo_d_driver__project_name-$mongo_d_driver__hash/src/* build/src
cp -v -r build/$zeromq__project_name-$zeromq__hash/src/* build/src




#echo $mdir

#cd $mdir

rm build/src/test_recieve.d 
rm build/src/test_send.d

git log -1 --pretty=format:"module myversion; public final static char[] author=\"%an\"; public final static char[] date=\"%ad\"; public final static char[] hash=\"%h\";">myversion.d

rm Pacahon
dmd -debug -g myversion.d build/src/trioplax/memory/*.d build/src/trioplax/mongodb/*.d build/src/trioplax/*.d build/src/*.d lib/libzmq.a lib/libstdc++.a lib/libuuid.a -ofPacahon
rm *.o

 