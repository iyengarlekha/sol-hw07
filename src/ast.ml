(** {0} Abstract syntax for core calculus of MiniML *)

open Util

(** {1} Type definitions for representing ASTs *)
  
(** Variable names *)
type var = string
      
(** Inbuilt functions *)
type inbuilt_fun =
  | Not (* not *)
  | Fix (* fix (fixpoint operator) *)

(** Binary infix operators *)
type binop =
  | Mult  (* * *)
  | Div   (* / *)
  | Mod   (* mod *)
  | Plus  (* + *)
  | Minus (* - *)
  | Eq    (* = *)
  | Ne    (* <> *)
  | Lt    (* < *)
  | Gt    (* > *)
  | Le    (* <= *)
  | Ge    (* >= *)
  | And   (* && *)
  | Or    (* || *)

(** Terms *)
type term =
  | FunConst of inbuilt_fun * pos      (* f (inbuilt function) *)
  | IntConst of int * pos              (* i (int constant) *)
  | BoolConst of bool * pos            (* b (bool constant) *)
  | Var of var * pos                   (* x (variable) *)
  | App of term * term * pos           (* t1 t2 (function application) *)
  | BinOp of binop * term * term * pos (* t1 bop t2 (binary infix operator) *)
  | Ite of term * term * term * pos    (* if t1 then t2 else t3 (conditional) *)
  | Lambda of var * term * pos         (* fun x -> t (lambda abstraction) *)

(** Values, i.e. the computed normal forms *)
type value =
  | IntVal of int (* i *)
  | BoolVal of bool (* b *)
  | Closure of var * term * env (* fun x -> t -- the env component is only needed in the bonus part *)

(* Environments -- only needed in the bonus part *)
and env = (var * value) list
        
(** Pretty printing *)

(** Return the precedence of the top-level syntactic construct in a term [t]. 
  * Lower values mean higher precedence. *)
let precedence = function
  | FunConst _ | IntConst _ | BoolConst _ | Var _ -> 0
  | App _ -> 1
  | BinOp (bop, _, _, _) ->
      (match bop with
      | Mult | Div | Mod -> 3
      | Plus | Minus -> 4
      | Eq | Ne | Lt | Gt | Le | Ge -> 5
      | And -> 6
      | Or -> 7)
  | Ite _ -> 8
  | Lambda _ -> 9

(** check whether given binary operator is left-associative *)
let is_left_assoc = function
  | And | Or -> false
  | _ -> true

        
let string_of_value = function
  | IntVal i -> string_of_int i
  | BoolVal b -> string_of_bool b
  | Closure _ -> ":function"
        
let string_of_bop = function
  | Mult -> "*"
  | Div -> "\\"
  | Mod -> "mod"
  | Plus -> "+"
  | Minus -> "-"
  | Eq -> "="
  | Ne -> "<>"
  | Lt -> "<"
  | Gt -> ">"
  | Le -> "<="
  | Ge -> ">="
  | And -> "&&"
  | Or -> "||"

let string_of_inbuilt_fun = function
  | Fix -> "__fix"
  | Not -> "not"

        
(** Part 1: implement the pretty printer using OCaml's Format module *)
let rec pr_term (ppf: Format.formatter) (t: term) : unit =
  match t with
  | FunConst (f, _) -> Format.fprintf ppf "%s" (string_of_inbuilt_fun f)
  | BoolConst (b, _) -> Format.fprintf ppf "%b" b 
  | IntConst (i, _) -> Format.fprintf ppf "%d" i
  | Var (x, _) ->
      Format.fprintf ppf "%s" x 
  | App (t1, t2, _) as t ->
      (if precedence t1 > precedence t
      then Format.fprintf ppf "@[<2>(%a)%a@]"
      else Format.fprintf ppf "@[<2>%a%a@]")
        pr_term t1
        (fun ppf t2 ->
          (if precedence t2 >= precedence t
          then Format.fprintf ppf "@ (%a)"
          else Format.fprintf ppf "@ %a")
            pr_term t2
        )
        t2
  | BinOp (bop, t1, t2, _) as t ->
      let pr_bop ppf bop = 
        Format.fprintf ppf "%s" (string_of_bop bop)
      in
      let comp1, comp2 =
        if is_left_assoc bop then (>), (>=)
        else (>=), (>)
      in
      (if comp1 (precedence t1) (precedence t)
      then Format.fprintf ppf "@[<2>(%a)@ %a@ %a@]"
      else Format.fprintf ppf "@[<2>%a@ %a@ %a@]")
        pr_term t1
        pr_bop bop
        (fun ppf t2 ->
          (if comp2 (precedence t2) (precedence t)
          then Format.fprintf ppf "(%a)"
          else Format.fprintf ppf "%a")
            pr_term t2
        )
        t2
  | Ite (t1, t2, t3, l) ->
      Format.fprintf ppf "if@ @[<2>%a@]@ then@ @[<2>%a@]@ else@ @[<2>%a@]"
        pr_term t1
        pr_term t2
        pr_term t3
  | Lambda (x, t1, _) ->
      Format.fprintf ppf "@[<2>fun@ %s@ ->@ %a@]"
        x pr_term t1

(** Convert the term [t] to its string representation *)
let string_of_term (t: term) : string =
  pr_term Format.str_formatter t;
  Format.flush_str_formatter ()

(** Pretty print the term [t] to output channel [out_ch]. *)
let print_term (out_ch: out_channel) (t: term) : unit =
  Format.fprintf
    (Format.formatter_of_out_channel out_ch) "%a@?" pr_term t

(** {1} Utility functions for manipulating ASTs *)

(** Extract the source code position associated with the given term. *)
let position_of_term = function
  | FunConst (_, pos) -> pos
  | IntConst (_, pos)
  | BoolConst (_, pos)
  | Var (_, pos)
  | App (_, _, pos)
  | BinOp (_, _, _, pos)
  | Ite (_, _, _, pos)
  | Lambda (_, _, pos) -> pos

(** Check whether terms [t1] and [t2] are syntactically equal modulo source code position tags. *)
let rec equal t1 t2 =
  match t1, t2 with
  | FunConst (f1, _), FunConst (f2, _) -> f1 = f2
  | IntConst (i1, _), IntConst (i2, _) -> i1 = i2
  | BoolConst (b1, _), BoolConst (b2, _) -> b1 = b2
  | Var (x1, _), Var(x2, _) -> x1 = x2
  | App (t11, t12, _), App (t21, t22, _) ->
      equal t11 t21 &&
      equal t12 t22
  | BinOp (bop1, t11, t12, _), BinOp (bop2, t21, t22, _) ->
      bop1 = bop2 &&
      equal t11 t21 &&
      equal t12 t22
  | Ite (t11, t12, t13, _), Ite (t21, t22, t23, _) ->
      equal t11 t21 &&
      equal t12 t22 &&
      equal t13 t23
  | Lambda (x1, t11, _), Lambda (x2, t21, _) ->
      x1 = x2 && equal t11 t21
  | _ -> false
        
(** Part 2: find the first free variable in term [t] if it exists and return it together with its position *)
let find_free_var (t: term) : (var * pos) option =
  let rec fv bound = function
    | FunConst _ | IntConst _ | BoolConst _ -> None
    | Var (x, pos) ->
        if List.mem x bound
        then None
        else Some (x, pos)
    | App (t1, t2, _)
    | BinOp (_, t1, t2, _) ->
        fv bound t1 |>
        Opt.lazy_or_else (fv bound) t2
    | Ite (t1, t2, t3, _) ->
        fv bound t1 |>
        Opt.lazy_or_else (fv bound) t2 |>
        Opt.lazy_or_else (fv bound) t3
    | Lambda (x, t, _) ->
        fv (x :: bound) t
  in
  fv [] t
    
(** Part 3: substitute all free occurrences of variable [x] in term [t] with term [s] (i.e. compute t[s/x]) *)
let subst (t: term) (x: var) (s: term) =
   let rec st = function
    | Var (y, _) when x = y -> s
    | App (t1, t2, pos) -> App (st t1, st t2, pos)
    | BinOp (bop, t1, t2, pos) -> BinOp (bop, st t1, st t2, pos)
    | Ite (t1, t2, t3, pos) -> Ite (st t1, st t2, st t3, pos)
    | Lambda (y, t1, pos) when x <> y -> Lambda (y, st t1, pos)
    | t -> t
  in st t
