package api

import base.Money

final case class Customer(id: Long, name: String, credit: Money)

final case class Line(sku: String, qty: Int, price: Money)

trait Repo {
  def customer(id: Long): Option[Customer]
  def lines(customerId: Long): List[Line]
}
