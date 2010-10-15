mongo_d_driver__hash=2f60737
trioplax__hash=9aaeb3f
zeromq__hash=1aab186

mkdir build
cd build

wget http://github.com/itiu/mongo-d-driver/zipball/$mongo_d_driver__hash
unzip $mongo_d_driver__hash
rm $mongo_d_driver__hash

wget http://github.com/itiu/trioplax/zipball/$trioplax__hash
unzip $trioplax__hash
rm $trioplax__hash

wget http://github.com/itiu/zeromq-connector/zipball/$zeromq__hash
unzip $zeromq__hash
rm $zeromq__hash
