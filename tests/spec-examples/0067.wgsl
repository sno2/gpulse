fn continue_end_of_loop_body() {
  for (var i: i32 = 0; i < 5; i++ ) {
    continue;   // Valid. This is redundant,
                //   branching to the end of the loop body.
  }             // Behavior: {Next},
                //   as loops absorb "Continue",
                //   and "for" loops always add "Next"
}
