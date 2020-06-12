open Data_types
open Ui_utils

module Js = Js_of_ocaml.Js


class type categoryFilter = object
  method id : int Js.readonly_prop
  method catName : Js.js_string Js.t Js.readonly_prop
  method catId   : Js.js_string Js.t Js.readonly_prop
  method checked : bool Js.t Js.prop
end

class type data = object
    method exportButton : Js.js_string Js.t Js.readonly_prop
    method adminButton  : Js.js_string Js.t Js.readonly_prop

    method categoryHeader      : Js.js_string Js.t Js.readonly_prop
    method otherFiltersHeader  : Js.js_string Js.t Js.readonly_prop
    method panelHeader         : Js.js_string Js.t Js.readonly_prop
    method minPonderationLabel : Js.js_string Js.t Js.readonly_prop
    method maxPonderationLabel : Js.js_string Js.t Js.readonly_prop

    method ponderationHelp : Js.js_string Js.t Js.readonly_prop

    method filterButtonText : Js.js_string Js.t Js.readonly_prop
    
    method minPonderation : int Js.prop
    method maxPonderation : int Js.prop

    method categories : categoryFilter Js.t Js.js_array Js.t Js.prop

    method startDateFormTitle    : Js.js_string Js.t Js.readonly_prop
    method endDateFormTitle      : Js.js_string Js.t Js.readonly_prop
    method mediaFormTitle        : Js.js_string Js.t Js.readonly_prop
    method headlineFormTitle     : Js.js_string Js.t Js.readonly_prop
    method uniqueIdFormTitle     : Js.js_string Js.t Js.readonly_prop
    method categoriesFormTitle   : Js.js_string Js.t Js.readonly_prop
    method textFormTitle         : Js.js_string Js.t Js.readonly_prop
    method tagsFormTitle         : Js.js_string Js.t Js.readonly_prop
    method ponderationFormTitle  : Js.js_string Js.t Js.readonly_prop
    method confidentialFormTitle : Js.js_string Js.t Js.readonly_prop
    method backButton            : Js.js_string Js.t Js.readonly_prop
        
    method startDateFormValue    : Js.js_string Js.t Js.prop
    method endDateFormValue      : Js.js_string Js.t Js.prop
    method mediaFormValue        : Js.js_string Js.t Js.prop
    method headlineFormValue     : Js.js_string Js.t Js.prop
    method uniqueIdFormValue     : Js.js_string Js.t Js.prop
    method categoriesFormValue   : Js.js_string Js.t Js.prop
    method textFormValue         : Js.js_string Js.t Js.prop
    method tagsFormValue         : Js.js_string Js.t Js.prop
    method ponderationFormValue  : int Js.prop
    method confidentialFormValue : bool Js.t Js.prop
        
    method addingNewEvent : bool Js.t Js.prop
    (* Is the form here to add (true) or edit (false) an event *)

    method updateEventButton     : Js.js_string Js.t Js.prop
    method formName              : Js.js_string Js.t Js.prop

    method currentEvent          : int Js.prop
    (* Id of the current event *)

    method currentTimeline : Js.js_string Js.t Js.readonly_prop
    (* Name of the current timeline *)
  end

module PageContent = struct
  type nonrec data = data
  let id = "page-content"
end

module Vue = Vue_js.Make (PageContent)

let page_vue (timeline_name : string) (categories : (string * bool) list) : data Js.t =
  let categories : categoryFilter Js.t Js.js_array Js.t =
    Js.array @@
    Array.of_list @@
    List.mapi
      (fun i (c, checked) ->
         object%js
           val id = i
           val catName = jss c
           val catId = jss (Ui_utils.trim c)
           val mutable checked = Js.bool checked
         end)
      categories
  in object%js
    val exportButton      = jss "Share timeline"
    val adminButton       = jss "Administration panel"

    val categoryHeader      = jss "Categories"
    val otherFiltersHeader  = jss "Extra filters"
    val panelHeader         = jss "Events"
    val minPonderationLabel = jss "Minimal Ponderation"
    val maxPonderationLabel = jss "Max Ponderation"
    val ponderationHelp     = jss "Select two values"
    val filterButtonText    = jss "Filter"

    val mutable minPonderation = 0
    val mutable maxPonderation = 100
    val mutable categories     = categories

    val startDateFormTitle    = jss "From"
    val endDateFormTitle      = jss "To"
    val mediaFormTitle        = jss "Media"
    val headlineFormTitle     = jss "Headline"
    val uniqueIdFormTitle     = jss "Unique"
    val categoriesFormTitle   = jss "Category"
    val textFormTitle         = jss "Description"
    val tagsFormTitle         = jss "Tags (separate with ',')"
    val ponderationFormTitle  = jss "Ponderation"
    val confidentialFormTitle = jss "Confidential"
    val backButton            = jss "Back"

    val mutable startDateFormValue    = jss ""
    val mutable endDateFormValue      = jss ""
    val mutable mediaFormValue        = jss ""
    val mutable headlineFormValue     = jss ""
    val mutable uniqueIdFormValue     = jss ""
    val mutable categoriesFormValue   = jss ""
    val mutable textFormValue         = jss ""
    val mutable tagsFormValue         = jss ""
    val mutable ponderationFormValue  = 0
    val mutable confidentialFormValue = Js.bool false

    val mutable addingNewEvent = Js.bool false
    
    val mutable formName          = jss "Add a new event"
    val mutable updateEventButton = jss "Add event"

    val mutable currentEvent = -1
    val currentTimeline = jss timeline_name
  end

let category_component () =
  let template =
    "<div>\n\
     <input \n\
       type='checkbox' \n\
       :id=category.catId\n\
       :value=category.catName \n\
       v-model=category.checked>\n\
     <label :for=category.catId>{{category.catName}}</label>\n\
     </div>" in
  let props = ["category"; "checkedCategories"] in
  Vue_js.component "cat" ~template ~props

type on_page =
  | No_timeline
  | Timeline of {
      name: string;
      title: (int * title) option;
      events: (int * event) list
    }

(* Methods of the view *)
let showForm (self : 'a) (adding : bool) : unit =
  Js_utils.Manip.addClass (Js_utils.find_component "navPanel") "visible";
  self##.addingNewEvent := (Js.bool adding);
  if adding then begin
    self##.formName := jss "Add a new event on the timeline";
    self##.updateEventButton := jss "Add new event"
  end else begin
    self##.formName := jss "Update the event";
    self##.updateEventButton := jss "Update event"
  end;
  ()

let hideForm self =
  Js_utils.Manip.removeClass (Js_utils.find_component "navPanel") "visible";
  self##.addingNewEvent := (Js.bool false)
  
let addEvent self adding : unit =
  let timeline = Js.to_string self##.currentTimeline in
  if timeline = "" then
    Js_utils.alert "Select a timeline before editing it."
  else begin
    let start_date = Utils.string_to_date @@ Js.to_string self##.startDateFormValue in
    let end_date   = Utils.string_to_date @@ Js.to_string self##.endDateFormValue   in
    let media      = Js.to_string self##.mediaFormValue     in
    let headline   = Js.to_string self##.headlineFormValue  in
    let text       = Js.to_string self##.textFormValue      in
    let unique_id  = Js.to_string self##.uniqueIdFormValue  in
    let group      = Js.to_string self##.categoriesFormValue in
    let tags       = Js.to_string self##.tagsFormValue in
    let ponderation = self##.ponderationFormValue in
    let confidential = Js.to_bool self##.confidentialFormValue in
    if adding then begin
      Js_utils.log "Adding event";
      let _l : 'a Lwt.t =
        Controller.add_event
          ~start_date
          ~end_date
          ~media
          ~headline
          ~text
          ~unique_id
          ~group
          ~ponderation
          ~confidential
          ~tags
          ~timeline
      in ()
    end
    else
      Js_utils.alert "Edition is not yet accessible"
  end

(* Timeline initializer *)
let display_timeline title events =  
  let timeline =
    let title =
      match title with
      | None -> None
      | Some (_, t) -> Some t in
    let events = List.map snd events in
    {Data_types.events; title} in
  let json = Json_encoding.construct (Data_encoding.timeline_encoding) timeline in
  let yoj  = Json_repr.to_yojson json in
  let str  = Yojson.Safe.to_string yoj in
  Js_utils.log "Json: %s" str;
  let () =
    Js_of_ocaml.Js.Unsafe.js_expr @@
    Format.asprintf
      "window.timeline = new TL.Timeline('home-timeline-embed',%s)"
      str in () (*
  Timeline.make "home-timeline-embed" str *)

let init
  ~(on_page: on_page)
  ~(categories : (string * bool) list) =

  (* First : displaying titles *)

  let name =
    match on_page with
    | Timeline {name; _} -> name
    | No_timeline -> "" in
  let data_js = page_vue name categories in
  
  (* Adding methods *)
  Vue.add_method1 "showForm" showForm;
  Vue.add_method0 "hideForm" hideForm;
  Vue.add_method1 "addEvent" addEvent;
  
  let _cat = category_component () in
  let _obj = Vue.init ~data_js () in

  (* Now displaying timeline *)

  let () =
    match on_page with
    | No_timeline -> Js_utils.alert "No timeline has been selected"
    | Timeline {title; events; name} ->
      match events with
      | [] -> Ui_utils.click (Js_utils.find_component "add-event-span")
      | _ -> display_timeline title events in
  ()
