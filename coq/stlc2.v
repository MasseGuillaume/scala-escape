(* Full safety for STLC *)
(* values well-typed with respect to runtime environment *)
(* inversion lemma structure *)

(* copied from stlc1.v *)

Require Export SfLib.

Require Export Arith.EqNat.
Require Export Arith.Le.

Require Export stlc1.

Definition stack_frame (X : Type) := prod (list X) nat.
Definition stack (X : Type) := list (stack_frame X).
Definition heap (X : Type) := list X.
Definition env_stack (X : Type) := prod (heap X) (stack_frame X).

Inductive vl_stack : Type :=
| vbool_stack : bool -> vl_stack
| vabs_stack  : heap vl_stack -> option nat -> class -> tm -> vl_stack
.

Definition venv_stack := env_stack vl_stack.

Hint Unfold venv_stack.

Definition index_heap {X : Type} (n : id) (l : env_stack X) : option X := index n (fst l).

Definition index_stack {X : Type} (n : id) (l : env_stack X) : option X :=
match l with
| (_, ([], _))          => None
| (_, (h, off)) => if ble_nat off n then index (n - off) h else None
end.

Definition lookup_stack {X : Type} (n : var) (l : env_stack X) : option X :=
match n with
| VFst i => index_heap i l
| VSnd i => index_stack i l
end
.

Hint Unfold index_heap.
Hint Unfold index_stack.
Hint Unfold lookup_stack.

(*

Inductive wf_env : venv -> tenv -> Prop := 
| wfe_nil : wf_env (Def vl nil nil O) (Def ty nil nil O) 
| wfe_cons : forall v t vs ts n,
    val_type (expand_env vs v n) v t ->
    wf_env vs ts ->
    wf_env (expand_env vs v n) (expand_env ts t n)

with val_type : venv -> vl -> ty -> Prop :=
| v_bool: forall venv b,
    val_type venv (vbool b) TBool
| v_abs: forall env venv tenv y T1 T2 m,
    wf_env venv tenv ->
    has_type (expand_env tenv T1 m) y m T2 ->
    val_type env (vabs venv m y) (TFun T1 m T2)
.

Inductive stp: venv -> ty -> venv -> ty -> Prop :=
| stp_refl: forall G1 G2 T,
   stp G1 T G2 T.
*)


(*
None             means timeout
Some None        means stuck
Some (Some v))   means result v

Could use do-notation to clean up syntax.
 *)
(*Definition heap {X : Type} (env: env_stack X) := fst(env).*)

Definition expand_env_stack {X : Type} (st : stack X) (env : env_stack X) (x : X) (i : option nat)  (n : class) :=
match env, i, n with
| (h, _), Some idx, First  => match index idx st with
                              | None => ([], ([], 0))
                              | Some v => (x::h, v)
                              end
| (h, _), Some idx, Second => match index idx st with
                          | None => ([], ([], 0))
                          | Some (l, off) => (h, (x::l, off))
                          end
| _, _, _ => ([], ([], 0))
end
.

Fixpoint teval_stack(k: nat) (st : stack vl_stack)(env: venv_stack)(t: tm)(n: class){struct k}: option (option vl_stack) :=
  match k with
    | 0 => None
    | S k' =>
      match t, n with
        | ttrue, _              => Some (Some (vbool_stack true))
        | tfalse, _             => Some (Some (vbool_stack false))
        | tvar (VFst i), First  => Some (lookup_stack (VFst i) env)
        | tvar (VSnd i), First  => Some None
        | tvar i, Second        => Some (lookup_stack i env)
        | tabs m y, First       => Some (Some (vabs_stack (fst env) None m y))
        | tabs m y, Second      => Some (Some (vabs_stack (fst env) (Some (length st)) m y))
        | tapp ef ex, _   =>
           match teval_stack k' st env ef Second with
             | None => None
             | Some None => Some None
             | Some (Some (vbool_stack _)) => Some None
             | Some (Some (vabs_stack env2 i m ey)) =>
                match teval_stack k' st env ex m with
                  | None => None
                  | Some None => Some None
                  | Some (Some vx) => let env' := expand_env_stack st (expand_env_stack st env (vabs_stack env2 i m ey) i m) vx i m in
                         teval_stack k' st env' ey First
                end
          end
      end
  end.

Inductive equiv_val : stack vl_stack -> vl -> vl_stack -> Prop :=
  | equiv_const : forall b b' st, b = b' -> equiv_val st (vbool b) (vbool_stack b')
  | equiv_abs : forall H1 H2 idx H lS i t n S,
                      index i lS = Some (S ,idx) ->
                      equiv_env lS (Def vl H1 H2 idx) (H, (S, idx)) ->
                      equiv_val lS (vabs (Def vl H1 H2 idx) n t) (vabs_stack H (Some i) n t)
with equiv_env : stack vl_stack -> venv -> venv_stack -> Prop :=
  | eqv_nil : forall H2 lS, equiv_env lS (Def vl [] H2 (length H2)) ([], ([], length H2))
  | eqv_cons : forall v H1 H2 idx v_stack H lS i n S env,
                    index i lS = Some (S, idx) ->
                    equiv_env lS (Def vl H1 H2 idx) (H, (S, idx)) ->
                    equiv_val lS v v_stack ->
                    env = expand_env_stack lS (H, (S, idx)) v_stack (Some i) n ->
                    equiv_env lS (expand_env (Def vl H1 H2 idx) v n) env
.

Hint Constructors equiv_val.
Hint Constructors equiv_env.

Lemma lookup_equiv : forall v env v_stack env_stack lS x,
   equiv_env lS env env_stack ->
   lookup x env = Some v ->
   lookup_stack x env_stack = Some v_stack ->
   equiv_val lS v v_stack.
Proof.
  Admitted.

Lemma stack_extend : forall lS env env' fr, 
   equiv_env lS env env' ->
   equiv_env (fr::lS) env env'.
Proof.
  intros. generalize fr. induction H.
  constructor.
Admitted.

(*
Lemma equiv_expand : forall lS env env' v v' n idx,
   
Proof.
*)

Theorem teval_equiv : forall k n t env v lS env_stack v_stack,
     equiv_env lS env env_stack ->
     teval k env t n = Some (Some v) ->
     teval_stack k lS env_stack t n = Some (Some v_stack) ->
     equiv_val lS v v_stack.
Proof.
   intro k. induction k.
   Case "k = 0". intros. inversion H0.
   Case "k = S k". intros. destruct t; inversion H0; inversion H1.
     
      SCase "True". constructor; reflexivity.
      SCase "False". constructor; reflexivity.
    
      - SCase "Var".
        eapply lookup_equiv; eauto.
        destruct v0; destruct n; destruct env; try solve by inversion; eauto.
        unfold sanitize_env in H3; eauto.
        destruct v0; destruct n; try solve by inversion; inversion H4; eauto.
      
      - SCase "App".
        
        remember (teval k env t1 Second) as tf.
        destruct tf as [rf|]; try solve by inversion.
        destruct rf as [vf|]; try solve by inversion.
        destruct vf; try solve by inversion.

        remember (teval k env t2 c) as tx.
        destruct tx as [rx|]; try solve by inversion.
        destruct rx as [vx|]; try solve by inversion.

        remember (teval_stack k lS env_stack0 t1 Second) as tf_stack.
        destruct tf_stack as [rf_stack|]; try solve by inversion.
        destruct rf_stack as [vf_stack|]; try solve by inversion.
        destruct vf_stack; try solve by inversion.

        remember (teval_stack k lS env_stack0 t2 c0) as tx_stack.
        destruct tx_stack as [rx_stack|]; try solve by inversion.
        destruct rx_stack as [vx_stack|]; try solve by inversion.
        
        eapply IHk.
          destruct env.
        eapply eqv_cons; eauto.
          ??
        
        
          
  
     


(* TODO: 

Theorem: The lifetimes of second-class values follow a stack discipline.

We define a lower-level operational
semantics that splits environments into first-class and second-class parts,
and maintains a stack of second-class environments through all
function calls. Closures will contain a first-class environment but
only a stack pointer to represent the second-class part. When invoking
a closure, the stack pointer will be used to find the correct caller
environment in which to resolve the callee's free second-class variables.
Proving equivalence of the high-level and low-level semantics will
establish this proposition.

Tentative rules:

N,M ::= nat
H,S ::= 0 | H,x:v


H S_0,..,S_N |- c ⇓^n c    CST

x^m:v  in  H S_N^[<=n]
-----------------------    VAR
H S0,..,SN |- x^m ⇓^n v

H S0,..,SN |- λx^m.t ⇓^n  <H N, λx^m.t>    ABS

H S0,..,SM,..,SN |- t1 ⇓^2  <H' M, λx^m.t3>
H S0,..,SM,..,SN |- t2 ⇓^m  v2
H S0,..,SM,..,SN,(SM x^m: v2) |- t3 ⇓^1  v3
-------------------------------------------    APP
H S0,..,SM,..,SN |- t1 t2 ⇓^n v3


We want to prove that this semantics is equivalent to teval above.

How to do this we need to define alternative version (_stack) of
the following:

  Inductive vl_stack : Type      (because closures are different here)

  Definition venv_stack          (this will be a pair (list vl) * (list list vl),
                                  the H S0,..,SN above)

  Fixpoint teval_stack(k: nat)(env: venv_stack)(t: tm)(n: class){struct k}: option (option vl_stack) :=

And then have correspondences that relate vl/vl_stack, venv/venv_stack, etc.
Let's call these corr_vl, corr_venv, ... .

The final theorem we want to prove is:

  Theorem eval_equiv : forall n e c G GS v vS,
    corr_venv G GS ->
    teval n G e c = v -> 
    teval_stack n GS c = vS ->
    corr_vl v vS.

So, given corresponding environments, the two eval functions produce a
corresponding result.

*)






Hint Constructors ty.
Hint Constructors tm.
Hint Constructors vl.


Hint Constructors has_type.
Hint Constructors val_type.
Hint Constructors wf_env.

Hint Constructors option.
Hint Constructors list.
Hint Constructors env.

Hint Unfold index.
Hint Unfold length.
Hint Unfold expand_env.

Hint Resolve ex_intro.

Definition length_env {X : Type} (c : class) (env : env X): nat :=
match env, c with
| Def l1 l2 n, First => length l1
| Def l1 l2 n, Second => length l2
end
.

Hint Unfold expand_env.

Lemma length_env_incr : forall (X : Type) n m env (x : X),
   n = m ->
   length_env n (expand_env env x m) = 1 + length_env n env.
Proof.
  intros. destruct env; destruct n; inversion H; auto.
Qed.
   
Lemma length_env_same : forall (X : Type) n m env (x : X),
   n <> m ->
   length_env n (expand_env env x m) = length_env n env.
Proof.
  intros. destruct env0; destruct n; destruct m.
      apply ex_falso_quodlibet; auto.
      auto.
      auto.
      apply ex_falso_quodlibet; auto.
Qed.

Hint Rewrite length_env_incr.
Hint Rewrite length_env_same.
Hint Unfold not.

Lemma wf_length : forall vs ts,
      wf_env vs ts ->
      length_env First vs = length_env First ts /\ length_env Second vs = length_env Second ts.
Proof.
  intros. induction H. auto.
  destruct IHwf_env.
  destruct n. 
  Case "First"; split.
  repeat rewrite length_env_incr; auto.
  repeat rewrite length_env_same; auto.
  unfold not; intros. inversion H3. unfold not; intros. inversion H3.
  Case "Second"; split.
  repeat rewrite length_env_same; auto.
  unfold not; intros. inversion H3. unfold not; intros. inversion H3.
  repeat rewrite length_env_incr; auto.
Qed.

Hint Immediate wf_length.

Definition get_class (x : var): class :=
match x with
| VFst _ => First
| VSnd _ => Second
end
.

Definition get_idx (x : var): nat :=
match x with
| VFst n => n
| VSnd n => n
end
.

Lemma index_max : forall X vs x (T: X),
                       lookup x vs = Some T ->
                       get_idx x < length_env (get_class x) vs.
Proof.
  intros X vs; destruct vs as [l1 l2 n].
  intros x T H.
  destruct x; simpl.
  Case "VFst"; induction l1.
    SCase "nil". intros. inversion H.
    SCase "cons".
       intros. inversion H.
       case_eq (beq_nat i (length l1)); intros E.
       SSCase "hit".
          rewrite E in H1. inversion H1. subst.
          eapply beq_nat_true in E. 
          unfold length. unfold length in E. rewrite E. eauto.
       SSCase "miss".
          rewrite E in H1.
          assert (i < length l1). eapply IHl1. apply H1.
          compute. eauto.
  Case "VSnd"; induction l2.
    SCase "nil". inversion H. destruct (ble_nat i n); inversion H1.
    SCase "cons". intros. inversion H.
       case_eq (beq_nat i (length l2)); intros E.
       SSCase "hit".
          rewrite E in H1. inversion H1. subst.
          eapply beq_nat_true in E. 
          unfold length. unfold length in E. rewrite E. eauto.
       SSCase "miss".
          rewrite E in H1.
          assert (i < length l2). eapply IHl2. apply H1.
          compute. eauto.
Qed.

Lemma valtp_extend : forall vs v v1 T,
                       val_type vs v T ->
                       val_type (v1::vs) v T.
Proof. intros. induction H; eauto. Qed.

Lemma index_extend : forall X vs n a (T: X),
                       index n vs = Some T ->
                       index n (a::vs) = Some T.

Proof.
  intros.
  assert (n < length vs). eapply index_max. eauto.
  assert (n <> length vs). omega.
  assert (beq_nat n (length vs) = false) as E. eapply beq_nat_false_iff; eauto.
  unfold index. unfold index in H. rewrite H. rewrite E. reflexivity.
Qed.


Lemma index_safe_ex: forall H1 G1 TF i,
             wf_env H1 G1 ->
             index i G1 = Some TF ->
             exists v, index i H1 = Some v /\ val_type H1 v TF.
Proof. intros. induction H.
       Case "nil". inversion H0.
       Case "cons". inversion H0.
         case_eq (beq_nat i (length ts)).
           SCase "hit".
             intros E.
             rewrite E in H3. inversion H3. subst t.
             assert (beq_nat i (length vs) = true). eauto.
             assert (index i (v :: vs) = Some v). eauto.  unfold index. rewrite H2. eauto.
             eauto.
           SCase "miss".
             intros E.
             assert (beq_nat i (length vs) = false). eauto.
             rewrite E in H3.
             assert (exists v0, index i vs = Some v0 /\ val_type vs v0 TF) as HI. eapply IHwf_env. eauto.
           inversion HI as [v0 HI1]. inversion HI1. 
           eexists. econstructor. eapply index_extend; eauto. eapply valtp_extend; eauto.
Qed.

  
Inductive res_type: venv -> option vl -> ty -> Prop :=
| not_stuck: forall venv v T,
      val_type venv v T ->
      res_type venv (Some v) T.

Hint Constructors res_type.
Hint Resolve not_stuck.


Lemma valtp_widen: forall vf H1 H2 T1 T2,
  val_type H1 vf T1 ->
  stp H1 T1 H2 T2 ->
  val_type H2 vf T2.
Proof.
  intros. inversion H; inversion H0; subst T2; subst; eauto.
Qed.


Lemma invert_abs: forall venv vf vx T1 T2,
  val_type venv vf (TFun T1 T2) ->
  exists env tenv y T3 T4,
    vf = (vabs env y) /\ 
    wf_env env tenv /\
    has_type (T3::(TFun T3 T4)::tenv) y T4 /\
    stp venv T1 (vx::vf::env) T3 /\
    stp (vx::vf::env) T4 venv T2.
Proof.
  intros. inversion H. repeat eexists; repeat eauto.
Qed.


(* if not a timeout, then result not stuck and well-typed *)

Theorem full_safety : forall n e tenv venv res T,
  teval n venv e = Some res -> has_type tenv e T -> wf_env venv tenv ->
  res_type venv res T.

Proof.
  intros n. induction n.
  (* 0 *)   intros. inversion H.
  (* S n *) intros. destruct e; inversion H; inversion H0.
  
  Case "True".  eapply not_stuck. eapply v_bool.
  Case "False". eapply not_stuck. eapply v_bool.

  Case "Var".
    destruct (index_safe_ex venv0 tenv0 T i) as [v [I V]]; eauto. 

    rewrite I. eapply not_stuck. eapply V.

  Case "App".
    remember (teval n venv0 e1) as tf.
    remember (teval n venv0 e2) as tx. 
    subst T.
    
    destruct tx as [rx|]; try solve by inversion.
    assert (res_type venv0 rx T1) as HRX. SCase "HRX". subst. eapply IHn; eauto.
    inversion HRX as [? vx]. 

    destruct tf as [rf|]; subst rx; try solve by inversion.  
    assert (res_type venv0 rf (TFun T1 T2)) as HRF. SCase "HRF". subst. eapply IHn; eauto.
    inversion HRF as [? vf].

    destruct (invert_abs venv0 vf vx T1 T2) as
        [env1 [tenv [y0 [T3 [T4 [EF [WF [HTY [STX STY]]]]]]]]]. eauto.
    (* now we know it's a closure, and we have has_type evidence *)

    assert (res_type (vx::vf::env1) res T4) as HRY.
      SCase "HRY".
        subst. eapply IHn. eauto. eauto.
        (* wf_env f x *) econstructor. eapply valtp_widen; eauto.
        (* wf_env f   *) econstructor. eapply v_abs; eauto.
        eauto.

    inversion HRY as [? vy].

    eapply not_stuck. eapply valtp_widen; eauto.
    
  Case "Abs". intros. inversion H. inversion H0.
    eapply not_stuck. eapply v_abs; eauto.
Qed.

End STLC2.