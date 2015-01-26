#!/usr/bash
#
#   Buildbotics server
#
#  Add to system with:
#    sudo update-rc.d buildbotics defaults 90

NAME=buildbotics
EXEC=/usr/local/bin/$NAME
CONFIG=/etc/$NAME/config.xml
USER=server
PIDFILE=/var/run/$NAME.pid

START_STOP_OPTS="-x $EXEC -n $NAME -c $USER -b"


start() {
    start-stop-daemon --start $START_STOP_OPTS -- --config $CONFIG
}


stop() {
    start-stop-daemon --stop $START_STOP_OPTS
}


status() {
    start-stop-daemon --status $START_STOP_OPTS
}


################################################################################
# Main switch statement
#
case "$1" in
    start) start ;;
    stop) stop ;;
    restart) stop; start ;;
    status) status ;;

    *)
      echo "Syntax: $0 <start | stop | restart | status>"
      exit 1
    ;;
esac
