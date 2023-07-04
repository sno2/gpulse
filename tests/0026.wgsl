struct S {
    age: i32,
    weight: f32
}
var<private> person: S;
// Elsewhere, 'person' denotes the reference to the memory underlying the variable,
// and will have type ref<private,S,read_write>.

fn f() {
    var uv: vec2<f32>;
    // For the remainder of this function body, 'uv' denotes the reference
    // to the memory underlying the variable, and will have type
    // ref<function,vec2<f32>,read_write>.

    // Evaluate the left-hand side of the assignment:
    //   Evaluate 'uv.x' to yield a reference:
    //   1. First evaluate 'uv', yielding a reference to the memory for
    //      the 'uv' variable. The result has type ref<function,vec2<f32>,read_write>.
    //   2. Then apply the '.x' vector access phrase, yielding a reference to
    //      the memory for the first component of the vector pointed at by the
    //      reference value from the previous step.
    //      The result has type ref<function,f32,read_write>.
    // Evaluating the right-hand side of the assignment yields the f32 value 1.0.
    // Store the f32 value 1.0 into the storage memory locations referenced by uv.x.
    uv.x = 1.0;

    // Evaluate the left-hand side of the assignment:
    //   Evaluate 'uv[1]' to yield a reference:
    //   1. First evaluate 'uv', yielding a reference to the memory for
    //      the 'uv' variable. The result has type ref<function,vec2<f32>,read_write>.
    //   2. Then apply the '[1]' array index phrase, yielding a reference to
    //      the memory for second component of the vector referenced from
    //      the previous step.  The result has type ref<function,f32,read_write>.
    // Evaluating the right-hand side of the assignment yields the f32 value 2.0.
    // Store the f32 value 2.0 into the storage memory locations referenced by uv[1].
    uv[1] = 2.0;

    var m: mat3x2<f32>;
    // When evaluating 'm[2]':
    // 1. First evaluate 'm', yielding a reference to the memory for
    //    the 'm' variable. The result has type ref<function,mat3x2<f32>,read_write>.
    // 2. Then apply the '[2]' array index phrase, yielding a reference to
    //    the memory for the third column vector pointed at by the reference
    //    value from the previous step.
    //    Therefore the 'm[2]' expression has type ref<function,vec2<f32>,read_write>.
    // The 'let' declaration is for type vec2<f32>, so the declaration
    // statement requires the initializer to be of type vec2<f32>.
    // The Load Rule applies (because no other type rule can apply), and
    // the evaluation of the initializer yields the vec2<f32> value loaded
    // from the memory locations referenced by 'm[2]' at the time the declaration
    // is executed.
    let p_m_col2: vec2<f32> = m[2];

    var A: array<i32,5>;
    // When evaluating 'A[4]'
    // 1. First evaluate 'A', yielding a reference to the memory for
    //    the 'A' variable. The result has type ref<function,array<i32,5>,read_write>.
    // 2. Then apply the '[4]' array index phrase, yielding a reference to
    //    the memory for the fifth element of the array referenced by
    //    the reference value from the previous step.
    //    The result value has type ref<function,i32,read_write>.
    // The let-declaration requires the right-hand-side to be of type i32.
    // The Load Rule applies (because no other type rule can apply), and
    // the evaluation of the initializer yields the i32 value loaded from
    // the memory locations referenced by 'A[4]' at the time the declaration
    // is executed.
    let A_4_value: i32 = A[4];

    // When evaluating 'person.weight'
    // 1. First evaluate 'person', yielding a reference to the memory for
    //    the 'person' variable declared at module scope.
    //    The result has type ref<private,S,read_write>.
    // 2. Then apply the '.weight' member access phrase, yielding a reference to
    //    the memory for the second member of the memory referenced by
    //    the reference value from the previous step.
    //    The result has type ref<private,f32,read_write>.
    // The let-declaration requires the right-hand-side to be of type f32.
    // The Load Rule applies (because no other type rule can apply), and
    // the evaluation of the initializer yields the f32 value loaded from
    // the memory locations referenced by 'person.weight' at the time the
    // declaration is executed.
    let person_weight: f32 = person.weight;
}
