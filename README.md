# gpulse

An LSP for the WebGPU Shader Language (WGSL).

## Goals

- Spec 1:1 Compliance
- Maintain a small binary size
- High performance

## Why not [naga](https://github.com/gfx-rs/naga)?

Although naga is a great project, it lacks support for many of the basic
features included in WGSL such as global constants, constant type interpolation,
proper template parsing, type validation, and does not follow the specification
in many cases regarding types which I find annoying when writing code
specifically for WGSL.

Separating the projects will hopefully allow us to focus on building and
maintaining a WGSL tool that will be updated with each specification update.

## Coverage

gpulse implements the WebGPU Shading Language spec from June 26, 2023.

We pull code examples from the WGSL Specification and the
[Tour of WGSL](https://github.com/google/tour-of-wgsl) repository for tests.
Please consider creating an issue if you have a large codebase with WGSL code to
strengthen our test suite.

See the [tests/_manifest.stat file](./tests/_manifest.stat) for the current
coverage status.

## License

[MIT](./LICENSE)
