package base

final case class Money(cents: Long) {
  def +(other: Money): Money = Money(cents + other.cents)
  def *(n: Int): Money = Money(cents * n)
}

object Money {
  val zero: Money = Money(0)
}

trait Show[A] {
  def show(a: A): String
}

object Show {
  given Show[Money] = m => s"${m.cents / 100}.${m.cents % 100}"
}
