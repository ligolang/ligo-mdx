open Common

let get_all_md_files directory =
  let ic = Unix.open_process_in ("find " ^ directory ^ " -iname \"*.md\"") in
  let files = ref [] in
  (try
     while true do
       match In_channel.input_line ic with
       | Some line -> files := line :: !files
       | None -> raise End_of_file
     done
   with
   | End_of_file -> In_channel.close ic);
  List.rev !files


open Core

let arg_to_string x =
  match x with
  | Md.Field s -> s
  | Md.NameValue (k, v) -> Format.asprintf "%s=%s" k v


let _print_code_block (block : Md.block) =
  Format.printf "Header: %s\n" (Option.value ~default:"" block.header);
  Format.printf "Arguments:\n";
  List.iter ~f:(fun arg -> Format.printf "- %s\n" (arg_to_string arg)) block.arguments;
  Format.printf "Contents:\n";
  List.iter ~f:(fun content -> Format.printf "- %s\n" content) block.contents;
  Format.printf "-----------------------\n"


let _print_code_blocks (_code_blocks : Md.block list) =
  List.iter ~f:_print_code_block _code_blocks


let sort_md_args (args_list : Md.arg list) : Md.arg list =
  let compare_args arg1 arg2 =
    match arg1, arg2 with
    | Md.Field s1, Md.Field s2 -> String.compare s1 s2
    | Md.Field _, Md.NameValue _ -> -1
    | Md.NameValue _, Md.Field _ -> 1
    | Md.NameValue (key1, _), Md.NameValue (key2, _) -> String.compare key1 key2
  in
  List.sort ~compare:compare_args args_list


let generate_snippetsmap_entry
  grp_names
  syntax
  compilation
  contents
  grp_map
  interpretation_type
  : snippetsmap
  =
  let groups = String.split_on_chars ~on:[ ';' ] grp_names in
  List.fold_left groups ~init:grp_map ~f:(fun grp_map name ->
    SnippetsGroup.update
      (syntax, name)
      (fun arg_content ->
        match arg_content with
        | Some (ct, _, _) ->
          Some
            ( String.concat ~sep:"\n" (ct :: contents)
            , compilation_from_string compilation
            , interpretation_type_from_string interpretation_type )
        | _ ->
          Some
            ( String.concat ~sep:"\n" contents
            , compilation_from_string compilation
            , interpretation_type_from_string interpretation_type ))
      grp_map)


let add_default_arg arg_key arg_default (args_list : Md.arg list) : Md.arg list =
  let imports_arg_exists =
    List.exists
      ~f:(fun arg ->
        match arg with
        | NameValue (arg, _) -> String.equal arg arg_key
        | _ -> false)
      args_list
  in
  if imports_arg_exists
  then args_list
  else Md.NameValue (arg_key, arg_default) :: args_list


let get_groups md_file : snippetsmap option =
  try
    let channel = In_channel.create md_file in
    let lexbuf = Lexing.from_channel channel in
    let code_blocks = Md.token lexbuf in
    let aux : snippetsmap -> Md.block -> snippetsmap =
     fun grp_map el ->
      (* _print_code_block el; *)
      match el.header with
      | Some ("cameligo" as s)
      | Some ("jsligo" as s)
      | Some ("zsh" as s)
      | Some ("bash" as s) ->
        let () =
          (*sanity check*)
          List.iter
            ~f:(fun arg ->
              match arg with
              | Md.NameValue ("syntax", _)
              | Md.NameValue ("group", _)
              | Md.NameValue ("interpretation-type", _)
              | Md.NameValue ("compilation", _) -> ()
              | Md.Field _ | Md.NameValue (_, _) ->
                failwith
                  (Format.asprintf
                     "unknown argument '%s' in code block at line %d of file %s"
                     (arg_to_string arg)
                     el.line
                     el.file))
            el.arguments
        in
        let args = add_default_arg "compilation" "interpret" el.arguments in
        let args = add_default_arg "interpretation-type" "expression" args in
        let args = add_default_arg "group" "ungrouped" args in
        let args = add_default_arg "syntax" "" args in
        let args = sort_md_args args in
        (match args with
         (* Every possibilities with group syntax and compilation*)
         | [ Md.NameValue ("compilation", compilation)
           ; Md.NameValue ("group", names)
           ; Md.NameValue ("interpretation-type", interpretation_type)
           ; Md.NameValue ("syntax", syntax)
           ] ->
           let syntax = if String.equal "" syntax then syntax else syntax ^ "." in
           generate_snippetsmap_entry
             names
             (syntax ^ s)
             compilation
             el.contents
             grp_map
             interpretation_type
         | args ->
           let () =
             List.iter
               ~f:(function
                 | Md.NameValue (x, y) -> Format.printf "NamedValue %s %s\n" x y
                 | Md.Field x -> Format.printf "%s\n" x)
               args
           in
           failwith "Block arguments (above) not supported")
      | None | Some _ -> grp_map
    in
    Some (List.fold_left ~f:aux ~init:SnippetsGroup.empty code_blocks)
  with
  | exn ->
    Printf.eprintf "Exception in get_groups: %s\n" (Exn.to_string exn);
    None


let parse_markdown file_path =
  Format.printf "=== File: %s ===\n" file_path;
  match get_groups file_path with
  | Some snippets ->
    Format.printf "\n";
    Some snippets
  | None ->
    Printf.printf "Due to error, ignoring file: %s\n" file_path;
    None


let parse_markdowns directory : snippetsmap list =
  let md_filepaths = get_all_md_files directory in
  List.fold_left
    ~f:(fun acc file_path ->
      match parse_markdown file_path with
      | Some snippets -> snippets :: acc
      | None -> acc)
    ~init:[]
    md_filepaths
