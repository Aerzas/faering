#!/bin/sh

# User ID.
export USER_ID=$(id -u);

# Faering environment variables.
set -a
[ -f "${FAERING:-~/.faering}/.env.dist" ] && . ${FAERING:-~/.faering}/.env.dist;
[ -f "${FAERING:-~/.faering}/.env" ] && . ${FAERING:-~/.faering}/.env;
set +a
