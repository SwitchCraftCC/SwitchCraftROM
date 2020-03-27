; -*- mode: Lisp;-*-

(sources /switchcraft)

(at /
  (linters
    -format:separator-space -format:table-trailing
    -var:set-loop
    -var:unused-arg
    -doc:detached-comment -doc:undocumented -doc:undocumented-arg
    -doc:unresolved-reference))

(at
  (/switchcraft/assets/computercraft/lua/bios.lua
   /switchcraft/assets/computercraft/lua/rom/apis/)
  (linters -var:unused-global)
  (lint
    (allow-toplevel-global true)))
