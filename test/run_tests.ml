(*
   Run all the OCaml test suites defined in the project.
*)

let test_suites : unit Alcotest.test list = [ "Sub1.A", Test_markdown_helper.tests ]
let () = Alcotest.run "proj" test_suites
