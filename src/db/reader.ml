
open Data_types
open Db_intf
open Utils

let verbose_mode = ref false
let verbose_counter = ref 0

let search_limit = 20

let hash str = Sha512.(to_hex (string str))

let salted_hash i str = hash ((Int32.to_string i) ^ str)

module Reader_generic (M : Db_intf.MONAD) = struct
  module Monad = M
  open M

  module PGOCaml_old = PGOCaml_generic.Make(M)

  module PGOCaml = struct
    include PGOCaml_old
    let prepare dbh ~name ~query () =
      if !verbose_mode then
        Printf.eprintf "DB %S PREPARE %s\n%!" name query;
      prepare dbh ~name ~query ()

    let execute_rev dbh ~name ~params () =
      if !verbose_mode then begin
        incr verbose_counter;
        let counter = !verbose_counter in
        Printf.eprintf "DB x%dx begin %s\n%!" counter name;
        bind (execute_rev dbh ~name ~params ())
          (fun rows ->
             Printf.eprintf "DB x%dx end %s\n%!" counter name;
             return rows)
      end else
        execute_rev dbh ~name ~params ()
  end
  let dbh_pool =
    let validate conn =
      PGOCaml.alive conn >>= fun is_alive ->
      M.return is_alive in
    let check _conn is_ok =
      is_ok false in
    let dispose conn =
      PGOCaml.close conn in
    M.pool_create ~check ~validate ~dispose 20 (fun () ->
      PGOCaml.connect ~database:Config.database ())

  let with_dbh f = M.pool_use dbh_pool f

  let (>>>) f g = f g

  let line_to_event ?(with_end_date=true) line =
    match line with
      (id, Some start_date, end_date, headline, text, url, group, confidential, ponderation) ->
      Int32.to_int id, {
        start_date;
        end_date = if with_end_date then end_date else None;
        text = {
          text;
          headline};
        media = opt (fun url -> {url}) url;
        group;
        confidential;
        ponderation = Int32.to_int ponderation
      }

    | _ -> assert false

  let event auth id =
    let id = Int32.of_int id in
    with_dbh >>> fun dbh ->
    PGSQL(dbh)
      "SELECT * FROM events_ \
       WHERE (id_ = $id) AND ($auth OR NOT confidential_)" >>= function
    | res :: _ ->
      let (_, event) = line_to_event res in
      return (Some event)
    | _ -> return None

  let events auth =
    with_dbh >>> fun dbh ->
    PGSQL(dbh) "SELECT * FROM events_ WHERE id_ > 0 AND ($auth OR NOT confidential_) ORDER BY id_ DESC" >>=
    fun l ->
    return @@ List.map line_to_event l

  let title () =
    with_dbh >>> fun dbh ->
    PGSQL(dbh) "SELECT * FROM events_ WHERE id_ = 0" >>=
    function
    | [] -> return None
    | (_,_,_,headline, text,_,_,_,_) :: _ -> return (Some {headline; text})

  let category_exists group =
    with_dbh >>> fun dbh ->
    PGSQL(dbh) "SELECT * FROM groups_ WHERE group_ = $group" >>=
    function
    | [] -> return false
    | _  -> return true

  let categories () =
    with_dbh >>> fun dbh -> PGSQL(dbh) "SELECT * FROM groups_"

  let timeline_data
      ?(start_date      = CalendarLib.Date.mardi_gras 1000)
      ?(end_date        = CalendarLib.Date.mardi_gras 3000)
      ?(min_ponderation = 0)
      ?(max_ponderation = 100)
      ?group
      auth
      () =
    let min_ponderation = Int32.of_int min_ponderation in
    let max_ponderation = Int32.of_int max_ponderation in
    with_dbh >>> fun dbh ->
    let req =
      match group with
        None -> begin
          PGSQL(dbh)
            "SELECT * FROM events_ WHERE \
             id_ > 0 AND \
             (start_date_ BETWEEN $start_date AND $end_date) AND \
             (ponderation_ BETWEEN $min_ponderation AND $max_ponderation) \
             AND ($auth OR NOT confidential_) \
             ORDER BY id_ DESC" end
      | Some group ->
        PGSQL(dbh)
            "SELECT * FROM events_ WHERE \
             id_ > 0 AND \
             group_ = $group AND \
             (start_date_ BETWEEN $start_date AND $end_date) AND \
             (ponderation_ BETWEEN $min_ponderation AND $max_ponderation) \
             AND ($auth OR NOT confidential_) \
             ORDER BY id_ DESC"
    in
    req >>= fun l ->
    return @@ List.map (fun l -> (line_to_event ~with_end_date:false l)) l

  let user_exists email =
    with_dbh >>> fun dbh ->
    PGSQL(dbh) "SELECT id_ FROM users_ WHERE email_=$email" >>=
    function
    | []      -> return None
    | id :: _ -> return (Some id)

  let login email pwdhash =
    Format.printf "Login %s with %s@." email pwdhash;
    with_dbh >>> fun dbh ->
    PGSQL(dbh) "SELECT id_, pwhash_ FROM users_ WHERE email_=$email" >>=
    function
    | [] ->
      return false
    | (id, saved_hash) :: _ ->
      let challenger_hash = salted_hash id pwdhash in
      Format.printf "New login attempt@.";
      let res = String.equal challenger_hash saved_hash in
      if res then
        Format.printf "New login from %s@." email
      else
        Format.printf "Failed login on %s@." email;
      return res
end

module Self = Reader_generic(Db_intf.Default_monad)
include Self
