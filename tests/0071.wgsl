const first_one = firstLeadingBit(1234 + 4567); // Evaluates to 12
                                                // first_one has the type i32, because
                                                // firstLeadingBit cannot operate on
                                                // AbstractInt

@id(1) override x : i32;
override y = firstLeadingBit(x); // const-expressions can be
                                 // used in override-expressions.
                                 // firstLeadingBit(x) is not a
                                 // const-expression in this context.

fn foo() {
  var a : array<i32, firstLeadingBit(257)>; // const-functions can be used in
                                            // const-expressions if all their
                                            // parameters are const-expressions.
}
