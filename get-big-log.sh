#!/bin/sh

# copy the big log from the running rudybot, since it's great test data.
rsync --progress --recursive linode:v4/big-log .