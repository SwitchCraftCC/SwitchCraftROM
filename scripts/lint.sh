#!/usr/bin/sh
set -x

test -f illuaminate || wget -q -Oilluaminate https://squiddev.cc/illuaminate/linux-x86-64/illuaminate
chmod +x illuaminate
./illuaminate lint
