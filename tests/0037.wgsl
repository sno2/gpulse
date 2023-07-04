fn fun() {
   var extracted_values: array<i32,2>;
   const v = vec2<i32>(0,1);

   for (var i: i32 = 0; i < 2 ; i++) {
      // A runtime-expression used to index a vector, but outside the
      // indexing bounds of the vector, produces an indeterminate value
      // of the vector component type.
      let extract = v[i+5];

      // Now 'extract' is any value of type i32.

      // Save it for later.
      extracted_values[i] = extract;

      if extract == extract {
         // This is always executed
      }
      if extract < 2 {
         // This might be executed, but might not be executed.
         // Even though the original vector components are 0 and 1,
         // the extracted value might not be either of those values.
      }
   }
   if extracted_value[0] == extracted_values[1] {
      // This might be executed, but might not be executed.
   }
}

fn float_fun(runtime_index: u32) {
   const v = vec2<f32>(0,1); // A vector of floating point values

   // As in the previous example, 'float_extract' is an indeterminate value.
   // Since it is a floating point type, it may be a NaN.
   let float_extract: f32 = v[runtime_index+5];

   if float_extract == float_extract {
      // This *might not* be executed, because:
      //  -  'float_extract' may be NaN, and
      //  -  a NaN is never equal to any other floating point number,
      //     even another NaN.
   }
}
