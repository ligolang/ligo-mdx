(*
   Inspect the first command-line argument (Sys.argv.(1))
   and determine which subcommand to execute, calling
   a function from our library accordingly.
*)

open Printf
(*
   You can do anything you want.
   You may want to use Arg.parse_argv to read the remaining
   command-line arguments.
*)

let run argv_offset =
  if Array.length (Core.Sys.get_argv ()) <= argv_offset
  then (
    print_string "run <directory path> <ligo executable path>";
    exit 1);
  let directory = (Core.Sys.get_argv ()).(2) in
  let ligo_executable = (Core.Sys.get_argv ()).(3) in
  let snippets = Markdown_helper.parse_markdowns directory in
  let report = Compilation_helper.compile_snippets_map ligo_executable snippets in
  exit (Common.check_report_for_errors report)


(* Add your own subcommands as needed. *)
let subcommands = [ "run", run ]

let help () =
  let subcommand_names =
    String.concat "\n" (List.map (fun (name, _f) -> "  " ^ name) subcommands)
  in
  let usage_msg =
    sprintf
      "Usage: %s SUBCOMMAND [ARGS]\n\
       where SUBCOMMAND is one of:\n\
       %s\n\n\
       For help on a specific subcommand, try:\n\
       %s SUBCOMMAND --help\n"
      Sys.argv.(0)
      subcommand_names
      Sys.argv.(0)
  in
  eprintf "%s%!" usage_msg


let dispatch_subcommand () =
  assert (Array.length Sys.argv > 1);
  match Sys.argv.(1) with
  | "help" | "-h" | "-help" | "--help" -> help ()
  | subcmd ->
    let argv_offset = 3 in
    let action =
      try List.assoc subcmd subcommands with
      | Not_found ->
        eprintf "Invalid subcommand: %s\n" subcmd;
        help ();
        exit 1
    in
    action argv_offset


let main () =
  let len = Array.length Sys.argv in
  if len <= 1
  then (
    help ();
    exit 1)
  else dispatch_subcommand ()


(* Run now. *)
let () = main ()
