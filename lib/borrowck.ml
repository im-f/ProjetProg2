(* Once you are done writing the code, remove this directive,
   whose purpose is to disable several warnings. *)
[@@@warning "-26-27"]

open Type
open Minimir
open Active_borrows

(* This function computes the set of alive lifetimes at every program point. *)
let compute_lft_sets prog mir : lifetime -> PpSet.t =

  (* The [outlives] variable contains all the outlives relations between the
    lifetime variables of the function. *)
  let outlives = ref LMap.empty in

  (* Helper functions to add outlives constraints. *)
  let add_outlives (l1, l2) = outlives := add_outlives_edge l1 l2 !outlives in
  let unify_lft l1 l2 =
    add_outlives (l1, l2);
    add_outlives (l2, l1)
  in

  (* First, we add in [outlives] the constraints implied by the type of locals. *)
  Hashtbl.iter
    (fun _ typ -> outlives := outlives_union !outlives (implied_outlives prog typ))
    mir.mlocals;

  (* Then, we add the outlives relations needed for the instructions to be safe. *)

  (* TODO: generate these constraints by
       - unifying types that need be equal (note that MiniRust does not support subtyping, that is,
         if a variable x: &'a i32 is used as type &'b i32, then this requires that lifetimes 'a and
         'b are equal),
       - adding constraints required by function calls,
       - generating constraints corresponding to reborrows. More precisely, if we create a borrow
         of a place that dereferences  borrows, then the lifetime of the borrow we
         create should be shorter than the lifetimes of the borrows the place dereference.
         For example, if x: &'a &'b i32, and we create a borrow y = &**x of type &'c i32,
         then 'c should be shorter than 'a and 'b.

    SUGGESTION: use functions [typ_of_place], [fields_types_fresh] and [fn_prototype_fresh].
  *)

  (* Function to find the place that has been dereferenced *)
  let rec find_deref_borrow pl = 
    match pl with 
    | PlDeref deref -> deref
    | PlField (pl1, _) -> (find_deref_borrow pl1)
    | _ -> failwith "Should be a deref borrow" (* Should never enter this case *)
  in 
  (* Function to check if two types are identical. If they are, unify their lifetimes if possible, otherwise, raise an error*)
  let check_unif loc typ typ' = 
    match typ, typ' with 
    | Tborrow (lyf1, _, _), Tborrow (lyf2, _, _) -> unify_lft lyf1 lyf2
    | Tstruct (_, struct_lyf1), Tstruct (_, struct_lyf2) -> 
      List.iter2 unify_lft struct_lyf1 struct_lyf2
    | Tbool, Tbool | Ti32, Ti32 | Tunit, Tunit -> ()
    | _ ->  Error.error loc "Rust doesnt support subtyping"
  in
  Array.iter 
    (
      fun (instr, loc) -> 
        match instr with
        | Icall (s, _, _, _) -> 
          (* We find the oulives constraints of the function called and add them to [outlives] *)
          let (_, _, typ_fn) = fn_prototype_fresh prog s in 
          List.iter (fun x -> add_outlives x) typ_fn
        | Iassign (pl, RVborrow(_, pl_borrow), _) -> 
          if (contains_deref_borrow pl) then 
            (* We get the place derefenced *)
            let deref = find_deref_borrow pl in 
            (match typ_of_place prog mir pl with 
            | Tborrow (lft, _, _) -> 
              (* If we want to initialise a borrow, we check if theres a lifetime associated with the type of the place its going in *)
              ( match typ_of_place prog mir deref with 
                (* If its the case, we add it to [outlives] following the contraints *)
                | Tborrow (lft', _, _) -> add_outlives (lft',lft)
                | Tstruct (_, lft_l) -> List.iter (fun x -> add_outlives (x,lft)) lft_l
                | _ -> ()
              )
            | _ -> ())
        (* For the rest, we check if its necessary to unify lifetimes by using the function [check_unif] *)
        | Iassign (pl, RVplace(pl'), _) -> check_unif loc (typ_of_place prog mir pl) (typ_of_place prog mir pl')
        | Iassign (pl, RVmake(s, pl_l), _) -> 
          let (typ_l, typ) = fields_types_fresh prog s in 
          check_unif loc (typ_of_place prog mir pl) typ;
          List.iter2 (fun x x' -> check_unif loc x (typ_of_place prog mir x')) typ_l pl_l
        | _ -> ()
    ) 
    mir.minstrs;

  (* The [living] variable contains constraints of the form "lifetime 'a should be
    alive at program point p". *)
  let living : PpSet.t LMap.t ref = ref LMap.empty in

  (* Helper function to add living constraint. *)
  let add_living pp l =
    living :=
      LMap.update l
        (fun s -> Some (PpSet.add pp (Option.value s ~default:PpSet.empty)))
        !living
  in

  (* Run the live local analysis. See module Live_locals for documentation. *)
  let live_locals = Live_locals.go mir in

  (* TODO: generate living constraints:
     - Add living constraints corresponding to the fact that liftimes appearing free
       in the type of live locals at some program point should be alive at that
       program point.
     - Add living constraints corresponding to the fact that generic lifetime variables
       (those in [mir.mgeneric_lfts]) should be alive during the whole execution of the
       function. 
  *)

  (* If [lft] is a generic lifetime, [lft] is always alive at [PpInCaller lft]. *)
  List.iter (fun lft -> add_living (PpInCaller lft) lft) mir.mgeneric_lfts;

  Array.iteri 
    (fun lbl (instr, loc) -> 
      (* We make sure generic lifetimes are alive at all points of the program *)
      List.iter (fun lft -> add_living (PpLocal lbl) lft) mir.mgeneric_lfts;

      (* Live locals at this point of the program *)
      let livelocinit = live_locals lbl in 

      (* Function to verify if the lifetime has been freed or not at that point of the program *)
      let free_alive_lft typ lft = 
        let free_lft_typ = free_lfts typ in 
        if (LSet.mem lft free_lft_typ) then 
           add_living (PpLocal(lbl)) lft
        else Error.error loc "Alive lifetime should be free" (* If it isnt, the contraint wasnt respected *)
      in
      match instr with 
      | Iassign (pl, _, _) | Icall (_, _, pl, _) -> 
      (
        let loc_pl = local_of_place pl in

        if LocSet.mem loc_pl livelocinit then 
          let typ_pl = typ_of_place prog mir pl in 
          match typ_pl with 
          | Tborrow (lft, _, _) -> free_alive_lft typ_pl lft
          | Tstruct (_, lft_l) -> 
            List.iter (fun x -> free_alive_lft typ_pl x) lft_l
          | _ -> ()
      )
      | _ -> ()

    ) 
    mir.minstrs;

  (* Now, we compute lifetime sets by finding the smallest solution of the constraints, using the
    Fix library. *)
  let module Fix = Fix.Fix.ForType (struct type t = lifetime end) (Fix.Prop.Set (PpSet))
  in
  Fix.lfp (fun lft lft_sets ->
      LSet.fold
        (fun lft acc -> PpSet.union (lft_sets lft) acc)
        (Option.value ~default:LSet.empty (LMap.find_opt lft !outlives))
        (Option.value ~default:PpSet.empty (LMap.find_opt lft !living)))

let borrowck prog mir =
  (* We check initializedness requirements for every instruction. *)
  let uninitialized_places = Uninitialized_places.go prog mir in
  Array.iteri
    (fun lbl (instr, loc) ->
      let uninit : PlaceSet.t = uninitialized_places lbl in

      let check_initialized pl =
        if PlaceSet.exists (fun pluninit -> is_subplace pluninit pl) uninit then
          Error.error loc "Use of a place which is not fully initialized at this point."
      in

      (match instr with
      | Iassign (pl, _, _) | Icall (_, _, pl, _) -> (
          match pl with
          | PlDeref pl0 ->
              if PlaceSet.mem pl0 uninit then
                Error.error loc "Writing into an uninitialized borrow."
          | PlField (pl0, _) ->
              if PlaceSet.mem pl0 uninit then
                Error.error loc "Writing into a field of an uninitialized struct."
          | _ -> ())
      | _ -> ());

      match instr with
      | Iassign (_, RVplace pl, _) | Iassign (_, RVborrow (_, pl), _) ->
          check_initialized pl
      | Iassign (_, RVbinop (_, pl1, pl2), _) ->
          check_initialized pl1;
          check_initialized pl2
      | Iassign (_, RVunop (_, pl), _) | Iif (pl, _, _) -> check_initialized pl
      | Iassign (_, RVmake (_, pls), _) | Icall (_, pls, _, _) ->
          List.iter check_initialized pls
      | Ireturn -> check_initialized (PlLocal Lret)
      | Iassign (_, (RVunit | RVconst _), _) | Ideinit _ | Igoto _ -> ())
    mir.minstrs;

  (* We check the code honors the non-mutability of shared borrows. *)
  Array.iteri
    (fun _ (instr, loc) ->
      (* TODO: check that we never write to shared borrows, and that we never create mutable borrows
        below shared borrows. Function [place_mut] can be used to determine if a place is mutable, i.e., if it
        does not dereference a shared borrow. *)
      let check_mut pl = 
        match (place_mut prog mir pl) with
        | NotMut -> Error.error loc "Writing in unmutable place"
        | Mut -> ()
      in
      match instr with
      | Iassign (pl, RVborrow(mut, pl1), _)  ->  (
        (* We check that we're not writing content in an unmutable place *)
          check_mut pl;
        (* If the first check passes, we check that we're not creating a mutable borrow 
          in an unmutable place  *)
          match mut with 
          | Mut -> (match (place_mut prog mir pl1) with
                    | NotMut -> Error.error loc "Creating a mutable borrow in an unmutable place"
                    | Mut -> ())
          | NotMut -> ()
        )
      | Iassign (pl, _, _) | Iif (pl, _, _) | Icall (_, _, pl, _) -> check_mut pl
      | Ireturn -> check_mut (PlLocal Lret)
      | _ -> ()
    )
    mir.minstrs;

  let lft_sets = compute_lft_sets prog mir in

  (* TODO: check that outlives constraints declared in the prototype of the function are
    enough to ensure safety. I.e., if [lft_sets lft] contains program point [PpInCaller lft'], this
    means that we need that [lft] be alive when [lft'] dies, i.e., [lft'] outlives [lft]. This relation
    has to be declared in [mir.outlives_graph]. *)

  List.iter 
    (fun lft -> 
        let k_lft_set = lft_sets lft in 
          PpSet.iter 
          ( fun pp -> 
              match pp with 
              | PpInCaller lft' -> 
               (match LMap.find_opt lft' mir.moutlives_graph with 
                | Some lft_l -> 
                  (if not (LSet.mem lft lft_l) then 
                    Error.error mir.mloc "Lifetime isnt alive long enough")
                | None -> ()
                )
              | _ -> ()
          ) k_lft_set;
    ) mir.mgeneric_lfts;

  (* We check that we never perform any operation which would conflict with an existing
    borrows. *)
  let bor_active_at = Active_borrows.go prog lft_sets mir in
  Array.iteri
    (fun lbl (instr, loc) ->
      (* The list of bor_info for borrows active at this instruction. *)
      let active_borrows_info : bor_info list =
        List.map (get_bor_info prog mir) (BSet.to_list (bor_active_at lbl))
      in

      (* Does there exist a borrow of a place pl', which is active at program point [lbl],
        such that a *write* to [pl] conflicts with this borrow?

         If [pl] is a subplace of pl', then writing to [pl] is always conflicting, because
        it is aliasing with the borrow of pl'.

         If pl' is a subplace of [pl], the situation is more complex:
           - if pl' involves as many dereferences as [pl] (e.g., writing to [x.f1] while
            [x.f1.f2] is borrowed), then the write to [pl] will overwrite pl', hence this is
            conflicting.
           - BUT, if pl' involves more dereferences than [pl] (e.g., writing to [x.f1] while
            [*x.f1.f2] is borrowed), then writing to [pl] will *not* modify values accessible
            from pl'. Hence, subtlely, this is not a conflict. *)
      let conflicting_borrow_no_deref pl =
        List.exists
          (fun bi -> is_subplace pl bi.bplace || is_subplace_no_deref bi.bplace pl)
          active_borrows_info
      in

      (match instr with
      | Iassign (pl, _, _) | Icall (_, _, pl, _) ->
          if conflicting_borrow_no_deref pl then
            Error.error loc "Assigning a borrowed place."
      | Ideinit (l, _) ->
          if conflicting_borrow_no_deref (PlLocal l) then
            Error.error loc
              "A local declared here leaves its scope while still being borrowed."
      | Ireturn ->
          Hashtbl.iter
            (fun l _ ->
              match l with
              | Lparam p ->
                  if conflicting_borrow_no_deref (PlLocal l) then
                    Error.error loc
                      "When returning from this function, parameter `%s` is still \
                       borrowed."
                      p
              | _ -> ())
            mir.mlocals
      | _ -> ());

      (* Variant of [conflicting_borrow_no_deref]: does there exist a borrow of a place pl',
        which is active at program point [lbl], such that a *read* to [pl] conflicts with this
        borrow? In addition, if parameter [write] is true, we consider an operation which is
        both a read and a write. *)
      let conflicting_borrow write pl =
        List.exists
          (fun bi ->
            (bi.bmut = Mut || write)
            && (is_subplace pl bi.bplace || is_subplace bi.bplace pl))
          active_borrows_info
      in

      (* Check a "use" (copy or move) of place [pl]. *)
      let check_use pl =
        let consumes = not (typ_is_copy prog (typ_of_place prog mir pl)) in
        if conflicting_borrow consumes pl then
          Error.error loc "A borrow conflicts with the use of this place.";
        if consumes && contains_deref_borrow pl then
          Error.error loc "Moving a value out of a borrow."
      in
      (* Check if writing in borrow is possible *)
      let check_write_use pl1 f = 
        if conflicting_borrow true pl1 then 
          Error.error loc "Cant write in borrow"
        else f ()
      in
      match instr with
      (* We check each time if writing in a place is possible or not. 
         If it is, we check that the use of the rest of the places associated is correct *)
      | Iassign (pl1, RVunop (_, pl), _) 
      | Iassign (pl1, RVplace(pl), _) -> check_write_use pl1 (fun () -> check_use pl)
      | Iassign (pl0, RVbinop (_, pl, pl1), _) -> 
        check_write_use pl0 (fun () -> check_use pl; check_use pl1)
      | Icall (_, pl_l, pl, _)
      | Iassign (pl, RVmake (_, pl_l), _) -> 
        check_write_use pl (fun () -> List.iter check_use pl_l )
      | Iassign (pl1, RVborrow (mut, pl), _) ->
        check_write_use pl1 (fun () -> if conflicting_borrow (mut = Mut) pl then
                                          Error.error loc "There is a borrow conflicting with borrow.")
      | Iassign (pl, _, _) -> check_write_use pl (fun () -> ())
      | _ -> () 
    )
    mir.minstrs
