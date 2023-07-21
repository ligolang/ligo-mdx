type syntax = string
type group_name = string
type lang = string
type snippet_content = string
type filepath = string
type imports_groups = string list

(* Expression must be default value *)
type interpretation_type =
  | Declaration
  | Expression

(* Interpret must be default value, None to skip compilation *)
type compilation =
  | Interpret
  | Contract
  | Test
  | Command
  | None

type execution_result = int
type execution_result_details = string

let interpretation_type_to_string compilation =
  match compilation with
  | Declaration -> "Declaration"
  | Expression -> "Expression"


let interpretation_type_from_string s =
  match String.lowercase_ascii s with
  | "declaration" -> Declaration
  | "expression" -> Expression
  | _ -> failwith "unrecognized interpretation_type type"


let compilation_to_string compilation =
  match compilation with
  | Interpret -> "Interpret"
  | Contract -> "Contract"
  | Test -> "Test"
  | Command -> "Command"
  | None -> "None"


let is_valid_extension extension =
  List.exists (fun el -> String.equal extension el) [ "mligo"; "jsligo"; "sh" ]


let extension_from_syntax syntax =
  match syntax with
  | "cameligo" -> ".mligo"
  | "jsligo" -> ".jsligo"
  | "cameligo.bash" | "cameligo.zsh" -> ".mligo.sh"
  | "jsligo.zsh" | "jsligo.bash" -> ".jsligo.sh"
  | _ -> "." ^ syntax


let compilation_from_string s =
  match String.lowercase_ascii s with
  | "interpret" -> Interpret
  | "contract" -> Contract
  | "test" -> Test
  | "command" -> Command
  | "none" -> None
  | _ -> failwith "unrecognized compilation type"


module SnippetsGroup = Map.Make (struct
  type t = syntax * group_name

  let compare a b = compare a b
end)

type snippetsmap = (snippet_content * compilation * interpretation_type) SnippetsGroup.t

type snippets_result_map =
  (snippet_content * compilation * execution_result * execution_result_details)
  SnippetsGroup.t

type report_list = snippets_result_map list

open Core

let _print_group key (_syntax, content) =
  Format.printf "Group: %s - %s\n" (fst key) (snd key);
  Format.printf "Content:\n%s\n" content;
  Format.printf "-----------------------\n"


let print_snippetsmap (snippets : snippetsmap) : unit =
  SnippetsGroup.iter
    (fun (syntax, group_name) (content, compilation, interpretation_type) ->
      Format.printf "Syntax: %s\n" syntax;
      Format.printf "Group: %s\n" group_name;
      Format.printf "Content:\n%s\n" content;
      Format.printf "Compilation: %s\n" (compilation_to_string compilation);
      Format.printf
        "Interpretation_type:\n%s\n"
        (interpretation_type_to_string interpretation_type);
      Format.printf "*******************\n")
    snippets


let _print_report_list (report : report_list) : unit =
  List.iter
    ~f:(fun snippets ->
      SnippetsGroup.iter
        (fun (syntax, group_name)
             (content, compilation, execution_result, execution_result_details) ->
          Format.printf "Syntax: %s\n" syntax;
          Format.printf "Group: %s\n" group_name;
          Format.printf "Content:\n%s\n" content;
          Format.printf
            "Compilation: %s\n"
            (match compilation with
             | Interpret -> "Interpret"
             | Contract -> "Contract"
             | Test -> "Test"
             | Command -> "Command"
             | None -> "None");
          Format.printf "Execution Result: %d\n" execution_result;
          Format.printf "Execution Result Details: %s\n" execution_result_details;
          Format.printf "-----------------------\n")
        snippets)
    report


let contains s1 s2 =
  let re = Str.regexp_string s2 in
  try
    ignore (Str.search_forward re s1 0);
    true
  with
  | _ -> false


let get_result_color execution_result execution_result_details =
  if execution_result <> 0
  then "red" (* ligne rouge si le résultat n'est pas 0 *)
  else if contains execution_result_details "warning"
  then "orange" (* ligne orange si "warning" est présent dans les détails du résultat *)
  else "black" (* ligne noire par défaut *)


let write_report_list_to_html_file (report : report_list) (filename : string) : unit =
  let oc = Out_channel.create filename in
  Out_channel.output_string oc "<style>\n";
  Out_channel.output_string oc "table {\n";
  Out_channel.output_string oc "  border-collapse: collapse;\n";
  Out_channel.output_string oc "  width: 100%;\n";
  Out_channel.output_string oc "}\n";
  Out_channel.output_string oc "th, td {\n";
  Out_channel.output_string oc "  border: 1px solid black;\n";
  Out_channel.output_string oc "  padding: 8px;\n";
  Out_channel.output_string oc "}\n";
  Out_channel.output_string oc "</style>\n";
  Out_channel.output_string oc "<table>\n";
  List.iter
    ~f:(fun snippets ->
      SnippetsGroup.iter
        (fun (syntax, group_name)
             (content, compilation, execution_result, execution_result_details) ->
          let result_color =
            if execution_result <> 0
            then "red" (* ligne rouge si le résultat n'est pas 0 *)
            else if String.is_substring execution_result_details ~substring:"warning"
            then
              "orange"
              (* ligne orange si "warning" est présent dans les détails du résultat *)
            else "black" (* ligne noire par défaut *)
          in
          Printf.fprintf oc "<tr style=\"color: %s\">\n" result_color;
          Printf.fprintf oc "<td>Syntax: %s</td>\n" syntax;
          Printf.fprintf oc "<td>Group: %s</td>\n" group_name;
          Printf.fprintf oc "<td>Content:</td>\n";
          Printf.fprintf
            oc
            "<td><details><summary>Click to expand</summary><pre>%s</pre></details></td>\n"
            content;
          Printf.fprintf
            oc
            "<td>Compilation: %s</td>\n"
            (match compilation with
             | Interpret -> "Interpret"
             | Contract -> "Contract"
             | Test -> "Test"
             | Command -> "Command"
             | None -> "None");
          Printf.fprintf oc "<td>Execution Result: %d</td>\n" execution_result;
          Printf.fprintf oc "<td>Execution Result Details:</td>\n";
          Printf.fprintf
            oc
            "<td><details><summary>Click to expand</summary><pre>%s</pre></details></td>\n"
            execution_result_details;
          Printf.fprintf oc "</tr>\n")
        snippets)
    report;
  Out_channel.output_string oc "</table>\n";
  Out_channel.close oc


let check_report_for_errors (report : report_list) : int =
  let has_errors =
    Caml.List.exists
      (fun snippets ->
        SnippetsGroup.exists
          (fun _ (_, _, execution_result, _) -> execution_result <> 0)
          snippets)
      report
  in
  if has_errors then 1 else 0
