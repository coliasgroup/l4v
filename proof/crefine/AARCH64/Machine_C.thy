(*
 * Copyright 2023, Proofcraft Pty Ltd
 * Copyright 2020, Data61, CSIRO (ABN 41 687 119 230)
 * Copyright 2014, General Dynamics C4 Systems
 *
 * SPDX-License-Identifier: GPL-2.0-only
 *)

(*
   Assumptions and lemmas on machine operations.
*)

theory Machine_C
imports Ctac_lemmas_C
begin

(* FIXME: somewhere automation has failed, resulting in virq_C arrays not being in packed_type! *)
instance virq_C :: array_inner_packed
  apply intro_classes
  by (simp add: size_of_def)

locale kernel_m = kernel +

(* timer and IRQ common machine ops (function names exist on other platforms *)

assumes resetTimer_ccorres:
  "ccorres dc xfdc \<top> UNIV []
           (doMachineOp resetTimer)
           (Call resetTimer_'proc)"

(* This is not very correct, however our current implementation of Hardware in haskell is stateless *)
assumes isIRQPending_ccorres:
  "\<And>in_kernel.
     ccorres (\<lambda>rv rv'. rv' = from_bool (rv \<noteq> None)) ret__unsigned_long_'
      \<top> UNIV []
      (doMachineOp (getActiveIRQ in_kernel)) (Call isIRQPending_'proc)"

assumes getActiveIRQ_Normal:
  "\<Gamma> \<turnstile> \<langle>Call getActiveIRQ_'proc, Normal s\<rangle> \<Rightarrow> s' \<Longrightarrow> isNormal s'"

(* AArch64-specific machine ops (function names don't exist on other platforms) *)

(* FIXME AARCH64 TODO
   cache ops might need to go here
*)

(* Hypervisor-related machine ops *)

(* FIXME AARCH64 TODO *)

(* FIXME AARCH64 these were RISCV64 machine op ccorres assumptions, remove after we have new ones
assumes setVSpaceRoot_ccorres:
  "ccorres dc xfdc \<top> (\<lbrace>\<acute>addr___unsigned_long = pt\<rbrace> \<inter> \<lbrace>\<acute>asid___unsigned_long = asid\<rbrace>) []
           (doMachineOp (AARCH64.setVSpaceRoot pt asid))
           (Call setVSpaceRoot_'proc)"

assumes hwASIDFlush_ccorres:
  "ccorres dc xfdc \<top> (\<lbrace>\<acute>asid___unsigned_long = asid\<rbrace>) []
           (doMachineOp (AARCH64.hwASIDFlush asid))
           (Call hwASIDFlush_'proc)"

assumes read_stval_ccorres:
  "ccorres (=) ret__unsigned_long_' \<top> UNIV []
           (doMachineOp RISCV64.read_stval)
           (Call read_stval_'proc)"

assumes sfence_ccorres:
  "ccorres dc xfdc \<top> UNIV []
           (doMachineOp RISCV64.sfence)
           (Call sfence_'proc)"

assumes maskInterrupt_ccorres:
  "ccorres dc xfdc \<top> (\<lbrace>\<acute>disable = from_bool m\<rbrace> \<inter> \<lbrace>\<acute>irq = ucast irq\<rbrace>) []
           (doMachineOp (maskInterrupt m irq))
           (Call maskInterrupt_'proc)"

assumes getActiveIRQ_ccorres:
"\<And>in_kernel.
   ccorres (\<lambda>(a::irq option) c::64 word.
     case a of None \<Rightarrow> c = ucast irqInvalid
     | Some (x::irq) \<Rightarrow> c = ucast x \<and> c \<noteq> ucast irqInvalid)
     ret__unsigned_long_'
     \<top> UNIV hs
 (doMachineOp (getActiveIRQ in_kernel)) (Call getActiveIRQ_'proc)"

assumes ackInterrupt_ccorres:
  "ccorres dc xfdc \<top> UNIV hs
           (doMachineOp (ackInterrupt irq))
           (Call ackInterrupt_'proc)"

assumes plic_complete_claim_ccorres:
  "ccorres dc xfdc \<top> \<lbrace>\<acute>irq = ucast irq\<rbrace> []
           (doMachineOp (plic_complete_claim irq))
           (Call plic_complete_claim_'proc)"


assumes setIRQTrigger_ccorres:
  "ccorres dc xfdc \<top> (\<lbrace>\<acute>irq = ucast irq\<rbrace> \<inter> \<lbrace>\<acute>edge_triggered = from_bool trigger\<rbrace>) []
           (doMachineOp (RISCV64.setIRQTrigger irq trigger))
           (Call setIRQTrigger_'proc)"
*)


(* The following are fastpath specific assumptions.
   We might want to move them somewhere else. *)

(*
  @{text slowpath} is an assembly stub that switches execution
  from the fastpath to the slowpath. Its contract is equivalence
  to the toplevel slowpath function @{term callKernel} for the
  @{text SyscallEvent} case.
*)
assumes slowpath_ccorres:
  "ccorres dc xfdc
     (\<lambda>s. invs' s \<and> ct_in_state' ((=) Running) s)
     ({s. syscall_' s = syscall_from_H ev})
     [SKIP]
     (callKernel (SyscallEvent ev)) (Call slowpath_'proc)"

(*
  @{text slowpath} does not return, but uses the regular
  slowpath kernel exit instead.
*)
assumes slowpath_noreturn_spec:
  "\<Gamma> \<turnstile> UNIV Call slowpath_'proc {},UNIV"

(*
  @{text fastpath_restore} updates badge and msgInfo registers
  and returns to the user.
*)
assumes fastpath_restore_ccorres:
  "ccorres dc xfdc
     (\<lambda>s. t = ksCurThread s)
     ({s. badge_' s = bdg} \<inter> {s. msgInfo_' s = msginfo}
      \<inter> {s. cur_thread_' s = tcb_ptr_to_ctcb_ptr t})
     [SKIP]
     (asUser t (zipWithM_x setRegister
               [AARCH64_H.badgeRegister, AARCH64_H.msgInfoRegister]
               [bdg, msginfo]))
     (Call fastpath_restore_'proc)"

context kernel_m begin

lemma index_xf_for_sequence:
  "\<forall>s f. index_' (index_'_update f s) = f (index_' s)
          \<and> globals (index_'_update f s) = globals s"
  by simp

lemma dmo_if:
  "(doMachineOp (if a then b else c)) = (if a then (doMachineOp b) else (doMachineOp c))"
  by (simp split: if_split)

(* Count leading and trailing zeros. *)

(* FIXME AARCH64 clzl and ctzl use builtin compiler versions, while clz32/64 and ctz32/64 are
   software implementations that are provided BUT NOT USED, hence this whole chunk except for
   clzl_spec and ctzl_spec can be removed. *)

definition clz32_step where
  "clz32_step i \<equiv>
    \<acute>mask___unsigned :== \<acute>mask___unsigned >> unat ((1::32 sword) << unat i);;
    \<acute>bits___unsigned :== SCAST(32 signed \<rightarrow> 32) (if \<acute>mask___unsigned < \<acute>x___unsigned then 1 else 0) << unat i;;
    Guard ShiftError \<lbrace>\<acute>bits___unsigned < SCAST(32 signed \<rightarrow> 32) 0x20\<rbrace>
      (\<acute>x___unsigned :== \<acute>x___unsigned >> unat \<acute>bits___unsigned);;
    \<acute>count :== \<acute>count - \<acute>bits___unsigned"

definition clz32_invariant where
  "clz32_invariant i s \<equiv> {s'.
   mask___unsigned_' s' \<ge> x___unsigned_' s'
   \<and> of_nat (word_clz (x___unsigned_' s')) + count_' s' = of_nat (word_clz (x___unsigned_' s)) + 32
   \<and> mask___unsigned_' s' = mask (2 ^ unat i)}"

lemma clz32_step:
  "unat (i :: 32 sword) < 5 \<Longrightarrow>
   \<Gamma> \<turnstile> (clz32_invariant (i+1) s) clz32_step i (clz32_invariant i s)"
  unfolding clz32_step_def
  apply (vcg, clarsimp simp: clz32_invariant_def)
  \<comment> \<open>Introduce some trivial but useful facts so that most later goals are solved with simp\<close>
  apply (prop_tac "i \<noteq> -1", clarsimp simp: unat_minus_one_word)
  apply (frule unat_Suc2)
  apply (prop_tac "(2 :: nat) ^ unat i < (32 :: nat)",
         clarsimp simp: power_strict_increasing_iff[where b=2 and y=5, simplified])
  apply (prop_tac "(2 :: nat) ^ unat (i + 1) \<le> (32 :: nat)",
         clarsimp simp: unat_Suc2 power_increasing_iff[where b=2 and y=4, simplified])
  apply (intro conjI impI; clarsimp)
       apply (clarsimp simp: word_less_nat_alt)
      apply (erule le_shiftr)
     apply (clarsimp simp: word_size shiftr_mask2 word_clz_shiftr)
    apply (clarsimp simp: shiftr_mask2)
   apply fastforce
  apply (clarsimp simp: shiftr_mask2)
  done

lemma clz32_spec:
  "\<forall>s. \<Gamma> \<turnstile> {s} Call clz32_'proc \<lbrace>\<acute>ret__unsigned = of_nat (word_clz (x___unsigned_' s))\<rbrace>"
  apply (hoare_rule HoarePartial.ProcNoRec1)
  apply (hoarep_rewrite, fold clz32_step_def)
  apply (intro allI hoarep.Catch[OF _ hoarep.Skip])
  apply (rule_tac Q="clz32_invariant 0 s" in hoarep_Seq_nothrow[OF _ creturn_wp])
   apply (rule HoarePartial.SeqSwap[OF clz32_step], simp, simp)+
   apply (rule conseqPre, vcg)
   apply (all \<open>clarsimp simp: clz32_invariant_def mask_def word_less_max_simp\<close>)
  by (fastforce simp: word_le_1)

definition clz64_step where
  "clz64_step i \<equiv>
    \<acute>mask___unsigned_longlong :== \<acute>mask___unsigned_longlong >> unat ((1::32 sword) << unat i);;
    \<acute>bits___unsigned :== SCAST(32 signed \<rightarrow> 32) (if \<acute>mask___unsigned_longlong < \<acute>x___unsigned_longlong then 1 else 0) << unat i;;
    Guard ShiftError \<lbrace>\<acute>bits___unsigned < SCAST(32 signed \<rightarrow> 32) 0x40\<rbrace>
      (\<acute>x___unsigned_longlong :== \<acute>x___unsigned_longlong >> unat \<acute>bits___unsigned);;
    \<acute>count :== \<acute>count - \<acute>bits___unsigned"

definition clz64_invariant where
  "clz64_invariant i s \<equiv> {s'.
   mask___unsigned_longlong_' s' \<ge> x___unsigned_longlong_' s'
   \<and> of_nat (word_clz (x___unsigned_longlong_' s')) + count_' s' = of_nat (word_clz (x___unsigned_longlong_' s)) + 64
   \<and> mask___unsigned_longlong_' s' = mask (2 ^ unat i)}"

lemma clz64_step:
  "unat (i :: 32 sword) < 6 \<Longrightarrow>
   \<Gamma> \<turnstile> (clz64_invariant (i+1) s) clz64_step i (clz64_invariant i s)"
  unfolding clz64_step_def
  apply (vcg, clarsimp simp: clz64_invariant_def)
  \<comment> \<open>Introduce some trivial but useful facts so that most later goals are solved with simp\<close>
  apply (prop_tac "i \<noteq> -1", clarsimp simp: unat_minus_one_word)
  apply (frule unat_Suc2)
  apply (prop_tac "(2 :: nat) ^ unat i < (64 :: nat)",
         clarsimp simp: power_strict_increasing_iff[where b=2 and y=6, simplified])
  apply (prop_tac "(2 :: nat) ^ unat (i + 1) \<le> (64 :: nat)",
         clarsimp simp: unat_Suc2 power_increasing_iff[where b=2 and y=5, simplified])
  apply (intro conjI impI; clarsimp)
       apply (clarsimp simp: word_less_nat_alt)
      apply (erule le_shiftr)
     apply (clarsimp simp: word_size shiftr_mask2 word_clz_shiftr)
    apply (clarsimp simp: shiftr_mask2)
   apply fastforce
  apply (clarsimp simp: shiftr_mask2)
  done

lemma clz64_spec:
  "\<forall>s. \<Gamma> \<turnstile> {s} Call clz64_'proc \<lbrace>\<acute>ret__unsigned = of_nat (word_clz (x___unsigned_longlong_' s))\<rbrace>"
  apply (hoare_rule HoarePartial.ProcNoRec1)
  apply (hoarep_rewrite, fold clz64_step_def)
  apply (intro allI hoarep.Catch[OF _ hoarep.Skip])
  apply (rule_tac Q="clz64_invariant 0 s" in hoarep_Seq_nothrow[OF _ creturn_wp])
   apply (rule HoarePartial.SeqSwap[OF clz64_step], simp, simp)+
   apply (rule conseqPre, vcg)
   apply (all \<open>clarsimp simp: clz64_invariant_def mask_def word_less_max_simp\<close>)
  apply (clarsimp simp: word_le_1)
  apply (erule disjE; clarsimp)
  apply (subst add.commute)
  apply (subst ucast_increment[symmetric])
   apply (simp add: not_max_word_iff_less)
   apply (rule word_of_nat_less)
   apply (rule le_less_trans[OF word_clz_max])
   apply (simp add: word_size unat_max_word)
  apply clarsimp
  done

definition ctz32_step where
  "ctz32_step i \<equiv> \<acute>mask___unsigned :== \<acute>mask___unsigned >> unat ((1::32 sword) << unat i);;
                   \<acute>bits___unsigned :== SCAST(32 signed \<rightarrow> 32) (if \<acute>x___unsigned && \<acute>mask___unsigned = SCAST(32 signed \<rightarrow> 32) 0 then 1 else 0) << unat i;;
                   Guard ShiftError \<lbrace>\<acute>bits___unsigned < SCAST(32 signed \<rightarrow> 32) 0x20\<rbrace> (\<acute>x___unsigned :== \<acute>x___unsigned >> unat \<acute>bits___unsigned);;
                   \<acute>count :== \<acute>count + \<acute>bits___unsigned"

definition ctz32_invariant where
  "ctz32_invariant (i :: 32 sword) s \<equiv> {s'.
     (x___unsigned_' s' \<noteq> 0 \<longrightarrow> (of_nat (word_ctz (x___unsigned_' s')) + count_' s' = of_nat (word_ctz (x___unsigned_' s))
   \<and> (word_ctz (x___unsigned_' s') < 2 ^ unat i)))
   \<and> (x___unsigned_' s' = 0 \<longrightarrow> (count_' s' + (0x1 << (unat i)) = 33 \<and> x___unsigned_' s = 0))
   \<and> mask___unsigned_' s' = mask (2 ^ unat i)}"

lemma ctz32_step:
  "unat (i :: 32 sword) < 5 \<Longrightarrow>
   \<Gamma> \<turnstile> (ctz32_invariant (i+1) s) ctz32_step i (ctz32_invariant i s)"
  supply word_neq_0_conv [simp del]
  unfolding ctz32_step_def
  apply (vcg, clarsimp simp: ctz32_invariant_def)
  apply (prop_tac "i \<noteq> -1", clarsimp simp: unat_minus_one_word)
  apply (frule unat_Suc2)
  apply (prop_tac "(2 :: nat) ^ unat i < (32 :: nat)",
         clarsimp simp: power_strict_increasing_iff[where b=2 and y=5, simplified])
  apply (prop_tac "(2 :: nat) ^ unat (i + 1) \<le> (32 :: nat)",
         clarsimp simp: unat_Suc2 power_increasing_iff[where b=2 and y=4, simplified])
  apply (intro conjI; intro impI)
   apply (intro conjI)
      apply (clarsimp simp: word_less_nat_alt)
     apply (intro impI)
     apply (subgoal_tac "x___unsigned_' x \<noteq> 0")
      apply (intro conjI, clarsimp)
       apply (subst word_ctz_shiftr, clarsimp, clarsimp)
        apply (rule word_ctz_bound_below, clarsimp simp: shiftr_mask2)
        apply (clarsimp simp: shiftr_mask2 is_aligned_mask[symmetric])
       apply (subst of_nat_diff)
        apply (rule word_ctz_bound_below, clarsimp simp: shiftr_mask2)
        apply (clarsimp simp: shiftr_mask2)
       apply fastforce
      apply (subst word_ctz_shiftr, clarsimp, clarsimp)
       apply (rule word_ctz_bound_below, clarsimp simp: shiftr_mask2)
       apply (clarsimp simp: shiftr_mask2 is_aligned_mask[symmetric])
      apply (fastforce elim: is_aligned_weaken)
     apply fastforce
    apply (intro impI conjI; clarsimp simp: shiftr_mask2)
     apply (subgoal_tac "x___unsigned_' x = 0", clarsimp)
      apply (subst add.commute, simp)
     apply (fastforce simp: shiftr_mask2 word_neq_0_conv and_mask_eq_iff_shiftr_0[symmetric])
    apply (simp add: and_mask_eq_iff_shiftr_0[symmetric])
   apply (clarsimp simp: shiftr_mask2)
  by (fastforce simp: shiftr_mask2 intro: word_ctz_bound_above)

lemma ctz32_spec:
  "\<forall>s. \<Gamma> \<turnstile> {s} Call ctz32_'proc \<lbrace>\<acute>ret__unsigned = of_nat (word_ctz (x___unsigned_' s))\<rbrace>"
  supply word_neq_0_conv [simp del]
  apply (hoare_rule HoarePartial.ProcNoRec1)
  apply (hoarep_rewrite, fold ctz32_step_def)
  apply (intro allI hoarep.Catch[OF _ hoarep.Skip])
  apply (rule_tac Q="ctz32_invariant 0 s" in hoarep_Seq_nothrow[OF _ creturn_wp])
   apply (rule HoarePartial.SeqSwap[OF ctz32_step], simp, simp)+
   apply (rule conseqPre, vcg)
   apply (clarsimp simp: ctz32_invariant_def)
   apply (clarsimp simp: mask_def)
   apply (subgoal_tac "word_ctz (x___unsigned_' s) \<le> size (x___unsigned_' s)")
    apply (clarsimp simp: word_size)
  using word_ctz_len_word_and_mask_zero apply force
   apply (rule word_ctz_max)
  apply (clarsimp simp: ctz32_invariant_def)
  apply (case_tac "x___unsigned_' x = 0"; clarsimp)
  done

definition ctz64_step where
  "ctz64_step i \<equiv> \<acute>mask___unsigned_longlong :== \<acute>mask___unsigned_longlong >> unat ((1::32 sword) << unat i);;
                   \<acute>bits___unsigned :== SCAST(32 signed \<rightarrow> 32) (if \<acute>x___unsigned_longlong && \<acute>mask___unsigned_longlong = SCAST(32 signed \<rightarrow> 64) 0 then 1 else 0) << unat i;;
                   Guard ShiftError \<lbrace>\<acute>bits___unsigned < SCAST(32 signed \<rightarrow> 32) 0x40\<rbrace> (\<acute>x___unsigned_longlong :== \<acute>x___unsigned_longlong >> unat \<acute>bits___unsigned);;
                   \<acute>count :== \<acute>count + \<acute>bits___unsigned"

definition ctz64_invariant where
  "ctz64_invariant i s \<equiv> {s'.
     (x___unsigned_longlong_' s' \<noteq> 0 \<longrightarrow> (of_nat (word_ctz (x___unsigned_longlong_' s')) + count_' s' = of_nat (word_ctz (x___unsigned_longlong_' s))
   \<and> (word_ctz (x___unsigned_longlong_' s') < 2 ^ unat i)))
   \<and> (x___unsigned_longlong_' s' = 0 \<longrightarrow> (count_' s' + (0x1 << (unat i)) = 65 \<and> x___unsigned_longlong_' s = 0))
   \<and> mask___unsigned_longlong_' s' = mask (2 ^ unat i)}"

lemma ctz64_step:
  "unat (i :: 32 sword) < 6 \<Longrightarrow>
   \<Gamma> \<turnstile> (ctz64_invariant (i+1) s) ctz64_step i (ctz64_invariant i s)"
supply word_neq_0_conv [simp del]
  unfolding ctz64_step_def
  apply (vcg, clarsimp simp: ctz64_invariant_def)
  apply (prop_tac "i \<noteq> -1", clarsimp simp: unat_minus_one_word)
  apply (frule unat_Suc2)
  apply (prop_tac "(2 :: nat) ^ unat i < (64 :: nat)",
         clarsimp simp: power_strict_increasing_iff[where b=2 and y=6, simplified])
  apply (prop_tac "(2 :: nat) ^ unat (i + 1) \<le> (64 :: nat)",
         clarsimp simp: unat_Suc2 power_increasing_iff[where b=2 and y=5, simplified])
  apply (intro conjI; intro impI)
   apply (intro conjI)
      apply (clarsimp simp: word_less_nat_alt)
     apply (intro impI)
     apply (subgoal_tac "x___unsigned_longlong_' x \<noteq> 0")
      apply (intro conjI, clarsimp)
       apply (subst word_ctz_shiftr, clarsimp, clarsimp)
        apply (rule word_ctz_bound_below, clarsimp simp: shiftr_mask2)
        apply (clarsimp simp: shiftr_mask2 is_aligned_mask[symmetric])
       apply (subst of_nat_diff)
        apply (rule word_ctz_bound_below, clarsimp simp: shiftr_mask2)
        apply (clarsimp simp: shiftr_mask2)
     apply fastforce
      apply (subst word_ctz_shiftr, clarsimp, clarsimp)
       apply (rule word_ctz_bound_below, clarsimp simp: shiftr_mask2)
       apply (clarsimp simp: shiftr_mask2 is_aligned_mask[symmetric])
      apply (fastforce elim: is_aligned_weaken)
     apply fastforce
    apply (intro impI conjI; clarsimp simp: shiftr_mask2)
     apply (subgoal_tac "x___unsigned_longlong_' x = 0", clarsimp)
      apply (subst add.commute, simp)
     apply (fastforce simp: shiftr_mask2 word_neq_0_conv and_mask_eq_iff_shiftr_0[symmetric])
    apply (simp add: and_mask_eq_iff_shiftr_0[symmetric])
   apply (clarsimp simp: shiftr_mask2)
  by (fastforce simp: shiftr_mask2 intro: word_ctz_bound_above)

lemma ctz64_spec:
  "\<forall>s. \<Gamma> \<turnstile> {s} Call ctz64_'proc \<lbrace>\<acute>ret__unsigned = of_nat (word_ctz (x___unsigned_longlong_' s))\<rbrace>"
  apply (hoare_rule HoarePartial.ProcNoRec1)
  apply (hoarep_rewrite, fold ctz64_step_def)
  apply (intro allI hoarep.Catch[OF _ hoarep.Skip])
  apply (rule_tac Q="ctz64_invariant 0 s" in hoarep_Seq_nothrow[OF _ creturn_wp])
   apply (rule HoarePartial.SeqSwap[OF ctz64_step], simp, simp)+
   apply (rule conseqPre, vcg)
   apply (clarsimp simp: ctz64_invariant_def)
   apply (clarsimp simp: mask_def)
   apply (subgoal_tac "word_ctz (x___unsigned_longlong_' s) \<le> size (x___unsigned_longlong_' s)")
    apply (clarsimp simp: word_size)
    apply (erule le_neq_trans, clarsimp)
    using word_ctz_len_word_and_mask_zero[where 'a=64] apply force
   apply (rule word_ctz_max)
  apply (clarsimp simp: ctz64_invariant_def)
  apply (case_tac "x___unsigned_longlong_' x = 0"; clarsimp)
  done

(* On AArch64, clzl and ctzl use compiler builtins and hence these are rephrasings of
   Kernel_C.clzl_spec.clzl_spec and Kernel_C.ctzl_spec.ctzl_spec to omit "symbol_table" *)

lemma clzl_spec:
  "\<forall>s. \<Gamma> \<turnstile> {\<sigma>. s = \<sigma> \<and> x___unsigned_long_' s \<noteq> 0} Call clzl_'proc
       \<lbrace>\<acute>ret__long = of_nat (word_clz (x___unsigned_long_' s))\<rbrace>"
  apply (rule allI, rule conseqPre, vcg)
  apply clarsimp
  apply (rule_tac x="ret__long_'_update f x" for f in exI)
  apply (simp add: mex_def meq_def)
  done

lemma ctzl_spec:
  "\<forall>s. \<Gamma> \<turnstile> {\<sigma>. s = \<sigma> \<and> x___unsigned_long_' s \<noteq> 0} Call ctzl_'proc
       \<lbrace>\<acute>ret__long = of_nat (word_ctz (x___unsigned_long_' s))\<rbrace>"
  apply (rule allI, rule conseqPre, vcg)
  apply clarsimp
  apply (rule_tac x="ret__long_'_update f x" for f in exI)
  apply (simp add: mex_def meq_def)
  done

(* FIXME AARCH64 there are a whole lot of cache op lemmas on ARM_HYP, e.g.
     cleanCaches_PoU_ccorres, branchFlushRange_ccorres, invalidateCacheRange_I_ccorres,
     invalidateCacheRange_RAM_ccorres, cleanCacheRange_PoU_ccorres, etc.
     We'll probably need some of these. *)

end
end
