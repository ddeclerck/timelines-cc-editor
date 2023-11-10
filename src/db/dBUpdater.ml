(**************************************************************************)
(*                                                                        *)
(*                 Copyright 2020-2023 OCamlPro                           *)
(*                                                                        *)
(*  All rights reserved. This file is distributed under the terms of the  *)
(*  GNU General Public License version 3.0 as described in LICENSE        *)
(*                                                                        *)
(**************************************************************************)

open Database_version.DBVersions
open Config.DB

let () =
  EzPGUpdater.main
    default_database
    ?host
    ?port
    ?user
    ?password
    ~upgrades
    ~downgrades
