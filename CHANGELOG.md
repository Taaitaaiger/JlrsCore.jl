#### v0.3.0

- The `IsBits` trait is derived for layout types by `Reflect.reflect` if the type it reflects is an `isbits` type when all type parameters that affect the layout are `isbits` types.

- If a separate type constructor is generated for a type by `Reflect.reflect`, it's annotated with several additional attributes to implement the `HasLayout` trait that connects the type constructor to its layout.

- The `CCallReturn` trait is only derived for `isbits` types.

- Async functions exported by with the `julia_module` macro in jlrs return their result directly.

- `JLRS_API_VERSION` is now 2.


#### v0.2.0

- Upgrade JlrsLedger to v0.1.0

- `Ledger.LEDGER_API_VERSION` is now 2: `Ledger.PoisonError` has been removed, and `Ledger.unborrow_shared` returns `true` if there are no remaining shared borrows or `false` otherwise.
