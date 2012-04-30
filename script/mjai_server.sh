#!/bin/sh

while true; do
  bundle exec ./bin/mjai server \
    --host=0.0.0.0 --port=11600 --game_type=one_kyoku --room=manue-1kyoku --log_dir=./log --repeat \
    ../mjai-manue/bin/mjai-manue \
    ../mjai-manue/bin/mjai-manue \
    ../mjai-manue/bin/mjai-manue \
    >> log/mjai_server.log 2>&1
  sleep 60
done
