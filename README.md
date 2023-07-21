# ligo-mdx

## Goal
The project goal is to test ligo code contained in markdown file. For example it'll help to test your documentation or training through a CICD.

It'll generate a report file named report.html 

## Try it

You can try now it by running :

```zsh
make init && make && ./_build/default/src/bin/main.exe run ./examples/docs/taco-shop/tezos-taco-shop-smart-contract.md ligo
```

It'll generate a report.html file.
## How to use

The script is able to read 3 keywords in header and the declared language.

Language can be jsligo, cameligo or zsh (in case of shell script)

- group : used to regroup multiple snippets, it'll also be used as a nameFile
- compilation : The way to test your code
  - Interpret : Use `ligo interpret` to test your code
  - Contract : Use `ligo compile contract` to test your code
  - Test : Use `ligo run test` to test your code
  - Command : Use directly command inside snippet
  - None  : Skip this snippet
- syntax: If the language does not match with the syntax, you can override the syntax with syntax attribute
  - cameligo 
  - jsligo
- interpretation-type : interpretation-type=declaration
  - Expression : Default value, nothing happen
  - Declaration : When the snippet is interpreted, it'll be transformed to an expression, surrounding the code with `module ASFJNISFX = struct` and `end in ()`

## Examples

### Group snippets 

(ommit \ which has been introduced to be able to insert markdown code)
```markdown

```jsligo group=taco-shop 
type taco_supply is record [current_stock : nat; max_price : tez]

type taco_shop_storage is map (nat, taco_supply)

type return_ = [list <operation>, taco_shop_storage];

\```

blabla 

```jsligo group=taco-shop compilation=contract
@entry
let buy_taco = (taco_kind_index: nat, taco_shop_storage: taco_shop_storage): return_ => {
  /* Retrieve the taco_kind from the contracts storage or fail */
  let taco_kind =
    match (Map.find_opt (taco_kind_index, taco_shop_storage), {
      Some: (k:taco_supply) => k,
      None: (_:unit) => (failwith ("Unknown kind of taco") as taco_supply)
    }) ;
}
\```
```

Will regroup and test snippets by running `ligo compile contract tmp/taco-shop.jsligo` on a temp file which is defined by 
```jsligo
type taco_supply is record [current_stock : nat; max_price : tez]

type taco_shop_storage is map (nat, taco_supply)

type return_ = [list <operation>, taco_shop_storage];

@entry
let buy_taco = (taco_kind_index: nat, taco_shop_storage: taco_shop_storage): return_ => {
  /* Retrieve the taco_kind from the contracts storage or fail */
  let taco_kind =
    match (Map.find_opt (taco_kind_index, taco_shop_storage), {
      Some: (k:taco_supply) => k,
      None: (_:unit) => (failwith ("Unknown kind of taco") as taco_supply)
    }) ;
}
```

:warning: This is file scopped, groups cannot be shared between files

### Branch onto group

It's possible to branch on snippet, for example if you want to define step by step a function :

```markdown

```jsligo group=taco-shop;taco-shop2 
type taco_supply is record [current_stock : nat; max_price : tez]

type taco_shop_storage is map (nat, taco_supply)

type return_ = [list <operation>, taco_shop_storage];

\```

blabla 


```jsligo group=taco-shop compilation=contract
@entry
let buy_taco = (taco_kind_index: nat, taco_shop_storage: taco_shop_storage): return_ => {
  [], taco_shop_storage
}
\```

blablablabla

```jsligo group=taco-shop2 compilation=contract
@entry
let buy_taco = (taco_kind_index: nat, taco_shop_storage: taco_shop_storage): return_ => {
  /* Retrieve the taco_kind from the contracts storage or fail */
  let taco_kind =
    match (Map.find_opt (taco_kind_index, taco_shop_storage), {
      Some: (k:taco_supply) => k,
      None: (_:unit) => (failwith ("Unknown kind of taco") as taco_supply)
    }) ;
}
\```
```

Will create two snippets named `taco-shop` and `taco-shop2` and test them using `ligo compile contract`

### Use shell command onto a snippet
Some time your documentation contains a bash command and you want to test it too, it's possible :

```
```jsligo group=contract/taco-shop
<your contract code here>
\```

blabla

```zsh group=contract/taco-shop compilation=command
ligo run dry-run contract/taco-shop.jsligo 4 3 --entry-point main
\```
```

### Build snippet with invisible code

Some time, your code is not compilable itself. You can add some code between `<!-- -->` and tag it with the correct group. For example : 
```
<!-- 
```cameligo group=invisible-snippet
type taco_supply = { current_stock : nat ; max_price : tez }

type taco_shop_storage = (nat, taco_supply) map
\```
-->

```cameligo group=invisible-snippet compilation=interpret interpretation-type=declaration
type return = operation list * taco_shop_storage
\```
``` 
