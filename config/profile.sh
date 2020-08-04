#!/bin/sh

# User ID.
USER_ID=$(id -u);
export USER_ID;

# Faering environment variables.
set -a
[ -f "${FAERING:-~/.faering}/.env.dist" ] && export $(grep "FAERING_" "${FAERING:-~/.faering}/.env.dist");
[ -f "${FAERING:-~/.faering}/.env" ] && export $(grep "FAERING_" "${FAERING:-~/.faering}/.env");
set +a
