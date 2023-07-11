fn my_function(
  /* 'ptr<function,i32,read_write>' is the type of a pointer value that references
     memory for keeping an 'i32' value, using memory locations in the 'function'
     address space.  Here 'i32' is the store type.
     The implied access mode is 'read_write'.
     See "Address Space" section for defaults. */
  ptr_int: ptr<function,i32>,

  // 'ptr<private,array<f32,50>,read_write>' is the type of a pointer value that
  // refers to memory for keeping an array of 50 elements of type 'f32', using
  // memory locations in the 'private' address space.
  // Here the store type is 'array<f32,50>'.
  // The implied access mode is 'read_write'.
  // See the "Address space section for defaults.
  ptr_array: ptr<private, array<f32, 50>>
) { }
