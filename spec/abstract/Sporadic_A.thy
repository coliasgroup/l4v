(*
 * Copyright 2020, Data61, CSIRO (ABN 41 687 119 230)
 * Copyright 2021, UNSW (ABN 57 195 873 197)
 *
 * SPDX-License-Identifier: GPL-2.0-only
 *)

chapter "Refill Unblock Check and Sporadic Guards"

theory Sporadic_A
imports CSpaceAcc_A
begin

text \<open> This theory contains the definition of refill unblock check function and its components,
       and functions that combine various guards and a call to refill unblock check \<close>

definition
  is_round_robin :: "obj_ref \<Rightarrow> (bool,'z::state_ext) s_monad"
where
  "is_round_robin sc_ptr = do
    sc \<leftarrow> get_sched_context sc_ptr;
    return (sc_period sc = 0)
  od"

definition
  refill_pop_head :: "obj_ref \<Rightarrow> (refill, 'z::state_ext) s_monad"
where
  "refill_pop_head sc_ptr \<equiv> do
     head \<leftarrow> get_refill_head sc_ptr;
     update_sched_context sc_ptr (sc_refills_update tl);
     return head
   od"

definition
  refill_head_overlapping :: "obj_ref \<Rightarrow> (bool, 'z::state_ext) r_monad"
where
  "refill_head_overlapping sc_ptr \<equiv> do {
    sc \<leftarrow> read_sched_context sc_ptr;
    oreturn (length (sc_refills sc) > 1
             \<and> r_time (hd (tl (sc_refills sc))) \<le> r_time (refill_hd sc) + r_amount (refill_hd sc))
  }"

definition
  update_refill_hd :: "obj_ref \<Rightarrow> (refill \<Rightarrow> refill) \<Rightarrow> (unit, 'z::state_ext) s_monad"
where
  "update_refill_hd sc_ptr f = update_sched_context sc_ptr (sc_refills_update (\<lambda>refills. f (hd refills) # (tl refills)))"

definition
  "can_merge_refill r1 r2 \<equiv> r_time r2 \<le> r_time r1 + r_amount r1"

definition
  merge_refill :: "refill \<Rightarrow> refill \<Rightarrow> refill"
where
  "merge_refill r1 r2 = \<lparr> r_time = r_time r1, r_amount = r_amount r2 + r_amount r1 \<rparr>"

definition
  merge_refills :: "obj_ref \<Rightarrow> (unit, 'z::state_ext) s_monad"
where
  "merge_refills sc_ptr \<equiv> do
     head \<leftarrow> refill_pop_head sc_ptr;
     update_refill_hd sc_ptr (merge_refill head)
   od"

definition
  refill_head_overlapping_loop :: "obj_ref \<Rightarrow> (unit, 'z::state_ext) s_monad"
where
  "refill_head_overlapping_loop sc_ptr
     \<equiv> whileLoop (\<lambda>_ s. the ((refill_head_overlapping sc_ptr) s)) (\<lambda>_. merge_refills sc_ptr) ()"

definition
  refill_unblock_check :: "obj_ref \<Rightarrow> (unit, 'z::state_ext) s_monad"
where
  "refill_unblock_check sc_ptr \<equiv> do
    robin \<leftarrow> is_round_robin sc_ptr;
    ready \<leftarrow> get_sc_refill_ready sc_ptr;
    when (ready \<and> \<not>robin) $ do
      modify (\<lambda>s. s\<lparr> reprogram_timer := True \<rparr>);
      ct \<leftarrow> gets cur_time;
      update_refill_hd sc_ptr (r_time_update (\<lambda>_. ct + kernelWCET_ticks));
      refill_head_overlapping_loop sc_ptr
    od
  od"

text \<open>The function defined below encodes several patterns of conditions
      for calling @{term refill_unblock_check}.

      - this takes an option @{typ obj_ref}, and two @{typ "bool option"} parameters @{term act} and @{term ast}
      - act and ast encode the conditions for calling @{term refill_unblock_check} as follows:

            act   None       constant\_bandwidth
                  Some True    sporadic \& active
                  Some False   sporadic
            ast   None         no test or assert on cur\_sc
                  Some True    asserts that the sc pointer is not cur\_sc
                                (currently replaced by test, i.e.,
                                 identical to the Some False case below)
                  Some False   tests if the sc pointer is not cur\_sc\<close>

definition if_cond_refill_unblock_check where
  "if_cond_refill_unblock_check sc_opt active asst \<equiv>
    maybeM (\<lambda>scp. do
      sc \<leftarrow> get_sched_context scp;
      cur_sc_ptr \<leftarrow> gets cur_sc;
      guard \<leftarrow> return (case active of
                         None \<Rightarrow> (\<not> sc_sporadic sc)
                       | Some True \<Rightarrow> sc_sporadic sc \<and> sc_active sc
                       | Some False \<Rightarrow> sc_sporadic sc);
      when (guard \<and> (asst = Some False \<longrightarrow> scp \<noteq> cur_sc_ptr)) $
        when (asst = Some True \<longrightarrow> scp \<noteq> cur_sc_ptr) $ refill_unblock_check scp
    od) sc_opt"

abbreviation "if_sporadic_cur_sc_assert_refill_unblock_check sc_opt \<equiv>
                  if_cond_refill_unblock_check sc_opt (Some False) (Some True)"

abbreviation "if_sporadic_and_active_refill_unblock_check sc_opt \<equiv>
                  if_cond_refill_unblock_check sc_opt (Some True) None"

abbreviation "if_sporadic_cur_sc_test_refill_unblock_check sc_opt \<equiv>
                  if_cond_refill_unblock_check sc_opt (Some False) (Some False)"

abbreviation "if_sporadic_active_cur_sc_test_refill_unblock_check sc_opt \<equiv>
                  if_cond_refill_unblock_check sc_opt (Some True) (Some False)"

abbreviation "if_sporadic_active_cur_sc_assert_refill_unblock_check sc_opt \<equiv>
                  if_cond_refill_unblock_check sc_opt (Some True) (Some True)"

abbreviation "if_constant_bandwidth_refill_unblock_check sc_opt \<equiv>
                  if_cond_refill_unblock_check sc_opt None None"

(* check *)
thm if_cond_refill_unblock_check_def[of _ "Some False" "Some True", simplified]
thm if_cond_refill_unblock_check_def[of _ "Some True" "Some True", simplified]
thm if_cond_refill_unblock_check_def[of _ "Some False" "Some False", simplified]
thm if_cond_refill_unblock_check_def[of _ "Some True" "Some False", simplified]

end
