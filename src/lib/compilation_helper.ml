open Common

type extension = string

let remove_directory path =
  let command = "rm -rf " ^ path in
  match Unix.system command with
  | Unix.WEXITED 0 -> ()
  | _ -> failwith "Failed to remove directory"


let inject_tmp_filepath_to_file (filepath_to_inject : string) (command : string) : string =
  let extension = Filename.extension filepath_to_inject in
  let pattern = Str.regexp (".*\\(\\ .*\\" ^ extension ^ "\\)") in
  if Str.string_match pattern command 0
  then
    (let matching_filepath = Str.matched_group 1 command in
     Str.global_replace (Str.regexp matching_filepath) (" " ^ filepath_to_inject) command)
    ^ " 2>&1"
  else command ^ " 2>&1"


let write_snippet_to_file (syntax, group_name) (content, _) : filepath =
  let extension =
    let splitted_filename = String.split_on_char '.' group_name in
    if is_valid_extension (List.nth splitted_filename (List.length splitted_filename - 1))
    then ""
    else extension_from_syntax syntax
  in
  let filepath = "tmp/" ^ group_name ^ extension in
  let folders_path =
    match List.rev (String.split_on_char '/' filepath) with
    | _head :: tail -> List.rev tail
    | _ -> failwith "filepath cannot be empty"
  in
  let _s =
    List.fold_left
      (fun acc folder ->
        let () =
          if not (Sys.file_exists (acc ^ folder)) then Unix.mkdir (acc ^ folder) 0o755
        in
        acc ^ folder ^ "/")
      ""
      folders_path
  in
  (* File need to be write to the correct place for include. This solution will not work if a file reference to a file which is referencing to another file*)
  Core.Out_channel.write_all filepath ~data:content;
  let filename =
    match List.rev (String.split_on_char '/' filepath) with
    | head :: _tail -> "tmp/" ^ head
    | _ -> failwith "filepath cannot be empty"
  in
  Core.Out_channel.write_all filename ~data:content;
  filename


let find_snippet_file_for_command_file group syntax : filepath option =
  let searched_extension =
    Str.global_replace (Str.regexp "\\.sh") "" (extension_from_syntax syntax)
  in
  let filename =
    match List.rev (String.split_on_char '/' group) with
    | head :: _tail -> head
    | _ -> failwith "filepath cannot be empty"
  in
  let regex = Str.regexp (filename ^ searched_extension ^ "$") in
  let matching_files = Array.to_list (Sys.readdir "tmp") in
  let filtered_files =
    List.filter (fun file -> Str.string_match regex file 0) matching_files
  in
  let head = List.nth_opt filtered_files 0 in
  match head with
  | Some filename -> Some ("tmp/" ^ filename)
  | None -> None


let execute_command command : int * string =
  Printf.printf "\nExecute %s" command;
  let ic = Unix.open_process_in command in
  let all_output = Buffer.create 1024 in
  let exit_code =
    try
      while true do
        let line = input_line ic in
        Buffer.add_string all_output line;
        Buffer.add_char all_output '\n'
      done;
      0
    with
    | End_of_file ->
      let status = Unix.close_process_in ic in
      (match status with
       | Unix.WEXITED code | Unix.WSIGNALED code | Unix.WSTOPPED code -> code)
  in
  exit_code, Buffer.contents all_output


let retrieve_commands_from_file (filename : string) : string list =
  let commands = ref [] in
  let ic = open_in filename in
  try
    while true do
      let line = input_line ic in
      if String.length line > 0 && line.[0] <> '#' then commands := line :: !commands
    done;
    []
  with
  | End_of_file ->
    close_in ic;
    List.rev !commands


let compile_snippets_map ligo_executable (snippets_list : snippetsmap list) : report_list =
  let () = if not (Sys.file_exists "tmp") then Unix.mkdir "tmp" 0o755 in
  let result =
    List.fold_left
      (fun acc snippets ->
        SnippetsGroup.fold
          (fun (syntax, group_name) (content, compilation, interpretation_type) acc ->
            let filename =
              write_snippet_to_file (syntax, group_name) (content, compilation)
            in
            let return_code, details =
              match compilation with
              | Interpret ->
                (match interpretation_type with
                 | Declaration ->
                   (* In this case, we want to transform the declaration into an expression to be interpretable *)
                   execute_command
                     (ligo_executable
                      ^ " run interpret  --syntax "
                      ^ syntax
                      ^ " \"module ASFJNISFX = struct $(cat "
                      ^ filename
                      ^ ") end in () \" 2>&1")
                 | Expression ->
                   execute_command
                     (ligo_executable
                      ^ " run interpret  --syntax "
                      ^ syntax
                      ^ " \"$(cat "
                      ^ filename
                      ^ ")\" 2>&1"))
              | Contract ->
                execute_command
                  (ligo_executable ^ " compile contract " ^ filename ^ " 2>&1")
              | Test ->
                execute_command (ligo_executable ^ " run test " ^ filename ^ " 2>&1")
              | Command ->
                let commands = retrieve_commands_from_file filename in
                List.fold_left
                  (fun (output_codes, output_logs_acc) command ->
                    let output_code, output_logs =
                      match find_snippet_file_for_command_file group_name syntax with
                      | Some snippet_file ->
                        execute_command (inject_tmp_filepath_to_file snippet_file command)
                      | None -> execute_command (command ^ " 2>&1")
                    in
                    ( output_codes + output_code
                    , output_logs_acc ^ "\n" ^ command ^ ":\n" ^ output_logs ))
                  (0, "")
                  commands
              | None -> 0, filename
            in
            let snippets_result =
              SnippetsGroup.singleton
                (syntax, group_name)
                (content, compilation, return_code, details)
            in
            snippets_result :: acc)
          snippets
          acc)
      []
      snippets_list
  in
  write_report_list_to_html_file result "report.html";
  remove_directory "tmp";
  result
