#!/bin/bash

# Zuul needs to be able to connect to the remote systems in order to
# start.

wait_for_mysql() {
    echo `date -Iseconds` "Wait for mysql to start"
    for i in $(seq 1 120); do
        cat < /dev/null > /dev/tcp/mysql/3306 && return
        sleep 1
    done

    echo `date -Iseconds` "Timeout waiting for mysql"
    exit 1
}

wait_for_gerrit() {
    echo `date -Iseconds` "Wait for zuul user to be created"
    for i in $(seq 1 120); do
        [ $(curl -s -o /dev/null -w "%{http_code}" http://admin:secret@gerrit:8080/a/accounts/zuul/sshkeys) = "200" ] && return
        sleep 1
    done

    echo `date -Iseconds` "Timeout waiting for gerrit"
    exit 1
}

wait_for_mysql
wait_for_gerrit
