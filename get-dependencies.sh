mongo_d_driver__hash=0bbebb1
trioplax__hash=b41cbfd 
zeromq__hash=eb076e1

trioplax__project_name=itiu-trioplax
mongo_d_driver__project_name=itiu-mongo-d-driver
zeromq__project_name=itiu-zeromq-connector

mkdir build
cd build
mkdir src

wget --no-check-certificate http://github.com/itiu/mongo-d-driver/zipball/$mongo_d_driver__hash
unzip $mongo_d_driver__hash
rm $mongo_d_driver__hash

wget --no-check-certificate http://github.com/itiu/trioplax/zipball/$trioplax__hash
unzip $trioplax__hash
rm $trioplax__hash

wget --no-check-certificate http://github.com/itiu/zeromq-connector/zipball/$zeromq__hash
unzip $zeromq__hash
rm $zeromq__hash

cd ..

cp -v -r build/$trioplax__project_name-$trioplax__hash/src/* build/src
cp -v -r build/$mongo_d_driver__project_name-$mongo_d_driver__hash/src/* build/src
cp -v -r build/$zeromq__project_name-$zeromq__hash/src/* build/src

rm build/src/test_recieve.d 
rm build/src/test_send.d


