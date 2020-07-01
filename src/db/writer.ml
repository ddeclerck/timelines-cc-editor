open Timeline_data.Data_types
open Timeline_data.Utils
open Database_reader_lib

let dbh : _ PGOCaml.t PGOCaml.monad =
  let open Config.DB in
  PGOCaml.connect ?host ?password ?port ?user ~database ()

let last_update_timeline (tid : string) last_update =
  [%pgsql dbh "UPDATE timeline_ids_ SET last_update_=$?last_update WHERE id_=$tid"]

let add_event (e : event) (tid : string) =
  let start_date = e.start_date in
  let end_date = e.end_date in
  let headline = e.text.headline in
  let text = e.text.text in
  let media = opt (fun m -> m.url) e.media in
  let group = e.group in
  let ponderation = Int32.of_int e.ponderation in
  let confidential = e.confidential in
  let unique_id = check_unique_id Reader.used_unique_id e.unique_id in
  let last_update = e.last_update in
  let tags = List.map (fun s -> Some s) e.tags in
  try
    let () = 
      [%pgsql dbh
        "INSERT INTO \
         events_(start_date_, end_date_, headline_, text_, \
         media_, group_, confidential_, ponderation_, unique_id_, \
         last_update_, tags_, timeline_id_, is_title_) \
         VALUES($start_date, $?end_date, $headline,$text,\
         $?media,$?group, $confidential, $ponderation, $unique_id, $?last_update, $tags, $tid, \
         false)"] in
    let () = last_update_timeline tid last_update in
    Ok unique_id
  with
    _ -> Error "[Writer.add_event] Error while adding event in DB"
      


let add_title (t : title) (tid : string) =
  let headline = t.text.headline in
  let text = t.text.text in
  let unique_id = check_unique_id Reader.used_unique_id t.unique_id in
  match Reader.title tid with
  | None ->
    let () =
      [%pgsql dbh
        "INSERT INTO events_(headline_, text_, confidential_, ponderation_, timeline_id_, \
         unique_id_, is_title_) VALUES($headline, $text, false, 0, $tid, $unique_id, true)"] in
    let () = last_update_timeline tid t.last_update in
    Ok ()
  | Some _ ->
    Error ("Timeline " ^ tid  ^ "already has a title!")

let update_event (i: int) (e : event) =
  match Reader.timeline_of_event i with
  | Some tid ->
    let i = Int32.of_int i in
    let start_date = e.start_date in
    let end_date = e.end_date in
    let headline = e.text.headline in
    let text = e.text.text in
    let media = opt (fun m -> m.url) e.media in
    let group = e.group in
    let ponderation = Int32.of_int e.ponderation in
    let confidential = e.confidential in
    let unique_id = e.unique_id in
    let last_update = e.last_update in
    let tags = List.map (fun s -> Some s) e.tags in
      let () =
        [%pgsql dbh
            "UPDATE events_ SET start_date_=$start_date, end_date_=$?end_date, \
             headline_=$headline, text_=$text, media_=$?media, group_=$?group, \
             confidential_=$confidential, ponderation_=$ponderation, \
             unique_id_=$unique_id, last_update_=$?last_update, \
             tags_=$tags WHERE id_=$i"] in
      let () = last_update_timeline tid last_update in
      Ok unique_id
  | None -> Error "[update_event] Event is not associated to an existing timeline"

let update_title (i: int) (e : title) =
  match Reader.timeline_of_event i with
  | Some tid ->
    let i = Int32.of_int i in
    let start_date = e.start_date in
    let end_date = e.end_date in
    let headline = e.text.headline in
    let text = e.text.text in
    let media = opt (fun m -> m.url) e.media in
    let group = e.group in
    let ponderation = Int32.of_int e.ponderation in
    let confidential = e.confidential in
    let unique_id = e.unique_id in
    let last_update = e.last_update in
    let tags = List.map (fun s -> Some s) e.tags in
    let () =
      [%pgsql dbh
          "UPDATE events_ SET start_date_=$?start_date, end_date_=$?end_date, \
           headline_=$headline, text_=$text, media_=$?media, group_=$?group, \
           confidential_=$confidential, ponderation_=$ponderation, \
           unique_id_=$unique_id, last_update_=$?last_update, \
           tags_=$tags WHERE id_=$i"] in
    let () = last_update_timeline tid last_update in
    Ok unique_id
  | None -> Error "[update_title] Title is not associated to an existing timeline"

let remove_event (id : int) =
  match Reader.timeline_of_event id with
  | Some tid ->
    let id = Int32.of_int id in
    let () = [%pgsql dbh "DELETE from events_ where id_ = $id"] in 
    let () = last_update_timeline tid (Some (CalendarLib.Calendar.Date.today ())) in 
    Ok ()
  | None -> Error "[remove_title] Event is not associated to an existing timeline"

let update_pwd email pwdhash =
  match Reader.user_exists email with
  | None -> Error ("User " ^ email ^ " does not exist")
  | Some i ->
    let real_pwdhash =
      Reader.salted_hash
        i
        pwdhash
    in
    let () = [%pgsql dbh "UPDATE users_ SET pwhash_=$real_pwdhash WHERE email_=$email"] in
    Ok ()

let create_private_timeline (email : string) (title : title) (timeline_id : string) =
  match Reader.user_exists email with
  | Some _ -> (* User exists, now checking if the timeline already exists *)
    let timeline_id = String.map (function ' ' -> '-' | c -> c) timeline_id in
    let timeline_id = check_unique_id Reader.timeline_exists timeline_id in
    let users = [Some email] in
    Format.eprintf "Timeline id after check: %s@." timeline_id;
    begin
      try
        match add_title title timeline_id with
        | Ok _ ->
          [%pgsql dbh
            "INSERT INTO timeline_ids_(id_, users_, public_) VALUES ($timeline_id, $users, false)";];
          [%pgsql dbh "UPDATE users_ SET timelines_ = array_append(timelines_, $timeline_id) \
                       WHERE email_=$email"];
          last_update_timeline timeline_id (Some (CalendarLib.Calendar.Date.today ()));
          Ok timeline_id
        | Error e -> Error e
      with e -> Error (Printexc.to_string e)
    end
  | None -> Error ("User " ^ email ^ " does not exist")  

let create_public_timeline (title : title) (timeline_id : string) =
    let timeline_id = String.map (function ' ' -> '-' | c -> c) timeline_id in
    let timeline_id = check_unique_id Reader.timeline_exists timeline_id in
    let users = [] in
    Format.eprintf "Timeline id after check: %s@." timeline_id;
    try
      match add_title title timeline_id with
      | Ok _ ->
        [%pgsql dbh
          "INSERT INTO timeline_ids_(id_, users_, public_) VALUES ($timeline_id, $users, true)"];
        last_update_timeline timeline_id (Some (CalendarLib.Calendar.Date.today ()));
        Ok timeline_id
      | Error e -> Error e
      with e -> Error (Printexc.to_string e)

let allow_user_to_timeline (email : string) (timeline : string) =
  if Reader.timeline_exists timeline then
    match Reader.user_exists email with
    | Some _ ->
      let tlist = Reader.user_timelines email in
      if List.mem timeline tlist then
        Ok ()
      else
        let () = 
          [%pgsql dbh "UPDATE users_ SET timelines_ = array_append(timelines_, $timeline) \
                      WHERE email_=$email"];
          [%pgsql dbh "UPDATE timeline_ids_ SET users_ = array_append(users_, $email) \
                      WHERE id_=$timeline"];
        in Ok ()
    | None -> Error "User does not exist!"
  else Error "Timeine does not exist."

let register_user email pwdhash =
  match Reader.user_exists email with
  | Some _ ->
    Error ("User " ^ email ^ " already exists")
  | None -> begin
      let () =
        [%pgsql dbh "INSERT INTO users_(email_, name_, pwhash_) VALUES ($email, $email, '')"]
      in (* Now we get the id of the user *)
      update_pwd email pwdhash
    end

let remove_timeline tid =
  if Reader.timeline_exists tid then begin
    [%pgsql dbh "UPDATE users_ SET timelines_=array_remove(timelines_, $tid)"];
    [%pgsql dbh "DELETE FROM timeline_ids_ WHERE id_ = $tid"];
    [%pgsql dbh "DELETE FROM events_ WHERE timeline_id_ = $tid"];
    Ok ()
  end
  else
    Error "Timeline does not exist"

let remove_user email =
  match Reader.user_exists email with
  | Some i -> begin
    let () = Reader.Login.remove_session i in
    let user_timelines = Reader.user_timelines email in
    let () =
      [%pgsql dbh "UPDATE timeline_ids_ SET users_=array_remove(users_, $email)"];
      [%pgsql dbh "DELETE FROM users_ WHERE email_ = $email"] in
    (* If a timeline owned by the deleted account has no more user, it is deleted *)
    let rec remove_unused_timelines = function
    | [] -> Ok ()
    | tid :: tl ->
      match Reader.timeline_users tid with
      | [] -> begin
        match remove_timeline tid with
        | Ok () -> remove_unused_timelines tl
        | e -> e
      end
      | _ -> remove_unused_timelines tl 
    in 
    remove_unused_timelines user_timelines
    end
  | None -> Error "User does not exist"
