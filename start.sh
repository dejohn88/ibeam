#!/bin/bash
python /srv/ibeam/proxy.py > /proc/1/fd/1 2>/proc/1/fd/2 &
exec python /srv/ibeam/ibeam_starter.py
