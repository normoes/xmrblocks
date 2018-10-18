#!/bin/bash


# used for xmrblocks
OPTIONS="-b $LMDB_PATH --port $PORT  --enable-autorefresh-option=$ENABLE_AUTOREFRESH"

if [[ "${1:0:1}" = '-' ]]  || [[ -z "$@" ]]; then
  set -- "xmrblocks $@ $OPTIONS"
fi

# allow the container to be started with `--user
if [ "$(id -u)" = 0 ]; then
  # USER_ID defaults to 1000 (Dockerfile)
  adduser --system --group --uid "$USER_ID" --shell /bin/false xmrblocks &> /dev/null
  # in order not to replace within the original files (mounted volume)
  cp -R /data/templates_template/. /data/templates/
  for i in /data/templates/*.html; do sed  -i "s|\_\_prefix\_\_|$URL_PREFIX|" $i; done
  for i in /data/templates/partials/*.html; do sed  -i "s|\_\_prefix\_\_|$URL_PREFIX|" $i; done
  su-exec xmrblocks $@
  # cannot use exec with xmrblocks
  # cryptonote::DB_ERROR_TXN_START
  # exec su-exec xmrblocks $@
  exit 1
fi

$@
# cannot use exec with xmrblocks
# cryptonote::DB_ERROR_TXN_START
# exec $@
