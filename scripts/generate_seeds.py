#!/usr/bin/env python3
"""Generate realistic seed CSVs with intentional data-quality errors for dbt tests."""

from __future__ import annotations

import csv
import random
from datetime import date, datetime, timedelta
from pathlib import Path

SEED = 42
random.seed(SEED)

OUT = Path(__file__).resolve().parents[1] / "dbt_demo" / "seeds"
OUT.mkdir(parents=True, exist_ok=True)

COUNTRIES = ["DE", "AT", "CH", "PL", "NL", "FR", "IT", "ES", "CZ", "BE"]
STATUSES = ["active", "inactive", "pending", "blocked"]
CATEGORIES = ["electronics", "clothing", "home", "sports", "books", "beauty", "toys"]
ORDER_STATUSES = ["completed", "pending", "cancelled", "returned"]
PAYMENT_METHODS = ["card", "paypal", "bank_transfer"]
SHIPMENT_STATUSES = ["pending", "shipped", "delivered", "returned"]
PRODUCT_NAMES = [
    "Wireless Mouse", "USB-C Hub", "Cotton T-Shirt", "Running Shoes", "Desk Lamp",
    "Yoga Mat", "Coffee Maker", "Bluetooth Speaker", "Backpack", "Notebook Set",
    "Water Bottle", "Keyboard", "Monitor Stand", "Winter Jacket", "Hiking Boots",
    "Smart Watch", "Phone Case", "Wall Clock", "Board Game", "Face Cream",
]


def write_csv(name: str, fieldnames: list[str], rows: list[dict]) -> None:
    path = OUT / name
    with path.open("w", newline="", encoding="utf-8") as f:
        writer = csv.DictWriter(f, fieldnames=fieldnames)
        writer.writeheader()
        writer.writerows(rows)
    print(f"Wrote {len(rows)} rows → {path}")


def gen_users(n: int = 80) -> list[dict]:
    rows = []
    base = datetime(2024, 1, 1)
    for i in range(1, n + 1):
        rows.append(
            {
                "user_id": i,
                "email": f"user{i}@example.com",
                "country": random.choice(COUNTRIES),
                "status": random.choice(STATUSES),
                "created_at": (base + timedelta(days=i % 300, hours=i % 24)).strftime(
                    "%Y-%m-%d %H:%M:%S"
                ),
            }
        )

    # Intentional errors for unique / not_null tests:
    # 1) duplicate user_id
    rows.append(
        {
            "user_id": 1,
            "email": "duplicate.user1@example.com",
            "country": "DE",
            "status": "active",
            "created_at": "2024-06-15 10:00:00",
        }
    )
    # 2) empty email (not_null + unique will fail)
    rows.append(
        {
            "user_id": 9999,
            "email": "",
            "country": "PL",
            "status": "pending",
            "created_at": "2024-07-01 12:00:00",
        }
    )
    return rows


def gen_products(n: int = 60) -> list[dict]:
    rows = []
    for i in range(1, n + 1):
        cat = CATEGORIES[i % len(CATEGORIES)]
        name = PRODUCT_NAMES[i % len(PRODUCT_NAMES)]
        rows.append(
            {
                "product_id": i,
                "product_name": f"{name} #{i}",
                "category": cat,
                "price": round(random.uniform(5.0, 299.99), 2),
            }
        )
    return rows


def gen_orders(n: int = 100) -> list[dict]:
    rows = []
    start = date(2024, 6, 1)
    for i in range(1, n + 1):
        rows.append(
            {
                "order_id": i,
                "user_id": random.randint(1, 80),
                "order_date": (start + timedelta(days=i % 90)).isoformat(),
                "order_status": random.choice(ORDER_STATUSES),
                "total_amount": round(random.uniform(15.0, 800.0), 2),
            }
        )
    # Intentional error: accepted_values will fail
    rows.append(
        {
            "order_id": 9998,
            "user_id": 5,
            "order_date": "2024-08-20",
            "order_status": "invalid_unknown_status",
            "total_amount": 42.50,
        }
    )
    return rows


def gen_order_items(orders: list[dict], n_products: int = 60) -> list[dict]:
    rows = []
    item_id = 1
    for order in orders:
        # skip generating many items for the invalid status order — still add 1
        n_items = 1 if order["order_id"] == 9998 else random.randint(1, 4)
        for _ in range(n_items):
            product_id = random.randint(1, n_products)
            qty = random.randint(1, 5)
            unit_price = round(random.uniform(5.0, 199.99), 2)
            rows.append(
                {
                    "item_id": item_id,
                    "order_id": order["order_id"],
                    "product_id": product_id,
                    "quantity": qty,
                    "unit_price": unit_price,
                }
            )
            item_id += 1
    return rows


def gen_payments(orders: list[dict], n: int = 40) -> list[dict]:
    """Payments seed for demo_showcase: fresh loaded_at (source freshness PASS) + DQ issues."""
    now = datetime.now().replace(microsecond=0)
    valid_order_ids = [o["order_id"] for o in orders if o["order_id"] != 9998]
    rows = []
    for i in range(1, n + 1):
        rows.append(
            {
                "payment_id": i,
                "order_id": valid_order_ids[i % len(valid_order_ids)],
                "payment_method": PAYMENT_METHODS[i % len(PAYMENT_METHODS)],
                "amount": round(random.uniform(10.0, 500.0), 2),
                "currency": "EUR",
                "paid_at": (now - timedelta(hours=i % 48)).strftime("%Y-%m-%d %H:%M:%S"),
                "_loaded_at": (now - timedelta(minutes=i % 90)).strftime("%Y-%m-%d %H:%M:%S"),
            }
        )

    # Intentional DQ issues for source/model tests (fail / warn):
    # 1) NULL amount → not_null FAIL
    rows.append(
        {
            "payment_id": 9001,
            "order_id": valid_order_ids[0],
            "payment_method": "card",
            "amount": "",
            "currency": "EUR",
            "paid_at": now.strftime("%Y-%m-%d %H:%M:%S"),
            "_loaded_at": now.strftime("%Y-%m-%d %H:%M:%S"),
        }
    )
    # 2) invalid payment_method → accepted_values FAIL
    rows.append(
        {
            "payment_id": 9002,
            "order_id": valid_order_ids[1],
            "payment_method": "crypto_unknown",
            "amount": 99.99,
            "currency": "EUR",
            "paid_at": now.strftime("%Y-%m-%d %H:%M:%S"),
            "_loaded_at": now.strftime("%Y-%m-%d %H:%M:%S"),
        }
    )
    # 3) orphan order_id → relationships WARN
    rows.append(
        {
            "payment_id": 9003,
            "order_id": 888888,
            "payment_method": "paypal",
            "amount": 12.34,
            "currency": "EUR",
            "paid_at": now.strftime("%Y-%m-%d %H:%M:%S"),
            "_loaded_at": now.strftime("%Y-%m-%d %H:%M:%S"),
        }
    )
    return rows


def gen_shipments(orders: list[dict], n: int = 30) -> list[dict]:
    """Shipments seed: stale loaded_at (source freshness ERROR) + mild DQ issues."""
    now = datetime.now().replace(microsecond=0)
    # ~45 days old → beyond error_after (14 days) for freshness ERROR demo
    stale_base = now - timedelta(days=45)
    valid_order_ids = [o["order_id"] for o in orders if o["order_id"] != 9998]
    rows = []
    for i in range(1, n + 1):
        rows.append(
            {
                "shipment_id": i,
                "order_id": valid_order_ids[i % len(valid_order_ids)],
                "carrier": random.choice(["DHL", "UPS", "DPD", "GLS"]),
                "shipment_status": SHIPMENT_STATUSES[i % len(SHIPMENT_STATUSES)],
                "shipped_at": (stale_base - timedelta(hours=i)).strftime("%Y-%m-%d %H:%M:%S"),
                "_loaded_at": (stale_base - timedelta(minutes=i)).strftime("%Y-%m-%d %H:%M:%S"),
            }
        )

    # Intentional DQ: invalid shipment_status + orphan order_id
    rows.append(
        {
            "shipment_id": 8001,
            "order_id": 777777,
            "carrier": "DHL",
            "shipment_status": "lost_in_space",
            "shipped_at": stale_base.strftime("%Y-%m-%d %H:%M:%S"),
            "_loaded_at": stale_base.strftime("%Y-%m-%d %H:%M:%S"),
        }
    )
    return rows


def main() -> None:
    users = gen_users(80)
    products = gen_products(60)
    orders = gen_orders(100)
    items = gen_order_items(orders, 60)
    payments = gen_payments(orders, 40)
    shipments = gen_shipments(orders, 30)

    write_csv(
        "raw_users.csv",
        ["user_id", "email", "country", "status", "created_at"],
        users,
    )
    write_csv(
        "raw_products.csv",
        ["product_id", "product_name", "category", "price"],
        products,
    )
    write_csv(
        "raw_orders.csv",
        ["order_id", "user_id", "order_date", "order_status", "total_amount"],
        orders,
    )
    write_csv(
        "raw_order_items.csv",
        ["item_id", "order_id", "product_id", "quantity", "unit_price"],
        items,
    )
    write_csv(
        "raw_payments.csv",
        [
            "payment_id",
            "order_id",
            "payment_method",
            "amount",
            "currency",
            "paid_at",
            "_loaded_at",
        ],
        payments,
    )
    write_csv(
        "raw_shipments.csv",
        [
            "shipment_id",
            "order_id",
            "carrier",
            "shipment_status",
            "shipped_at",
            "_loaded_at",
        ],
        shipments,
    )
    print(
        "Done. Intentional errors: duplicate user_id=1, empty email, "
        "invalid_unknown_status, null payment amount, crypto_unknown method, "
        "orphan payment/shipment order_ids, stale shipment freshness."
    )


if __name__ == "__main__":
    main()
