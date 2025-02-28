module S = Syntax


let rec eval_exp = function
  | S.Var x -> failwith "Expected a closed term"
  | S.Int _ | S.Bool _ | S.Lambda _ | S.RecLambda _ as e -> e
  | S.Plus (e1, e2) ->
    let n1 = eval_int e1
    and n2 = eval_int e2
    in S.Int (n1 + n2)
  | S.Minus (e1, e2) ->
    let n1 = eval_int e1
    and n2 = eval_int e2
    in S.Int (n1 - n2)
  | S.Times (e1, e2) ->
    let n1 = eval_int e1
    and n2 = eval_int e2
    in S.Int (n1 * n2)
  | S.Equal (e1, e2) ->
    let n1 = eval_int e1
    and n2 = eval_int e2
    in S.Bool (n1 = n2)
  | S.Less (e1, e2) ->
    let n1 = eval_int e1
    and n2 = eval_int e2
    in S.Bool (n1 < n2)
  | S.Greater (e1, e2) ->
    let n1 = eval_int e1
    and n2 = eval_int e2
    in S.Bool (n1 > n2)
  | S.IfThenElse (e, e1, e2) ->
    begin match eval_exp e with
      | S.Bool true -> eval_exp e1
      | S.Bool false -> eval_exp e2
      | _ -> failwith "Boolean expected"
    end
  | S.Apply (e1, e2) ->
    let f = eval_exp e1
    in
    begin match f with
      | S.Lambda (x, e) -> eval_exp (S.subst [(x, e2)] e)
      | S.RecLambda (f, x, e) as rec_f -> eval_exp (S.subst [(f, rec_f); (x, e2)] e)
      | _ -> failwith "Function expected"
    end
  | S.Nil -> S.Nil
  | S.Pair (e1, e2) -> S.Pair (eval_exp e1, eval_exp e2)
  | S.Fst e ->
    begin match e with
      | S.Pair (e1, e2) -> eval_exp e1
      | _ -> S.Fst (eval_exp e)
    end
  | S.Snd e ->
    begin match e with
      | S.Pair (e1, e2) -> eval_exp e2
      | _ -> S.Snd (eval_exp e)
    end
  | S.Cons (e, es) -> S.Cons (eval_exp e, eval_exp es)
  | S.Match (e, e1, x, xs, e2) ->
    begin match e with
      | S.Nil -> eval_exp e1
      | S.Cons (v, vs) -> eval_exp (S.subst [(x, v); (xs, vs)] e2)
      | _ -> eval_exp (S.Match (eval_exp e, e1, x, xs, e2))
    end

and eval_int e =
  match eval_exp e with
  | S.Int n -> n
  | _ -> failwith "Integer expected"

let rec is_value = function
  | S.Int _ | S.Bool _ | S.Lambda _ | S.RecLambda _ 
  | S.Nil -> true
  | S.Pair (e1, e2) when is_value e1 && is_value e2 -> true
  | S.Cons (e, es) when is_value e && is_value es -> true
  | S.Var _ | S.Plus _ | S.Minus _ | S.Times _ | S.Equal _ | S.Less _ | S.Greater _
  | S.IfThenElse _ | S.Apply _ 
  | S.Fst _ | S.Snd _ | S.Match _ | S.Pair _ | S.Cons _ -> false

let rec step = function
  | S.Var _ | S.Int _ | S.Bool _ | S.Lambda _ | S.RecLambda _ -> failwith "Expected a non-terminal expression"
  | S.Plus (S.Int n1, S.Int n2) -> S.Int (n1 + n2)
  | S.Plus (S.Int n1, e2) -> S.Plus (S.Int n1, step e2)
  | S.Plus (e1, e2) -> S.Plus (step e1, e2)
  | S.Minus (S.Int n1, S.Int n2) -> S.Int (n1 - n2)
  | S.Minus (S.Int n1, e2) -> S.Minus (S.Int n1, step e2)
  | S.Minus (e1, e2) -> S.Minus (step e1, e2)
  | S.Times (S.Int n1, S.Int n2) -> S.Int (n1 * n2)
  | S.Times (S.Int n1, e2) -> S.Times (S.Int n1, step e2)
  | S.Times (e1, e2) -> S.Times (step e1, e2)
  | S.Equal (S.Int n1, S.Int n2) -> S.Bool (n1 = n2)
  | S.Equal (S.Int n1, e2) -> S.Equal (S.Int n1, step e2)
  | S.Equal (e1, e2) -> S.Equal (step e1, e2)
  | S.Less (S.Int n1, S.Int n2) -> S.Bool (n1 < n2)
  | S.Less (S.Int n1, e2) -> S.Less (S.Int n1, step e2)
  | S.Less (e1, e2) -> S.Less (step e1, e2)
  | S.Greater (S.Int n1, S.Int n2) -> S.Bool (n1 > n2)
  | S.Greater (S.Int n1, e2) -> S.Greater (S.Int n1, step e2)
  | S.Greater (e1, e2) -> S.Greater (step e1, e2)
  | S.IfThenElse (S.Bool b, e1, e2) -> if b then e1 else e2
  | S.IfThenElse (e, e1, e2) -> S.IfThenElse (step e, e1, e2)
  | S.Apply (S.Lambda (x, e), e2)-> S.subst [(x, e2)] e
  | S.Apply (S.RecLambda (f, x, e) as rec_f, e2)-> S.subst [(f, rec_f); (x, e2)] e
  | S.Apply (e1, e2) -> S.Apply (step e1, e2)
  | S.Nil -> S.Nil
  | S.Pair (v1, v2) as p when is_value v1 && is_value v2 -> p
  | S.Pair (v1, e2) when is_value v1 -> S.Pair (v1, step e2)
  | S.Pair (e1, e2) -> S.Pair (step e1, e2)
  | S.Fst S.Pair (e1, e2) -> e1
  | S.Fst _ -> failwith "Pair Expected"
  | S.Snd S.Pair (e1, e2) -> e2
  | S.Snd _ -> failwith "Pair Expected"
  | S.Cons (v, vs) as l when is_value v && is_value vs -> l
  | S.Cons (v, xs) when is_value v -> S.Cons (v, step xs)
  | S.Cons (x, xs) -> S.Cons (step x, xs)
  | S.Match (S.Nil, e1, x, xs, e2) -> e1
  | S.Match (S.Cons (v, vs) as e, e1, x, xs, e2) when is_value e ->
    (S.subst [(x, v); (xs, vs)] e2)
  | S.Match (e, e1, x, xs, e2) when is_value e -> failwith "List expected"
  | S.Match (e, e1, x, xs, e2) -> S.Match (step e, e1, x, xs, e2)

let big_step e =
  let v = eval_exp e in
  print_endline (S.string_of_exp v)

let rec small_step e =
  print_endline (S.string_of_exp e);
  if not (is_value e) then
    (print_endline "  ~>";
     small_step (step e))
