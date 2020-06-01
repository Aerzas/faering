#!/bin/sh

# User ID.
export USER_ID=$(id -u);

# Faering environment variables.
set -a
[ -f "${FAERING:-~/.faering}/.env.dist" ] && export $(cat "${FAERING:-~/.faering}/.env.dist" | grep "FAERING_");
[ -f "${FAERING:-~/.faering}/.env" ] && export $(cat "${FAERING:-~/.faering}/.env" | grep "FAERING_");
set +a
