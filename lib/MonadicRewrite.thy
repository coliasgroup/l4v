(*
 * Copyright 2022, Proofcraft Pty Ltd
 * Copyright 2020, Data61, CSIRO (ABN 41 687 119 230)
 *
 * SPDX-License-Identifier: BSD-2-Clause
 *)

(* Theory of monadic rewriting under preconditions, applicable under refinement. *)

theory MonadicRewrite
imports
  NonDetMonadVCG
  Corres_UL
  EmptyFailLib
  LemmaBucket
begin

definition monadic_rewrite ::
  "bool \<Rightarrow> bool \<Rightarrow> ('s \<Rightarrow> bool) \<Rightarrow> ('s, 'a) nondet_monad \<Rightarrow> ('s, 'a) nondet_monad \<Rightarrow> bool"
  where
   "monadic_rewrite F E P f g \<equiv>
      \<forall>s. P s \<and> (F \<longrightarrow> \<not> snd (f s))
          \<longrightarrow> (E \<longrightarrow> f s = g s) \<and> (\<not> E \<longrightarrow> fst (g s) \<subseteq> fst (f s) \<and> (snd (g s) \<longrightarrow> snd (f s)))"

lemma monadic_rewrite_inst:
  "monadic_rewrite F E P f g \<Longrightarrow> monadic_rewrite F E P f g"
  by assumption

lemma monadic_rewrite_refl_generic:
  "monadic_rewrite F E P f f"
  by (simp add: monadic_rewrite_def)

lemmas monadic_rewrite_refl = monadic_rewrite_refl_generic[where P=\<top>]

lemma monadic_rewrite_sym:
  "monadic_rewrite False True P f g \<Longrightarrow> monadic_rewrite False True P g f"
  by (simp add: monadic_rewrite_def)

lemma monadic_rewrite_impossible:
  "monadic_rewrite F E \<bottom> f g"
  by (clarsimp simp: monadic_rewrite_def)

lemma monadic_rewrite_imp:
  "\<lbrakk> monadic_rewrite F E Q f g; \<And>s. P s \<Longrightarrow> Q s \<rbrakk> \<Longrightarrow> monadic_rewrite F E P f g"
  by (auto simp add: monadic_rewrite_def)

lemma monadic_rewrite_trans:
  "\<lbrakk> monadic_rewrite F E P f g; monadic_rewrite F E Q g h \<rbrakk>
   \<Longrightarrow> monadic_rewrite F E (P and Q) f h"
  by (auto simp add: monadic_rewrite_def)

lemma monadic_rewrite_trans_dup:
  "\<lbrakk> monadic_rewrite F E P f g; monadic_rewrite F E P g h \<rbrakk>
   \<Longrightarrow> monadic_rewrite F E P f h"
  by (rule monadic_rewrite_imp, (rule monadic_rewrite_trans; assumption), simp)

lemma monadic_rewrite_from_simple:
  "P \<longrightarrow> f = g \<Longrightarrow> monadic_rewrite F E (\<lambda>_. P) f g"
  by (simp add: monadic_rewrite_def)

lemma monadic_rewrite_gen_asm:
  "\<lbrakk> P \<Longrightarrow> monadic_rewrite F E Q f g \<rbrakk> \<Longrightarrow> monadic_rewrite F E ((\<lambda>_. P) and Q) f g"
  by (auto simp add: monadic_rewrite_def)

lemma monadic_rewrite_name_pre:
  "\<lbrakk> \<And>s. P s \<Longrightarrow> monadic_rewrite F E ((=) s) f g \<rbrakk>
   \<Longrightarrow> monadic_rewrite F E P f g"
  by (auto simp add: monadic_rewrite_def)

lemma monadic_rewrite_cases:
  "\<lbrakk> P \<Longrightarrow> monadic_rewrite F E Q a b; \<not> P \<Longrightarrow> monadic_rewrite F E R a b \<rbrakk>
   \<Longrightarrow> monadic_rewrite F E (\<lambda>s. (P \<longrightarrow> Q s) \<and> (\<not> P \<longrightarrow> R s)) a b"
  by (cases P, simp_all)

lemma monadic_rewrite_is_refl:
  "x = y \<Longrightarrow> monadic_rewrite F E \<top> x y"
  by (simp add: monadic_rewrite_refl)

lemma monadic_rewrite_refl3:
  "\<lbrakk> \<And>s. P s \<Longrightarrow> f s = g s \<rbrakk> \<Longrightarrow> monadic_rewrite F E P f g"
  by (simp add: monadic_rewrite_def)

lemmas monadic_rewrite_refl2 = monadic_rewrite_refl3[where P=\<top>]

lemma monadic_rewrite_exists:
  "(\<And>v. monadic_rewrite F E (Q v) m m')
   \<Longrightarrow> monadic_rewrite F E ((\<lambda>s. \<forall>v. P v s \<longrightarrow> Q v s) and (\<lambda>s. \<exists>v. P v s)) m m'"
  by (auto simp: monadic_rewrite_def)

lemma monadic_rewrite_exists_v:
  "\<lbrakk> \<And>v. monadic_rewrite E F (Q v) f g \<rbrakk>
   \<Longrightarrow> monadic_rewrite E F (\<lambda>x. (\<exists>v. P v x) & (\<forall>v. P v x \<longrightarrow> Q v x)) f g"
  by (rule monadic_rewrite_name_pre)
     (fastforce elim: monadic_rewrite_imp)

lemma monadic_rewrite_weaken:
  "monadic_rewrite (F \<and> F') (E \<or> E') P f g
   \<Longrightarrow> monadic_rewrite F' E' P f g"
  by (auto simp: monadic_rewrite_def)

lemma monadic_rewrite_weaken2:
  "monadic_rewrite F E P f g
   \<Longrightarrow> monadic_rewrite F' E' ((\<lambda>_. (F \<longrightarrow> F') \<and> (E' \<longrightarrow> E)) and P) f g"
  apply (rule monadic_rewrite_gen_asm)
  apply (rule monadic_rewrite_weaken[where F=F and E=E])
  apply auto
  done

text \<open>bind/bindE\<close>

lemma snd_bind:
  "snd ((a >>= b) s) = (snd (a s) \<or> (\<exists>(r, s') \<in> fst (a s). snd (b r s')))"
  by (auto simp add: bind_def split_def)

lemma monadic_rewrite_bind:
  "\<lbrakk> monadic_rewrite F E P f g; \<And>x. monadic_rewrite F E (Q x) (h x) (j x); \<lbrace>R\<rbrace> g \<lbrace>Q\<rbrace> \<rbrakk>
   \<Longrightarrow> monadic_rewrite F E (P and R) (f >>= (\<lambda>x. h x)) (g >>= (\<lambda>x. j x))"
  apply (cases E)
   apply (clarsimp simp: monadic_rewrite_def snd_bind imp_conjL)
   apply (drule spec, drule(1) mp, clarsimp)
   apply (rule bind_apply_cong)
    apply simp
   apply (frule(2) use_valid)
   apply fastforce
  apply (clarsimp simp: monadic_rewrite_def snd_bind imp_conjL)
  apply (simp add: bind_def split_def)
  apply (rule conjI)
   apply (rule UN_mono)
    apply simp
   apply clarsimp
   apply (frule(2) use_valid)
   apply fastforce
  apply (rule conjI)
   apply fastforce
  apply clarsimp
  apply (frule(2) use_valid)
  apply fastforce
  done

lemma monadic_rewrite_bindE:
  "\<lbrakk> monadic_rewrite F E P f g; \<And>x. monadic_rewrite F E (Q x) (h x) (j x); \<lbrace>R\<rbrace> g \<lbrace>Q\<rbrace>,- \<rbrakk>
   \<Longrightarrow> monadic_rewrite F E (P and R) (f >>=E (\<lambda>x. h x)) (g >>=E (\<lambda>x. j x))"
  apply (simp add: bindE_def)
  apply (erule monadic_rewrite_bind)
   prefer 2
   apply (simp add: validE_R_def validE_def)
  apply (case_tac x; simp add: lift_def monadic_rewrite_refl)
  done

lemmas monadic_rewrite_bind_tail
  = monadic_rewrite_bind[OF monadic_rewrite_refl, simplified pred_and_true_var]

lemmas monadic_rewrite_bind_head
  = monadic_rewrite_bind [OF _ monadic_rewrite_refl hoare_vcg_prop, simplified pred_and_true]

lemmas monadic_rewrite_bind_alt
  = monadic_rewrite_trans[OF monadic_rewrite_bind_tail monadic_rewrite_bind_head, rotated -1]

lemmas monadic_rewrite_bindE_head
    = monadic_rewrite_bindE[OF _ monadic_rewrite_refl hoare_vcg_propE_R]

lemma monadic_rewrite_bind2:
  "\<lbrakk> monadic_rewrite F E P f g; \<And>x. monadic_rewrite F E (Q x) (h x) (j x); \<lbrace>R\<rbrace> f \<lbrace>Q\<rbrace> \<rbrakk>
   \<Longrightarrow> monadic_rewrite F E (P and R) (f >>= (\<lambda>x. h x)) (g >>= (\<lambda>x. j x))"
  apply (rule monadic_rewrite_imp)
   apply (rule monadic_rewrite_trans)
    apply (erule(1) monadic_rewrite_bind_tail)
   apply (erule monadic_rewrite_bind_head)
  apply simp
  done

lemma monadic_rewrite_named_bindE:
  "\<lbrakk> monadic_rewrite F E ((=) s) f f';
    \<And>rv s'. (Inr rv, s') \<in> fst (f' s) \<Longrightarrow> monadic_rewrite F E ((=) s') (g rv) (g' rv) \<rbrakk>
   \<Longrightarrow> monadic_rewrite F E ((=) s) (f >>=E (\<lambda>rv. g rv)) (f' >>=E g')"
  apply (rule monadic_rewrite_imp)
   apply (erule_tac R="(=) s" and Q="\<lambda>rv s'. (Inr rv, s') \<in> fst (f' s)" in monadic_rewrite_bindE)
    apply (rule monadic_rewrite_name_pre)
    apply clarsimp
   apply (clarsimp simp add: validE_R_def validE_def valid_def
                      split: sum.split)
  apply simp
  done

(* FIXME: poorly named, super-specific (could do this with maybe one bind?), used in Ipc_C *)
lemma monadic_rewrite_do_flip:
  "monadic_rewrite E F P (do c \<leftarrow> j; a \<leftarrow> f; b \<leftarrow> g c; return (a, c) od)
                         (do c \<leftarrow> j; b \<leftarrow> g c; a \<leftarrow> f; return (a, c) od)
   \<Longrightarrow> monadic_rewrite E F P (do c \<leftarrow> j; a \<leftarrow> f; b \<leftarrow> g c; h a c od)
                            (do c \<leftarrow> j; b \<leftarrow> g c; a \<leftarrow> f; h a c od)"
  apply (drule_tac h="\<lambda>(a, b). h a b" in monadic_rewrite_bind_head)
  apply (simp add: bind_assoc)
  done

text \<open>catch\<close>

lemma monadic_rewrite_catch:
  "\<lbrakk> monadic_rewrite F E P f g; \<And>x. monadic_rewrite F E (Q x) (h x) (j x); \<lbrace>R\<rbrace> g -,\<lbrace>Q\<rbrace> \<rbrakk>
   \<Longrightarrow> monadic_rewrite F E (P and R) (f <catch> (\<lambda>x. h x)) (g <catch> (\<lambda>x. j x))"
  apply (simp add: catch_def)
  apply (erule monadic_rewrite_bind)
   defer
   apply (simp add: validE_E_def validE_def)
  apply (case_tac x, simp_all add: lift_def monadic_rewrite_refl)
  done

text \<open>modify\<close>

lemma monadic_rewrite_drop_modify:
  "monadic_rewrite F E (\<lambda>s. f s = s) (modify f >>= v) (v ())"
  by (simp add: monadic_rewrite_def bind_def simpler_modify_def)

lemma monadic_rewrite_modify_noop:
  "monadic_rewrite F E (\<lambda>s. f s = s) (modify f) (return ())"
  by (clarsimp simp: monadic_rewrite_def simpler_modify_def return_def)

text \<open>Symbolic execution\<close>

lemma monadic_rewrite_symb_exec_pre:
  assumes inv: "\<And>s. g \<lbrace> (=) s\<rbrace>"
       and ef: "empty_fail g"
       and rv: "\<lbrace>P\<rbrace> g \<lbrace>\<lambda>y s. y \<in> S\<rbrace>"
       and h': "\<And>y. y \<in> S \<longrightarrow> h y = h'"
  shows "monadic_rewrite True True P (g >>= h) h'"
proof -
  have P: "\<And>s v. \<lbrakk> P s; v \<in> fst (g s) \<rbrakk> \<Longrightarrow> split h v = h' s"
    apply clarsimp
    apply (frule use_valid[OF _ inv], rule refl)
    apply (frule(1) use_valid[OF _ rv])
    apply (simp add: h')
    done

  show ?thesis
    apply (clarsimp simp: monadic_rewrite_def bind_def P image_constant_conv
                    cong: image_cong)
    apply (drule empty_failD2[OF ef])
    apply (clarsimp simp: prod_eq_iff split: if_split_asm)
    done
qed

lemma singleton_eq_imp_helper:
  "v \<in> {x} \<longrightarrow> h v = h x" by simp

lemmas monadic_rewrite_symb_exec
  = monadic_rewrite_symb_exec_pre[OF _ _ _ singleton_eq_imp_helper,
                                  THEN monadic_rewrite_trans, simplified]

lemma eq_UNIV_imp_helper:
  "v \<in> UNIV \<longrightarrow> x = x" by simp

lemmas monadic_rewrite_symb_exec2
  = monadic_rewrite_symb_exec_pre[OF _ _ _ eq_UNIV_imp_helper, where P=\<top>,
                                  simplified, THEN monadic_rewrite_trans]

lemma monadic_rewrite_symb_exec_r:
  "\<lbrakk> \<And>s. m \<lbrace>(=) s\<rbrace>; no_fail P' m;
     \<And>rv. monadic_rewrite F False (Q rv) x (y rv);
     \<lbrace>P\<rbrace> m \<lbrace>Q\<rbrace> \<rbrakk>
   \<Longrightarrow> monadic_rewrite F False (P and P') x (m >>= y)"
  apply (clarsimp simp: monadic_rewrite_def bind_def)
  apply (drule(1) no_failD)
  apply (subgoal_tac "\<forall>v \<in> fst (m s). Q (fst v) (snd v) \<and> snd v = s")
   apply fastforce
  apply clarsimp
  apply (frule(2) use_valid)
  apply (frule use_valid, assumption, rule refl)
  apply simp
  done

lemma monadic_rewrite_symb_exec_r':
  "\<lbrakk> \<And>s. m \<lbrace>(=) s\<rbrace>; no_fail P m;
     \<And>rv. monadic_rewrite F False (Q rv) x (y rv);
     \<lbrace>P\<rbrace> m \<lbrace>Q\<rbrace> \<rbrakk>
   \<Longrightarrow> monadic_rewrite F False P x (m >>= y)"
  apply (rule monadic_rewrite_imp)
   apply (rule monadic_rewrite_symb_exec_r; assumption)
  apply simp
  done

lemma monadic_rewrite_symb_exec_l'':
  "\<lbrakk> \<And>s. m \<lbrace>(=) s\<rbrace>; empty_fail m;
     \<not> F \<longrightarrow> no_fail P' m;
     \<And>rv. monadic_rewrite F False (Q rv) (x rv) y;
     \<lbrace>P\<rbrace> m \<lbrace>Q\<rbrace> \<rbrakk>
   \<Longrightarrow> monadic_rewrite F False (P and P') (m >>= x) y"
  apply (clarsimp simp: monadic_rewrite_def bind_def)
  apply (subgoal_tac "\<not> snd (m s)")
   apply (subgoal_tac "\<forall>v \<in> fst (m s). Q (fst v) (snd v) \<and> snd v = s")
    apply (frule(1) empty_failD2)
    apply (clarsimp simp: split_def)
    apply fastforce
   apply clarsimp
   apply (frule(2) use_valid)
   apply (frule use_valid, assumption, rule refl)
   apply simp
  apply (cases F, simp_all add: no_failD)
  done

lemma monadic_rewrite_symb_exec_l':
  "\<lbrakk> \<And>P. m \<lbrace>P\<rbrace>; empty_fail m;
     \<not> F \<longrightarrow> no_fail P' m;
     \<And>rv. monadic_rewrite F E (Q rv) (x rv) y;
     \<lbrace>P\<rbrace> m \<lbrace>Q\<rbrace> \<rbrakk>
   \<Longrightarrow> monadic_rewrite F E (P and P') (m >>= x) y"
  apply (cases E)
   apply (clarsimp simp: monadic_rewrite_def bind_def prod_eq_iff)
   apply (subgoal_tac "\<not> snd (m s)")
    apply (simp add: empty_fail_def, drule_tac x=s in spec)
    apply (subgoal_tac "\<forall>(rv, s') \<in> fst (m s). x rv s' = y s")
     apply (rule conjI)
      apply (rule equalityI)
       apply (clarsimp simp: Ball_def)
      apply (fastforce simp: Ball_def elim!: nonemptyE elim: rev_bexI)
     apply (simp add: Bex_def Ball_def cong: conj_cong)
     apply auto[1]
    apply clarsimp
    apply (drule(1) in_inv_by_hoareD)
    apply (frule(2) use_valid)
    apply (clarsimp simp: Ball_def prod_eq_iff)
   apply (clarsimp simp: no_fail_def)
  apply simp
  apply (rule monadic_rewrite_symb_exec_l'', assumption+)
  done

(* FIXME this should replace monadic_rewrite_symb_exec_l' as it preserves names,
   and this approach should be used everywhere else anyhow, however that breaks proofs
   relying on arbitrarily generated names, so will be dealt with in future *)
lemma monadic_rewrite_symb_exec_l'_preserve_names:
  "\<lbrakk> \<And>P. m \<lbrace>P\<rbrace>; empty_fail m;
     \<not> F \<longrightarrow> no_fail P' m;
     \<And>rv. monadic_rewrite F E (Q rv) (x rv) y;
     \<lbrace>P\<rbrace> m \<lbrace>Q\<rbrace> \<rbrakk>
   \<Longrightarrow> monadic_rewrite F E (P and P') (m >>= (\<lambda>rv. x rv)) y"
  by (rule monadic_rewrite_symb_exec_l')

(* FIXME merge into below upon change-over desribed above *)
lemmas monadic_rewrite_symb_exec_l'_TT
  = monadic_rewrite_symb_exec_l'_preserve_names[where P'="\<top>" and F=True, simplified]

lemmas monadic_rewrite_symb_exec_l
  = monadic_rewrite_symb_exec_l''[where F=True and P'=\<top>, simplified]
    monadic_rewrite_symb_exec_l''[where F=False, simplified simp_thms]

lemma monadic_rewrite_symb_exec_l_known:
  "\<lbrakk> \<And>s. m \<lbrace>(=) s\<rbrace>; empty_fail m;
     monadic_rewrite True False Q (x rv) y;
     \<lbrace>P\<rbrace> m \<lbrace>\<lambda>rv' s. rv' = rv \<and> Q s\<rbrace> \<rbrakk>
   \<Longrightarrow> monadic_rewrite True False P (m >>= x) y"
  apply (erule(1) monadic_rewrite_symb_exec_l)
   apply (rule_tac P="rva = rv" in monadic_rewrite_gen_asm)
   apply simp
  apply wpsimp
  done

text \<open>if\<close>

lemma monadic_rewrite_if:
  "\<lbrakk> P \<Longrightarrow> monadic_rewrite F E Q a c; \<not> P \<Longrightarrow> monadic_rewrite F E R b d \<rbrakk>
   \<Longrightarrow> monadic_rewrite F E (\<lambda>s. (P \<longrightarrow> Q s) \<and> (\<not> P \<longrightarrow> R s))
                          (If P a b) (If P c d)"
  by (cases P, simp_all)

lemma monadic_rewrite_if_rhs:
  "\<lbrakk> P \<Longrightarrow> monadic_rewrite F E Q a b; \<not> P \<Longrightarrow> monadic_rewrite F E R a c \<rbrakk>
   \<Longrightarrow> monadic_rewrite F E (\<lambda>s. (P \<longrightarrow> Q s) \<and> (\<not> P \<longrightarrow> R s)) a (If P b c)"
  by (cases P, simp_all)

lemmas monadic_rewrite_named_if
  = monadic_rewrite_if[where Q="(=) s" and R="(=) s", simplified] for s

lemma monadic_rewrite_if_lhs:
  "\<lbrakk> P \<Longrightarrow> monadic_rewrite F E Q b a; \<not> P \<Longrightarrow> monadic_rewrite F E R c a \<rbrakk>
   \<Longrightarrow> monadic_rewrite F E (\<lambda>s. (P \<longrightarrow> Q s) \<and> (\<not> P \<longrightarrow> R s)) (If P b c) a"
  by (cases P, simp_all)

lemma monadic_rewrite_if_known:
  "monadic_rewrite F E ((\<lambda>s. C = X) and \<top>) (if C then f else g) (if X then f else g)"
  by (rule monadic_rewrite_gen_asm)
     (simp add: monadic_rewrite_refl split del: if_split)

text \<open>lift\<close>

lemma monadic_rewrite_liftM:
  "monadic_rewrite F E P f g \<Longrightarrow> monadic_rewrite F E P (liftM fn f) (liftM fn g)"
  by (clarsimp simp: liftM_def elim!: monadic_rewrite_bind_head)

lemmas monadic_rewrite_liftE
  = monadic_rewrite_liftM[where fn=Inr, folded liftE_liftM]

lemma monadic_rewrite_split_fn:
  "\<lbrakk> monadic_rewrite F E P (liftM fn a) c;
     \<And>rv. monadic_rewrite F E (Q rv) (b rv) (d (fn rv));
     \<lbrace>R\<rbrace> a \<lbrace>Q\<rbrace> \<rbrakk>
   \<Longrightarrow> monadic_rewrite F E (P and R) (a >>= b) (c >>= d)"
  apply (rule monadic_rewrite_imp)
   apply (rule monadic_rewrite_trans[rotated])
    apply (erule monadic_rewrite_bind_head)
   apply (simp add: liftM_def)
   apply (erule(1) monadic_rewrite_bind_tail)
  apply simp
  done

text \<open>Assertions\<close>

lemma monadic_rewrite_add_assert:
  "monadic_rewrite F E (\<lambda>s. P) m (assert P >>= (\<lambda>_. m))"
  by (simp add: monadic_rewrite_def)

lemma monadic_rewrite_assert:
  "\<lbrakk> Q \<Longrightarrow> monadic_rewrite True E P (f ()) g \<rbrakk>
   \<Longrightarrow> monadic_rewrite True E (\<lambda>s. Q \<longrightarrow> P s) (assert Q >>= f) g"
  by (simp add: assert_def split: if_split)
     (simp add: monadic_rewrite_def fail_def)

lemma monadic_rewrite_assert2:
  "\<lbrakk> Q \<Longrightarrow> monadic_rewrite F E P (f ()) g \<rbrakk>
   \<Longrightarrow> monadic_rewrite F E ((\<lambda>s. Q \<longrightarrow> P s) and (\<lambda>_. Q)) (assert Q >>= f) g"
  by (auto simp add: assert_def monadic_rewrite_def fail_def split: if_split)

lemma monadic_rewrite_state_assert_true:
  "monadic_rewrite F E P (state_assert P) (return ())"
  by (simp add: state_assert_def monadic_rewrite_def exec_get)

lemma monadic_rewrite_stateAssert:
  "monadic_rewrite F E P (stateAssert P xs) (return ())"
  by (simp add: stateAssert_def monadic_rewrite_def exec_get)

text \<open>Non-determinism: alternative and select\<close>

lemma monadic_rewrite_alternative_rhs:
  "\<lbrakk> monadic_rewrite F E P a b; monadic_rewrite F E Q a c \<rbrakk>
   \<Longrightarrow> monadic_rewrite F E (P and Q) a (b \<sqinter> c)"
  by (auto simp: monadic_rewrite_def alternative_def)

lemma monadic_rewrite_alternatives:
  "\<lbrakk> monadic_rewrite E F P a c; monadic_rewrite E F Q b d \<rbrakk>
   \<Longrightarrow> monadic_rewrite E F (P and Q) (a \<sqinter> b) (c \<sqinter> d)"
  by (auto simp: monadic_rewrite_def alternative_def)

lemma monadic_rewrite_rdonly_bind:
  "\<lbrakk> \<And>s. f \<lbrace>(=) s\<rbrace> \<rbrakk>
   \<Longrightarrow> monadic_rewrite F False \<top> (alternative (f >>= (\<lambda>x. g x)) h)
                                (f >>= (\<lambda>x. alternative (g x) h))"
  apply (clarsimp simp: monadic_rewrite_def bind_def
                        alternative_def imp_conjL)
  apply (subgoal_tac "\<forall>x \<in> fst (f s). snd x = s")
   apply (simp add: image_image split_def cong: image_cong)
   apply fastforce
  apply clarsimp
  apply (frule use_valid, (assumption | rule refl | simp)+)
  done

lemmas monadic_rewrite_rdonly_bind_l
  = monadic_rewrite_trans[OF monadic_rewrite_rdonly_bind]

lemma monadic_rewrite_alternative_l:
  "monadic_rewrite F False \<top> (alternative f g) g"
  by (clarsimp simp: monadic_rewrite_def alternative_def)

lemma monadic_rewrite_introduce_alternative:
  "\<lbrakk> f = f'; monadic_rewrite F E P (alternative f' f) g \<rbrakk>
   \<Longrightarrow> monadic_rewrite F E P f g"
  by (simp add: alternative_def)

lemma monadic_rewrite_pick_alternative_1:
  "monadic_rewrite F False \<top> (alternative f g) f"
  by (auto simp add: monadic_rewrite_def alternative_def)

lemmas monadic_rewrite_pick_alternative_2 = monadic_rewrite_alternative_l

lemma monadic_rewrite_select_x:
  "monadic_rewrite F False (\<lambda>s. x \<in> S) (select S) (return x)"
  by (simp add: monadic_rewrite_def return_def select_def)

lemmas monadic_rewrite_select_pick_x
  = monadic_rewrite_bind_head[OF monadic_rewrite_select_x[where x=x], simplified,
                              THEN monadic_rewrite_trans] for x

text \<open>get/gets\<close>

lemma monadic_rewrite_add_get:
  "monadic_rewrite F E P (do x <- get; f od) (do x <- get; g od)
   \<Longrightarrow> monadic_rewrite F E P f g"
  by (clarsimp simp: bind_def get_def)

lemma monadic_rewrite_add_gets:
  "monadic_rewrite F E \<top> m (gets f >>= (\<lambda>_. m))"
  by (simp add: monadic_rewrite_def exec_gets)

lemma monadic_rewrite_gets_known:
  "monadic_rewrite F E (\<lambda>s. f s = rv) (gets f >>= m) (m rv)"
  by (simp add: monadic_rewrite_def exec_gets)

lemma monadic_rewrite_gets_the_known_v:
  "monadic_rewrite F E (\<lambda>s. f s = Some v)
     (gets_the f) (return v)"
  by (simp add: monadic_rewrite_def gets_the_def
                exec_gets assert_opt_def)

lemma monadic_rewrite_gets_the_walk:
  "\<lbrakk> \<And>x. monadic_rewrite True False (P x) (g x) (gets_the pf >>= g' x);
     \<And>Q. f \<lbrace>\<lambda>s. Q (pf s)\<rbrace>;
     \<lbrace>R\<rbrace> f \<lbrace>P\<rbrace>; empty_fail f \<rbrakk>
   \<Longrightarrow> monadic_rewrite True False R (f >>= g)
                                   (do v \<leftarrow> gets_the pf; x \<leftarrow> f; g' x v od)"
  apply (rule monadic_rewrite_imp)
   apply (rule monadic_rewrite_trans)
    apply (erule(1) monadic_rewrite_bind_tail)
   apply (simp add: gets_the_def bind_assoc)
   apply (rule monadic_rewrite_symb_exec_r, wp+)
    apply (rule monadic_rewrite_trans)
     apply (rule monadic_rewrite_bind_tail)
      apply (rule_tac rv=rv in monadic_rewrite_symb_exec_l_known,
             (wp empty_fail_gets)+)
       apply (rule monadic_rewrite_refl)
      apply wp
     apply assumption
    apply (rule_tac P="rv = None" in monadic_rewrite_cases[where Q=\<top>])
     apply (simp add: assert_opt_def)
     apply (clarsimp simp: monadic_rewrite_def fail_def snd_bind)
     apply (rule ccontr, drule(1) empty_failD2)
     apply clarsimp
    apply (simp add: assert_opt_def case_option_If2)
    apply (rule monadic_rewrite_refl)
   apply wp
  apply simp
  done

lemma monadic_rewrite_gets_l:
  "(\<And>x. monadic_rewrite F E (P x) (g x) m)
   \<Longrightarrow> monadic_rewrite F E (\<lambda>s. P (f s) s) (gets f >>= (\<lambda>x. g x)) m"
  by (auto simp add: monadic_rewrite_def exec_gets)

lemma monadic_rewrite_gets_the_bind:
  assumes mr: "(\<And>v. monadic_rewrite F E (Q v) (g v) m)"
  shows "monadic_rewrite F E (\<lambda>s. f s \<noteq> None \<and> Q (the (f s)) s) (gets_the f >>= (\<lambda>x. g x)) m"
  apply (rule monadic_rewrite_imp)
  apply (rule monadic_rewrite_exists[where P="\<lambda>v s. f s = Some v"])
   apply (subst return_bind[symmetric, where f="\<lambda>_. m"])
   apply (rule monadic_rewrite_bind)
     apply (rule_tac v=v in monadic_rewrite_gets_the_known_v)
    apply (rule mr)
   apply wpsimp+
  done

lemma monadic_rewrite_gets_the_gets:
  "monadic_rewrite F E (\<lambda>s. f s \<noteq> None) (gets_the f) (gets (the o f))"
  apply (simp add: monadic_rewrite_def gets_the_def assert_opt_def exec_gets
            split: option.split)
  apply (auto simp: simpler_gets_def return_def)
  done

text \<open>Option cases\<close>

lemma monadic_rewrite_case_option:
  "\<lbrakk> \<And>y. x = Some y \<Longrightarrow> monadic_rewrite E F (P x) f (g y);
     x = None \<Longrightarrow> monadic_rewrite E F Q f h \<rbrakk>
   \<Longrightarrow> monadic_rewrite E F (\<lambda>s. (\<forall>y. x = Some y \<longrightarrow> P x s) \<and> (x = None \<longrightarrow> Q s))
                          f (case x of Some y \<Rightarrow> g y | None \<Rightarrow> h)"
  by (cases x, simp_all)

lemma monadic_rewrite_case_sum:
  "\<lbrakk> \<And>v. x = Inl v \<Longrightarrow> monadic_rewrite F E (P v) (a v) (c v);
     \<And>v. x = Inr v \<Longrightarrow> monadic_rewrite F E (Q v) (b v) (d v) \<rbrakk>
   \<Longrightarrow> monadic_rewrite F E (\<lambda>s. (\<not> isRight x \<longrightarrow> P (theLeft x) s) \<and> (isRight x \<longrightarrow> Q (theRight x) s))
        (case_sum a b x) (case_sum c d x)"
  by (cases x, simp_all add: isRight_def)

text \<open>WP proof via monadic rewriting\<close>

lemma monadic_rewrite_refine_valid:
  "\<lbrakk> monadic_rewrite F E P f g;
     \<lbrace>P'\<rbrace> f \<lbrace>Q\<rbrace>;
     F \<longrightarrow> no_fail P'' f \<rbrakk>
   \<Longrightarrow> \<lbrace>P and P' and P''\<rbrace> g \<lbrace>Q\<rbrace>"
  by (fastforce simp: monadic_rewrite_def valid_def no_fail_def imp_conjL Ball_def)

lemma monadic_rewrite_refine_validE_R:
  "\<lbrakk> monadic_rewrite F E P f g;
     \<lbrace>P'\<rbrace> f \<lbrace>Q\<rbrace>, -;
     F \<longrightarrow> no_fail P'' f \<rbrakk>
   \<Longrightarrow> \<lbrace>P and P' and P''\<rbrace> g \<lbrace>Q\<rbrace>, -"
  by (simp add: validE_R_def validE_def monadic_rewrite_refine_valid)

lemma monadic_rewrite_is_valid:
  "\<lbrakk> monadic_rewrite False False P' f f'; \<lbrace>P\<rbrace> do x <- f; g x od \<lbrace>Q\<rbrace> \<rbrakk>
   \<Longrightarrow> \<lbrace>P and P'\<rbrace> do x <- f'; g x od \<lbrace>Q\<rbrace>"
  by (fastforce simp: monadic_rewrite_def valid_def bind_def)

text \<open>Specific failure flags and flag manipulation\<close>

lemma monadic_rewrite_to_eq:
  "monadic_rewrite False True \<top> f g \<Longrightarrow> f = g"
  by (simp add: monadic_rewrite_def fun_eq_iff)

lemma monadic_rewrite_transverse:
  "\<lbrakk> monadic_rewrite False True Q c b; monadic_rewrite F E P a b \<rbrakk>
   \<Longrightarrow> monadic_rewrite F E (P and Q) a c"
  by (auto simp add: monadic_rewrite_def)

lemma monadic_rewrite_weaken_failure:
  "\<lbrakk> monadic_rewrite True True P f f'; no_fail P' f; no_fail Q' f' \<rbrakk>
   \<Longrightarrow> monadic_rewrite F E (P and P' and Q') f f'"
  by (clarsimp simp: monadic_rewrite_def no_fail_def)

text \<open>corres / refinement\<close>

lemma monadic_rewrite_corres:
  assumes cu: "corres_underlying R False nf' r P P' a' c"
  and     me: "monadic_rewrite False True Q a a'"
  shows   "corres_underlying R False nf' r (P and Q) P' a c"
proof (rule corres_underlyingI)
  fix s t rv' t'
  assume st: "(s, t) \<in> R" and pq: "(P and Q) s" and pt: "P' t" and ct: "(rv', t') \<in> fst (c t)"
  from pq have Ps: "P s" and Qs: "Q s" by simp_all

  from cu st Ps pt ct obtain s' rv where
     as': "(rv, s') \<in> fst (a' s)" and rest: "nf' \<longrightarrow> \<not> snd (c t)" "(s', t') \<in> R" "r rv rv'"
    by (fastforce elim: corres_underlyingE)

  from me st Qs as' have as: "(rv, s') \<in> fst (a s)"
    by (clarsimp simp: monadic_rewrite_def)

  with rest show "\<exists>(rv, s')\<in>fst (a s). (s', t') \<in> R \<and> r rv rv'" by auto
next
  fix s t
  assume "(s, t) \<in> R" "(P and Q) s" "P' t" "nf'"
  thus "\<not> snd (c t)" using cu
    by (fastforce simp: corres_underlying_def split_def)
qed

lemma monadic_rewrite_corres':
  assumes cu: "corres_underlying R False nf' r P P' a c'"
  and     me: "monadic_rewrite False True Q c c'"
  shows   "corres_underlying R False nf' r  P (P' and Q) a c"
proof (rule corres_underlyingI)
  fix s t rv' t'
  assume st: "(s, t) \<in> R" and pq: "(P' and Q) t" and ps: "P s" and ct: "(rv', t') \<in> fst (c t)"
  from pq have P't: "P' t" and Qt: "Q t" by simp_all

  from me ct Qt have c't: "(rv', t') \<in> fst (c' t)"
   by (clarsimp simp: monadic_rewrite_def)

  from cu st ps P't c't obtain s' rv where
     as: "(rv, s') \<in> fst (a s)" and rest: "nf' \<longrightarrow> \<not> snd (c' t)" "(s', t') \<in> R" "r rv rv'"
    by (fastforce elim: corres_underlyingE)

  with rest as show "\<exists>(rv, s')\<in>fst (a s). (s', t') \<in> R \<and> r rv rv'" by auto
next
  fix s t
  assume "(s, t) \<in> R" "(P' and Q) t" "P s" "nf'"
  thus "\<not> snd (c t)" using cu me
    by (fastforce simp: corres_underlying_def split_def monadic_rewrite_def)
qed

lemma monadic_rewrite_corres_rhs:
  "\<lbrakk> monadic_rewrite False True Q c c';
     corres_underlying R F F' r P P' a c' \<rbrakk>
   \<Longrightarrow> corres_underlying R F F' r P (P' and Q) a c"
  by (fastforce simp: corres_underlying_def monadic_rewrite_def)

lemma monadic_rewrite_corres2:
  "\<lbrakk> monadic_rewrite False E Q a a';
     corres_underlying R False F r P P' a' c \<rbrakk>
   \<Longrightarrow> corres_underlying R False F r (P and Q) P' a c"
  by (fastforce simp add: corres_underlying_def monadic_rewrite_def)

lemmas corres_gets_the_bind
  = monadic_rewrite_corres2[OF monadic_rewrite_bind_head[OF monadic_rewrite_gets_the_gets]]

text \<open>Tool integration\<close>

lemma wpc_helper_monadic_rewrite:
  "monadic_rewrite F E Q' m m'
   \<Longrightarrow> wpc_helper (P, P') (Q, {s. Q' s}) (monadic_rewrite F E (\<lambda>s. s \<in> P') m m')"
  by (auto simp: wpc_helper_def elim!: monadic_rewrite_imp)

wpc_setup "\<lambda>m. monadic_rewrite F E Q' m m'" wpc_helper_monadic_rewrite
wpc_setup "\<lambda>m. monadic_rewrite F E Q' (m >>= c) m'" wpc_helper_monadic_rewrite

end
