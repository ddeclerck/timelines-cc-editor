
(* Some rules:
   * Names that we introduce should end with '_' (it is a standard SQL rule);
   * Use EzPG.Mtimes to add row_created_ and row_modified_ columns in a table;
*)

let default_database = Config.database

let sql_downgrade_1_to_0 = [
  {| DROP TABLE sessions_; |};
  {| DROP TABLE users_; |};
]

let sql_upgrade_0_to_1 =
  [
    {| ALTER ROLE SESSION_USER SET search_path TO db,public|};
    {| CREATE TABLE users_ (
      id_     SERIAL PRIMARY KEY NOT NULL,
      email_  VARCHAR(100) UNIQUE NOT NULL,
      name_   VARCHAR(100) NOT NULL,
      pwhash_ BYTEA NOT NULL
      )|};
    {| CREATE TABLE sessions_ (
      user_id_   integer REFERENCES users_(id_) PRIMARY KEY NOT NULL,
      cookie_    VARCHAR NOT NULL)|};
  ]


let sql_downgrade_2_to_1 = [
  {| DROP TABLE events_ |}
]
let sql_upgrade_1_to_2 = [
  {| CREATE TABLE events_ (
    id_           SERIAL PRIMARY KEY NOT NULL,
    start_date_   DATE,
    end_date_     DATE,
    headline_     TEXT NOT NULL,
    text_         TEXT NOT NULL,
    media_        TEXT,
    group_        VARCHAR(100),
    confidential_ BOOLEAN NOT NULL,
    ponderation_  INT NOT NULL
    )|};
]

let sql_downgrade_3_to_2 = [
  {| DROP TABLE groups_ |}
]

let sql_upgrade_2_to_3 =  [
  {| CREATE TABLE groups_ (
     group_ VARCHAR(100) PRIMARY KEY NOT NULL
  )|}
]

let sql_downgrade_4_to_3 = [
  {| ALTER TABLE events_ DROP COLUMN unique_id_ |}
]

let sql_upgrade_3_to_4 =  [
  {| ALTER TABLE events_ ADD COLUMN unique_id_ VARCHAR UNIQUE NOT NULL |}
]

let sql_downgrade_5_to_4 = [
  {| ALTER TABLE events_ DROP COLUMN last_update_ |}
]

let sql_upgrade_4_to_5 =  [
  {| ALTER TABLE events_ ADD COLUMN last_update_ DATE |}
]

let sql_downgrade_6_to_5 = [
  {| ALTER TABLE events_ DROP COLUMN tags_ |}
]

let sql_upgrade_5_to_6 =  [
  {| ALTER TABLE events_ ADD COLUMN tags_ VARCHAR[] |}
]

let sql_downgrade_7_to_6 = [
  {| ALTER TABLE events_ DROP COLUMN timeline_id_ |};
  {| ALTER TABLE events_ DROP COLUMN is_title_ |};
  {| ALTER TABLE users_  DROP COLUMN timelines_   |};
  {| DROP TABLE timeline_ids_ |};
  {| CREATE TABLE groups_ (
     group_ VARCHAR(100) PRIMARY KEY NOT NULL
  )|};
]

let sql_upgrade_6_to_7 =  [
  {| ALTER TABLE events_ ADD COLUMN timeline_id_ VARCHAR NOT NULL |};
  {| ALTER TABLE events_ ADD COLUMN is_title_ BOOLEAN NOT NULL |};
  {| ALTER TABLE users_  ADD COLUMN timelines_ VARCHAR[] |};
  {| CREATE TABLE timeline_ids_ (
     id_ VARCHAR PRIMARY KEY NOT NULL,
     users_ VARCHAR[]
  )|};
  {| DROP TABLE groups_ |};
]



let ( upgrades, downgrades ) =
  let rev_versions = ref [] in
  let versions = List.mapi (fun i (upgrade, downgrade) ->
      rev_versions := (i+1, downgrade) :: !rev_versions;
      i,
      fun (dbh : unit PGOCaml.t) version ->
        EzPG.upgrade ~dbh ~version ~downgrade upgrade)
      [
        sql_upgrade_0_to_1, sql_downgrade_1_to_0;
        sql_upgrade_1_to_2, sql_downgrade_2_to_1;
        sql_upgrade_2_to_3, sql_downgrade_3_to_2;
        sql_upgrade_3_to_4, sql_downgrade_4_to_3;
        sql_upgrade_4_to_5, sql_downgrade_5_to_4;
        sql_upgrade_5_to_6, sql_downgrade_6_to_5;
        sql_upgrade_6_to_7, sql_downgrade_7_to_6;
      ]
  in
  (versions, !rev_versions)
