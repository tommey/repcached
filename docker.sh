#!/usr/bin/env bash
set -e

VERSION=$(cat version.m4 | cut -d '[' -f3 | cut -d ']' -f1)
IMAGE=repcached:$VERSION
export IMAGE

command="$1"
shift

case "$command" in
  build)
    docker build $@ --platform=linux/amd64 --progress=plain -t $IMAGE .
    ;;
  extract)
    docker run --rm --platform=linux/amd64 $IMAGE cat /usr/bin/memcached > memcached
    chmod +x memcached
    ;;
  run)
    docker-compose up -d --force-recreate $@
    ;;
  logs)
    docker-compose logs -t --no-color $@ | sort -u -k 3
    ;;
  tail)
    docker-compose logs -t -f --since 1s
    ;;
  bash)
    docker-compose exec repcached bash
    ;;
  dc)
    docker-compose $@
    ;;
  ci)
    ./docker.sh build
    ./docker.sh tests
    ;;
  tests)
    # Note: when starting at the same time there is a chance they both fail the initial connection
    # and won't replicate as there is no retry yet; therefore a delay makes it more reliable.
    echo "Stop if running"
    ./docker.sh stop
    echo "Start both"
    ./docker.sh run
    echo "Wait for them to start listening"
    until echo -n | nc -z localhost 21211; do sleep 0.1; done && echo "Repcached 1 is up!"
    until echo -n | nc -z localhost 31211; do sleep 0.1; done && echo "Repcached 2 is up!"
    echo "Restart first instance to make sure they connect for replication"
    ./docker.sh run repcached
    echo "Wait for it to start"
    until echo -n | nc -z localhost 21211; do sleep 0.1; done && echo "Repcached 1 is up!"
    echo "Wait for replication to start"
    sleep 1

    ./docker.sh test
    ;;
  test)
    echo "Testing replication - SET a key and read on both instances"
    RANDOM_KEY=key_$(head /dev/urandom | LC_CTYPE=C tr -dc A-Za-z0-9 | head -c 5)
    RANDOM_VALUE=value_$(head /dev/urandom | LC_CTYPE=C tr -dc A-Za-z0-9 | head -c 13)
    echo "SET $RANDOM_KEY in instance 1 with value: $RANDOM_VALUE"
    echo -e "set $RANDOM_KEY 0 2 ${#RANDOM_VALUE}\r\n$RANDOM_VALUE\r\nquit\r\n" | nc localhost 21211 | grep STORED
    echo "GET $RANDOM_KEY in instance 1"
    echo -e "get $RANDOM_KEY\r\nquit\r\n" | nc localhost 21211 | grep $RANDOM_VALUE
    echo "GET $RANDOM_KEY in instance 2"
    echo -e "get $RANDOM_KEY\r\nquit\r\n" | nc localhost 31211 | grep $RANDOM_VALUE
    ;;
  stop)
    docker-compose down --remove-orphans
    ;;
  *)
    echo "Usage: $0 {build|run|logs|tail|bash|ci|test|tests}"
    echo "  build   - Build the Docker image"
    echo "  extract - Extract the memcached binary from the Docker image"
    echo "  run     - Start the Docker containers"
    echo "  logs    - Show logs from the Docker containers, additional arguments are passed through, for example --since 1m"
    echo "  tail    - Tail the logs from the Docker containers, starting 1 second ago"
    echo "  bash    - Open a bash shell in the first instance's container"
    echo "  dc      - Run a docker-compose command with the rest of the arguments passed through"
    echo "  ci      - Run the build and test commands"
    echo "  tests   - Run 2 repcached instances and test"
    echo "  test    - Run a simple check if the replication is working"
    echo "  stop    - Stop the Docker containers"
    exit 1
    ;;
esac
