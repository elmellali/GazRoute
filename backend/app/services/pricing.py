"""Formulaic pricing engine with frozen snapshots."""
from dataclasses import dataclass
from decimal import Decimal


@dataclass(frozen=True)
class PriceQuote:
    applied_unit_price_mad: Decimal
    applied_deposit_rate_mad: Decimal
    line_subtotal_mad: Decimal
    deposit_net_impact_mad: Decimal
    total_invoice_mad: Decimal


def applied_unit_price(base_price: Decimal, override: Decimal = Decimal("0"), discount: Decimal = Decimal("0")) -> Decimal:
    return base_price + override - discount


def quote_line(
    *,
    base_price: Decimal,
    deposit_rate: Decimal,
    delivered_qty: Decimal,
    returned_qty: Decimal,
    price_override: Decimal = Decimal("0"),
    discount: Decimal = Decimal("0"),
) -> PriceQuote:
    unit = applied_unit_price(base_price, price_override, discount)
    subtotal = unit * delivered_qty
    deposit_net = (delivered_qty - returned_qty) * deposit_rate
    return PriceQuote(
        applied_unit_price_mad=unit,
        applied_deposit_rate_mad=deposit_rate,
        line_subtotal_mad=subtotal,
        deposit_net_impact_mad=deposit_net,
        total_invoice_mad=subtotal + deposit_net,
    )
