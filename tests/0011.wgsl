// This declaration hides the predeclared 'min' built-in function.
// Since this declaration is at module-scope, it is in scope over the entire
// source.  The built-in function is no longer accessible.
fn min() -> u32 { return 0; }

const rgba8unorm = 12; // This shadows the predeclared 'rgba8unorm' enumerant.
