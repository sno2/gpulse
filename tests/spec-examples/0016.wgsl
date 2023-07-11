override blockSize = 16;

var<workgroup> odds: array<i32,blockSize>;
var<workgroup> evens: array<i32,blockSize>; // Same type

// None of the following have the same type as 'odds' and 'evens'.

// Different type: Not the identifier 'blockSize'
var<workgroup> evens_0: array<i32,16>;
// Different type: Uses arithmetic to express the element count.
var<workgroup> evens_1: array<i32,(blockSize * 2 / 2)>;
// Different type: Uses parentheses, not just an identifier.
var<workgroup> evens_2: array<i32,(blockSize)>;

// An invalid example, because the overridable element count may only occur
// at the outer level.
// var<workgroup> both: array<array<i32,blockSize>,2>;

// An invalid example, because the overridable element count is only
// valid for workgroup variables.
// var<private> bad_address_space: array<i32,blockSize>;
