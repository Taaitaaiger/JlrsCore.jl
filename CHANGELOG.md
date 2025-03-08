#### v0.6.0

- Support for Julia versions younger than the current LTS (1.10) has been dropped.

- JlrsLedger has been updated to 0.2.0.

- Reflected bits union fields can now be annotated with type information.

- `JLRS_API_VERSION` is now 4.

#### v0.5.0

- Bindings for enums that have an integer `BaseType` can be generated with `Reflect.reflect`.

- Several bugs have been fixed for exported functions with type parameters.

- Performance of `Reflect.reflect` has been improved significantly.

#### v0.4.0

- `RustResult` has been removed.

- Support for async callbacks and their thread pools have been removed.

- `Reflect.reflect` skips generating bindings for mutable types that are only used as field types, i.e. `Reflect.reflect([T])` now only generates bindings that are necessary to represent the layout of `T`.

- The `internaltypes` keyword argument has been removed from `Reflect.reflect` because jlrs has dropped support for these types. `Expr` has been promoted to a "regular" managed type, other internal types now map to `Option<ValueRef>`.

- `Wrap.@wrapmodule` supports generating functions that are generic over one or more parameters, and restricting those parameters.

- `BackgroundTask` and `DelegatedTask` replace the old async callbacks.

- `JLRS_API_VERSION` is now 3.

#### v0.3.0

- The `IsBits` trait is derived for layout types by `Reflect.reflect` if the type it reflects is an `isbits` type when all type parameters that affect the layout are `isbits` types.

- If a separate type constructor is generated for a type by `Reflect.reflect`, it's annotated with several additional attributes to implement the `HasLayout` trait that connects the type constructor to its layout.

- The `CCallReturn` trait is only derived for `isbits` types.

- Async functions exported by with the `julia_module` macro in jlrs return their result directly.

- `JLRS_API_VERSION` is now 2.


#### v0.2.0

- Upgrade JlrsLedger to v0.1.0

- `Ledger.LEDGER_API_VERSION` is now 2: `Ledger.PoisonError` has been removed, and `Ledger.unborrow_shared` returns `true` if there are no remaining shared borrows or `false` otherwise.
