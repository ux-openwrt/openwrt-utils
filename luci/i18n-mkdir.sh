#!/bin/sh

luci=$1
dest=$2

[ -n "$luci" ] || luci=.
[ -n "$dest" ] || dest=.

[ -f "$luci/luci.mk" ] || { echo "luci.mk not found in $luci";exit 1; }

[ -d "$luci/modules/luci-base/po" ] || { echo "modules/luci-base/po not found in $luci";exit 1; }

mkdir -p $dest/po/templates
for lang in $(cd $luci/modules/luci-base/po; echo ?? ??_?? ??_????) 
do
    mkdir -p $dest/po/$lang
done
