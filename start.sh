#!/bin/bash
nginx -c /srv/ibeam/nginx.conf &
exec python /srv/ibeam/ibeam_starter.py
