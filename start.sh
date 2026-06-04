#!/bin/bash
python /srv/ibeam/proxy.py &
exec python /srv/ibeam/ibeam_starter.py
