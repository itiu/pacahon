mongo_d_driver__hash=98aad67
trioplax__hash=4c5e642
zeromq__hash=1230c23

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
