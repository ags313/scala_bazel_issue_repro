Issue:

# tl;dr:

Scala 3 dependency analyzer seems to do excessive checks - once for each compilation unit, re-analyse every compilation
unit of the target   
attached patch fixes this

## show me the error:

```shell
bazelisk build //violation:lib
```

prints same error, many times

```text
INFO: Analyzed target //violation:lib (144 packages loaded, 4223 targets configured).
(...)
-- Error: bazel-out/k8-fastbuild/bin/violation/gen/Order0000.scala:4:7 ---------
4 |import base.{Money, Show}
  |^^^^^^^^^^^^^^^^^^^^^^^^^
  |Target '//modules/base:base' is used but isn't explicitly declared, please add it to the deps.
  |You can use the following buildozer command:
  |buildozer 'add deps //modules/base:base' //violation:lib
-- Error: bazel-out/k8-fastbuild/bin/violation/gen/Order0000.scala:4:7 ---------
4 |import base.{Money, Show}
  |^^^^^^^^^^^^^^^^^^^^^^^^^
  |Target '//modules/base:base' is used but isn't explicitly declared, please add it to the deps.
  |You can use the following buildozer command:
  |buildozer 'add deps //modules/base:base' //violation:lib
-- Error: bazel-out/k8-fastbuild/bin/violation/gen/Order0000.scala:4:7 ---------
4 |import base.{Money, Show}
  |^^^^^^^^^^^^^^^^^^^^^^^^^
  |Target '//modules/base:base' is used but isn't explicitly declared, please add it to the deps.
  |You can use the following buildozer command:
  |buildozer 'add deps //modules/base:base' //violation:lib
-- Error: bazel-out/k8-fastbuild/bin/violation/gen/Order0000.scala:4:7 ---------
4 |import base.{Money, Show}
  |^^^^^^^^^^^^^^^^^^^^^^^^^
  |Target '//modules/base:base' is used but isn't explicitly declared, please add it to the deps.
  |You can use the following buildozer command:
  |buildozer 'add deps //modules/base:base' //violation:lib
-- Error: bazel-out/k8-fastbuild/bin/violation/gen/Order0000.scala:4:7 ---------
4 |import base.{Money, Show}
  |^^^^^^^^^^^^^^^^^^^^^^^^^
  |Target '//modules/base:base' is used but isn't explicitly declared, please add it to the deps.
  |You can use the following buildozer command:
  |buildozer 'add deps //modules/base:base' //violation:lib
-- Error: bazel-out/k8-fastbuild/bin/violation/gen/Order0000.scala:4:7 ---------
4 |import base.{Money, Show}
  |^^^^^^^^^^^^^^^^^^^^^^^^^
  |Target '//modules/base:base' is used but isn't explicitly declared, please add it to the deps.
  |You can use the following buildozer command:
  |buildozer 'add deps //modules/base:base' //violation:lib
-- Error: bazel-out/k8-fastbuild/bin/violation/gen/Order0000.scala:4:7 ---------
4 |import base.{Money, Show}
  |^^^^^^^^^^^^^^^^^^^^^^^^^
  |Target '//modules/base:base' is used but isn't explicitly declared, please add it to the deps.
  |You can use the following buildozer command:
  |buildozer 'add deps //modules/base:base' //violation:lib
-- Error: bazel-out/k8-fastbuild/bin/violation/gen/Order0000.scala:4:7 ---------
4 |import base.{Money, Show}
  |^^^^^^^^^^^^^^^^^^^^^^^^^
  |Target '//modules/base:base' is used but isn't explicitly declared, please add it to the deps.
  |You can use the following buildozer command:
  |buildozer 'add deps //modules/base:base' //violation:lib
-- Error: bazel-out/k8-fastbuild/bin/violation/gen/Order0000.scala:4:7 ---------
4 |import base.{Money, Show}
  |^^^^^^^^^^^^^^^^^^^^^^^^^
  |Target '//modules/base:base' is used but isn't explicitly declared, please add it to the deps.
  |You can use the following buildozer command:
  |buildozer 'add deps //modules/base:base' //violation:lib
-- Error: bazel-out/k8-fastbuild/bin/violation/gen/Order0000.scala:4:7 ---------
4 |import base.{Money, Show}
  |^^^^^^^^^^^^^^^^^^^^^^^^^
  |Target '//modules/base:base' is used but isn't explicitly declared, please add it to the deps.
  |You can use the following buildozer command:
  |buildozer 'add deps //modules/base:base' //violation:lib
10 errors found
Build failure with errors.
Target //violation:lib failed to build
Use --verbose_failures to see the command lines of failed build steps.
INFO: Elapsed time: 1.104s, Critical Path: 0.68s
INFO: 5 processes: 167 action cache hit, 2 internal, 3 worker.
ERROR: Build did NOT complete successfully
```

## show me the fix:

```shell
cat >> MODULE.bazel <<'EOF'

single_version_override(
    module_name = "rules_scala",
    patch_strip = 1,
    patches = ["//patches:rules_scala_analyze_once_per_run.patch"],
)
EOF

bazelisk build //violation:lib
```

error will be printed once

```text
INFO: Analyzed target //violation:lib (144 packages loaded, 4223 targets configured).
(...)
-- Error: bazel-out/k8-fastbuild/bin/violation/gen/Order0000.scala:4:7 ---------
4 |import base.{Money, Show}
  |^^^^^^^^^^^^^^^^^^^^^^^^^
  |Target '//modules/base:base' is used but isn't explicitly declared, please add it to the deps.
  |You can use the following buildozer command:
  |buildozer 'add deps //modules/base:base' //violation:lib
1 error found
Build failure with errors.
Target //violation:lib failed to build
Use --verbose_failures to see the command lines of failed build steps.
INFO: Elapsed time: 1.030s, Critical Path: 0.58s
INFO: 5 processes: 167 action cache hit, 2 internal, 3 worker.
ERROR: Build did NOT complete successfully
```

# longer:

I tried converting an existing project to bazel.
Run "find unused dependencies", and it took "a very long time" (10+ minutes).

# the fix:

`patches/rules_scala_analyze_once_per_run.patch`: run the analysis once per `Run`.

# benchmark (how much does it help):

Speedup with 400 generated files:

- `dependency_tracking_method = "ast",`, default took 84s, patched brought it down to ~5.3s.
- `dependency_tracking_method = "high-level",`, default 9.2s, patches 5.3s

Don't trust me, run `bench.sh` yourself.

| variant | method     | files | duration (s) |
|---------|------------|-------|--------------|
| stock   | off        | 10    | 0.2          |
| stock   | off        | 25    | 0.4          |
| stock   | off        | 50    | 0.7          |
| stock   | off        | 100   | 1.6          |
| stock   | off        | 200   | 2.9          |
| stock   | off        | 400   | 5.1          |
| stock   | ast        | 10    | 0.3          |
| stock   | ast        | 25    | 0.7          |
| stock   | ast        | 50    | 1.7          |
| stock   | ast        | 100   | 5.7          |
| stock   | ast        | 200   | 19.9         |
| stock   | ast        | 400   | 84           |
| stock   | high_level | 10    | 0.4          |
| stock   | high_level | 25    | 0.8          |
| stock   | high_level | 50    | 1.4          |
| stock   | high_level | 100   | 2.5          |
| stock   | high_level | 200   | 4.6          |
| stock   | high_level | 400   | 9.2          |
| patched | off        | 10    | 0.2          |
| patched | off        | 25    | 0.5          |
| patched | off        | 50    | 0.8          |
| patched | off        | 100   | 1.6          |
| patched | off        | 200   | 2.9          |
| patched | off        | 400   | 5.1          |
| patched | ast        | 10    | 0.3          |
| patched | ast        | 25    | 0.4          |
| patched | ast        | 50    | 0.9          |
| patched | ast        | 100   | 1.5          |
| patched | ast        | 200   | 2.9          |
| patched | ast        | 400   | 5.3          |
| patched | high_level | 10    | 0.3          |
| patched | high_level | 25    | 0.5          |
| patched | high_level | 50    | 0.9          |
| patched | high_level | 100   | 1.6          |
| patched | high_level | 200   | 2.8          |
| patched | high_level | 400   | 5.3          |

# contents:

modules:

- api
- base

`gen.bzl` is a hand rolled generator of sources

AI disclosure:
I have used AI to help generate demonstrator.
And to question my thinking.