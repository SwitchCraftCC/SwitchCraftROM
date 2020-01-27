#!/usr/bin/sh


test -f illuaminate || wget -q -Oilluaminate https://squiddev.cc/illuaminate/bin/illuaminate
chmod +x illuaminate
./illuaminate lint
