open Data_types

let finish () = Lwt.return (Ok ())

let error s = Lwt.return (Error (Xhr_lwt.Str_err ("Add new event action failed: " ^ s)))

let timeline_id_from_args = List.assoc_opt "timeline"

let login log pwd =
  ignore @@
  Request.login log pwd (function
      | Some auth_data -> begin
          Js_utils.log "Login OK!@.";
          Ui_utils.auth_session log auth_data;
          Js_utils.reload ();
          finish ()
        end
      | None -> begin
          Js_utils.alert "Wrong login/password@.";
          error ("Wrong login")
        end)

let logout () =
  ignore @@
  Request.logout
    (fun _ ->
       Ui_utils.logout_session ();
       Js_utils.reload ();
       finish ())

let register_account log pwd =
  ignore @@
  Request.register_user log pwd (fun _ ->
      Js_utils.log "Registering account@.";
      ignore @@ !Dispatcher.dispatch ~path:"admin" ~args:[];
      finish ()
    )

let add_action event =
  match Utils.metaevent_to_event event with
  | None ->
    Lwt.return (Error (Xhr_lwt.Str_err "Start date is missing"));
  | Some event ->
    Js_utils.log "Adding event %a" Utils.pp_event event;
    let args = Ui_utils.get_args () in
    match timeline_id_from_args args with
    | None ->
      Lwt.return (Error (Xhr_lwt.Str_err ("Add new event action failed: no timeline specified")))
    | Some timeline ->
      Request.add_event ~args timeline event
        (function
          | Ok () -> !Dispatcher.dispatch ~path:"home" ~args:[]
          | Error s -> Lwt.return (Error (Xhr_lwt.Str_err ("Add new event action failed: " ^ s)))
        )

let remove_action args i =
  let c = Js_utils.confirm "Are you sure you want to remove this event ? This is irreversible." in
  if c then
    ignore @@
    Request.remove_event
      ~args
      i
      (fun _ ->
         ignore @@ !Dispatcher.dispatch ~path:"admin" ~args:[];
         finish ())
  else ()

let rec update_action
    (compare :
       int -> string list ->
     date option meta_event option -> date option meta_event -> 'a Ocp_js.elt)
    (i : int)
    (categories : string list)
    (old_event : title)
    (new_event : title)
    cont =
  Js_utils.log "Update... %a -> %a" Utils.pp_title old_event Utils.pp_title new_event;
  begin
    Request.update_event i ~old_event ~new_event (
      function
      | Success -> cont ()
      | Failed s -> begin
          Js_utils.log "Update failed: %s" s;
          Lwt.return
            (Error (Xhr_lwt.Str_err ("Update event action failed: " ^ s)))
        end
      | Modified event_opt ->
        Js_utils.log "Event has been modified while editing";
        Dispatcher.set_in_main_page [
          compare
            i
            categories
            event_opt
            new_event
        ];
        finish ()
    )
  end

let export_database args =
  match timeline_id_from_args args with
  | None ->
    Lwt.return (Error (Xhr_lwt.Str_err ("Export database failed: no timeline specified")))
  | Some timeline ->
    Request.events ~args timeline (fun events ->
      Request.title ~args timeline (fun title ->
        let sep = "," in
        let title =
          match title with
          | None -> sep
          | Some title -> Data_encoding.title_to_csv ~sep title in
        let header = Data_encoding.header ~sep in
        let events =
          List.fold_left
            (fun acc event ->
               acc ^ Data_encoding.event_to_csv ~sep event ^ ";\n")
            ""
            (snd @@ List.split events) in
        let str =  (title ^ ";\n" ^ header ^ ";\n" ^ events) in
        Ui_utils.download "database.csv" str; finish ()
          )
      )
