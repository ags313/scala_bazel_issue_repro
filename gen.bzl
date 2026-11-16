"""Generates `count` Scala files of the same shape, so one target can be scaled up and down."""

SaltInfo = provider(doc = "Value of //:salt", fields = ["value"])

def _salt_impl(ctx):
    return SaltInfo(value = ctx.build_setting_value)

# `--//:salt=<anything new>` changes every generated file, which forces a recompile without
# `bazel clean` (and keeps the warm Scalac worker).
salt = rule(
    implementation = _salt_impl,
    build_setting = config.string(flag = True),
)

_HEADER = """package @PKG@

import api.{Customer, Line, Repo}
import base.{Money, Show}

// salt: @SALT@
final case class @CLS@(id: Long, customer: Customer, lines: List[Line]) {
  def total: Money = lines.foldLeft(Money.zero)((acc, l) => acc + l.price * l.qty)
}

object @CLS@ {
"""

# One method each; @K@ is the method index, so every method is distinct.
_METHODS = [
    """
  def find@K@(repo: Repo, id: Long): Option[@CLS@] =
    for {
      c <- repo.customer(id + @K@)
      ls = repo.lines(c.id).filter(_.qty > @K@)
    } yield @CLS@(id, c, ls)
""",
    """
  def render@K@(o: @CLS@)(using s: Show[Money]): String =
    o.lines.map(l => s"${l.sku}:${l.qty}:${s.show(l.price)}").mkString("@K@:", ",", "")
""",
    """
  def group@K@(xs: List[Int]): Map[String, Int] =
    xs.filter(_ % 2 == 1).groupBy(x => s"k${x % (@K@ + 1)}").view.mapValues(_.sum).toMap
""",
    """
  def check@K@(o: @CLS@): Either[String, Money] =
    o.total match {
      case Money(c) if c > @K@ => Right(Money(c))
      case other => Left(summon[Show[Money]].show(other))
    }
""",
]

def _source(pkg, cls, methods, salt):
    body = [_HEADER]
    for k in range(methods):
        body.append(_METHODS[k % len(_METHODS)].replace("@K@", str(k)))
    body.append("}\n")
    return "".join(body).replace("@PKG@", pkg).replace("@CLS@", cls).replace("@SALT@", salt)

def _generated_scala_impl(ctx):
    salt = ctx.attr._salt[SaltInfo].value
    outs = []
    for i in range(ctx.attr.count):
        cls = "Order" + ("000" + str(i))[-4:]
        out = ctx.actions.declare_file("%s/%s.scala" % (ctx.label.name, cls))
        ctx.actions.write(out, _source(ctx.attr.package, cls, ctx.attr.methods, salt))
        outs.append(out)
    return [DefaultInfo(files = depset(outs))]

generated_scala = rule(
    implementation = _generated_scala_impl,
    attrs = {
        "count": attr.int(mandatory = True, doc = "Number of .scala files"),
        "methods": attr.int(default = 24, doc = "Methods per file (~4 lines each)"),
        "package": attr.string(mandatory = True),
        "_salt": attr.label(default = "//:salt"),
    },
)
