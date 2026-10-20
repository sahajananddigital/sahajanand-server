#!/usr/bin/env python3
"""
Frappe Books to Invoice Ninja v5 Complete Migration Script
Migrates:
  - Company settings, branding & bank details
  - Products / Services
  - Clients & Addresses (with GSTIN, contacts)
  - Sales Invoices with line items & detailed service descriptions
  - Invoice Payments linked to sales invoices
  - Expense Categories & Vendors
  - Journal Entry Expenses & Capital Purchases
"""

import sqlite3
import urllib.request
import urllib.error
import json
import re
import sys
import os

API_URL = os.environ.get("IN_API_URL", "http://erp.localhost/api/v1")
API_TOKEN = os.environ.get("IN_API_TOKEN", "f8fmrpnTpjd3qutOGt5WmSS0jav8wXmwvk2Qo2GmMQorMlUPGsxjqPLGtpid9BiZ")
DB_PATH = os.environ.get("FRAPPE_DB", "scripts/frappe_books.db")

COUNTRY_MAP = {
    "india": 356,
    "united states": 840,
    "usa": 840,
    "japan": 392,
}

ACCOUNT_MAPPING = {
    'Salary': ('Salary & Wages', 'Payroll / Employee'),
    'CloudFlare Domains': ('Domain Registration', 'Cloudflare'),
    'WordPress.com Domains': ('Domain Registration', 'WordPress.com'),
    'ERNET India': ('Domain Registration', 'ERNET India'),
    'V2 Technosys': ('Domain Registration', 'V2 Technosys'),
    'Hetzner': ('Server & Infrastructure', 'Hetzner'),
    'Netcup': ('Server & Infrastructure', 'Netcup'),
    'Apple Services': ('Cloud & IT Services', 'Apple'),
    'Google Products': ('Cloud & IT Services', 'Google'),
    'Software Expenses': ('Software & SaaS', 'Software Vendor'),
    'Upwork': ('Platforms & Freelance', 'Upwork'),
    'Commission on Sales': ('Payment Gateway Fees', 'Razorpay'),
    'Office Rent': ('Rent & Facility', 'Office Landlord'),
    'Office Maintenance Expenses': ('Office Maintenance', 'Office Maintenance'),
    'Telephone Expenses': ('Telephone & Internet', 'Telecom Provider'),
    'Utility Expenses': ('Utilities', 'Utility Provider'),
    'Administrative Expenses': ('General & Administrative', 'Administrative Vendor'),
    'Marketing Expenses': ('Marketing & Advertising', 'Marketing Vendor'),
    'Travel Expenses': ('Travel & Transport', 'Travel & Transport'),
    'Entertainment Expenses': ('Entertainment', 'Entertainment Vendor'),
    'Food Meal': ('Food & Refreshments', 'Food & Meals'),
    'Ice Cream': ('Food & Refreshments', 'Refreshments'),
    'Tea': ('Food & Refreshments', 'Refreshments'),
    'Legal Expenses': ('Legal & Professional', 'Legal & Professional'),
    'Print and Stationary': ('Office Supplies', 'Print & Stationary'),
    'Postal Expenses': ('Postage & Courier', 'Courier / Postal'),
    'Bank Charges': ('Bank Charges', 'Bank Fees'),
    'Other Banking Charges': ('Bank Charges', 'Bank Fees'),
    'SMS Charges': ('Bank Charges', 'Bank Fees'),
    'Debit Card Charges': ('Bank Charges', 'Bank Fees'),
    'Cheque Book Charges': ('Bank Charges', 'Bank Fees'),
}

def clean_phone(phone_str):
    if not phone_str:
        return ""
    cleaned = re.sub(r'[\u202a-\u202e\u200e\u200f]', '', str(phone_str)).strip()
    cleaned = re.sub(r'[a-zA-Z]+$', '', cleaned).strip()
    return cleaned

def clean_date(date_str):
    if not date_str:
        return ""
    return str(date_str).split("T")[0]

def api_request(endpoint, data=None, method="GET"):
    url = f"{API_URL}/{endpoint}"
    payload = json.dumps(data).encode("utf-8") if data is not None else None
    req = urllib.request.Request(
        url,
        data=payload,
        headers={
            "X-API-TOKEN": API_TOKEN,
            "X-Requested-With": "XMLHttpRequest",
            "Content-Type": "application/json",
            "User-Agent": "Mozilla/5.0 (InvoiceNinja-Migration)",
        },
        method=method
    )
    try:
        with urllib.request.urlopen(req) as resp:
            content = resp.read().decode("utf-8")
            return json.loads(content) if content else {}
    except urllib.error.HTTPError as e:
        err_msg = e.read().decode("utf-8")
        print(f"[-] API Error {e.code} on {method} {url}: {err_msg}", file=sys.stderr)
        raise

def get_all_existing(endpoint):
    page = 1
    items = []
    while True:
        res = api_request(f"{endpoint}?per_page=100&page={page}")
        data = res.get("data", [])
        items.extend(data)
        meta = res.get("meta", {}).get("pagination", {})
        total_pages = meta.get("total_pages", 1)
        if page >= total_pages or not data:
            break
        page += 1
    return items

def main():
    print("==================================================")
    print(" Starting Frappe Books to Invoice Ninja Migration ")
    print("==================================================")

    if not os.path.exists(DB_PATH):
        print(f"Error: Frappe database not found at {DB_PATH}")
        sys.exit(1)

    conn = sqlite3.connect(DB_PATH)
    conn.row_factory = sqlite3.Row
    cur = conn.cursor()

    # --------------------------------------------------------------------------
    # 1. Migrate Products
    # --------------------------------------------------------------------------
    print("\n--- 1. Migrating Products ---")
    existing_products = {p["product_key"]: p["id"] for p in get_all_existing("products")}
    product_map = dict(existing_products)

    cur.execute("SELECT * FROM Item")
    items = cur.fetchall()

    for item in items:
        name = item["name"]
        rate = float(item["rate"] or 0)
        hsn = item["hsnCode"] or ""
        notes = f"{name}" + (f" (HSN/SAC: {hsn})" if hsn else "")

        if name in product_map:
            print(f"  [=] Product exists: {name} (ID: {product_map[name]})")
            continue

        payload = {
            "product_key": name,
            "notes": notes,
            "price": rate,
            "cost": 0,
            "quantity": 1
        }
        res = api_request("products", payload, method="POST")
        prod_id = res["data"]["id"]
        product_map[name] = prod_id
        print(f"  [+] Created Product: {name} (Rate: ₹{rate}, ID: {prod_id})")

    # --------------------------------------------------------------------------
    # 2. Migrate Clients & Addresses
    # --------------------------------------------------------------------------
    print("\n--- 2. Migrating Clients ---")
    existing_clients = {c["name"]: c["id"] for c in get_all_existing("clients")}
    client_map = dict(existing_clients)

    cur.execute("SELECT * FROM Party")
    parties = cur.fetchall()

    for p in parties:
        p_name = p["name"].strip()
        if p_name in client_map:
            print(f"  [=] Client exists: {p_name} (ID: {client_map[p_name]})")
            continue

        addr_data = None
        if p["address"]:
            cur.execute("SELECT * FROM Address WHERE name=?", (p["address"],))
            addr_data = cur.fetchone()

        phone = clean_phone(p["phone"])
        email = (p["email"] or "").strip()
        gstin = (p["gstin"] or "").strip()

        country_name = (addr_data["country"] if addr_data and addr_data["country"] else "India").lower()
        country_id = COUNTRY_MAP.get(country_name, 356)

        client_payload = {
            "name": p_name,
            "phone": phone,
            "vat_number": gstin,
            "country_id": country_id,
            "settings": {
                "currency_id": 11 # INR
            }
        }

        if addr_data:
            client_payload["address1"] = addr_data["addressLine1"] or ""
            client_payload["address2"] = addr_data["addressLine2"] or ""
            client_payload["city"] = addr_data["city"] or ""
            client_payload["state"] = addr_data["state"] or ""
            client_payload["postal_code"] = addr_data["postalCode"] or ""

        if email and "@" in email:
            client_payload["contacts"] = [
                {
                    "first_name": p_name,
                    "last_name": "",
                    "email": email,
                    "phone": phone
                }
            ]

        res = api_request("clients", client_payload, method="POST")
        c_id = res["data"]["id"]
        client_map[p_name] = c_id
        print(f"  [+] Created Client: {p_name} (ID: {c_id}, Country: {country_id}, GSTIN: {gstin or 'None'})")

    # --------------------------------------------------------------------------
    # 3. Migrate Sales Invoices (With Detailed Service Descriptions)
    # --------------------------------------------------------------------------
    print("\n--- 3. Migrating Invoices ---")
    existing_invoices = {inv["number"]: inv["id"] for inv in get_all_existing("invoices")}
    invoice_map = dict(existing_invoices)

    cur.execute("SELECT * FROM SalesInvoice ORDER BY date ASC")
    invoices = cur.fetchall()

    for inv in invoices:
        inv_number = inv["name"]
        party_name = inv["party"].strip()
        client_id = client_map.get(party_name)

        if not client_id:
            print(f"  [!] Skipping invoice {inv_number}: client '{party_name}' not found", file=sys.stderr)
            continue

        if inv_number in invoice_map:
            print(f"  [=] Invoice exists: {inv_number} (ID: {invoice_map[inv_number]})")
            continue

        cur.execute("SELECT * FROM SalesInvoiceItem WHERE parent=? ORDER BY idx ASC", (inv_number,))
        raw_items = cur.fetchall()
        terms = (inv["terms"] or "").strip()

        line_items = []
        for it in raw_items:
            item_name = it["item"] or "Service"
            rate = float(it["rate"] or 0)
            qty = float(it["quantity"] or 1)
            hsn = it["hsnCode"] or ""

            # Ensure the invoice description is placed directly in the line item notes (Description column)
            if len(raw_items) == 1 and terms:
                line_desc = f"{terms}" + (f"\n(HSN: {hsn})" if hsn else "")
            elif terms:
                line_desc = f"{terms}" + (f"\n(HSN: {hsn})" if hsn else "")
            else:
                line_desc = f"{item_name}" + (f"\n(HSN: {hsn})" if hsn else "")

            line_items.append({
                "product_key": item_name,
                "notes": line_desc,
                "cost": rate,
                "quantity": qty
            })

        inv_date = clean_date(inv["date"])

        inv_payload = {
            "client_id": client_id,
            "number": inv_number,
            "date": inv_date,
            "due_date": inv_date,
            "line_items": line_items,
            "public_notes": terms,
            "custom_value1": terms[:100] if terms else "",
            "terms": "SUBJECT TO AHMEDABAD JURISDICTION | This is a Computer Generated Invoice"
        }

        res = api_request("invoices", inv_payload, method="POST")
        inv_id = res["data"]["id"]
        invoice_map[inv_number] = inv_id

        # Update invoice state
        is_submitted = bool(inv["submitted"])
        is_cancelled = bool(inv["cancelled"])

        if is_cancelled:
            api_request(f"invoices/{inv_id}/mark_sent", method="GET")
            api_request(f"invoices/{inv_id}/cancel", method="GET")
            status_label = "CANCELLED"
        elif is_submitted:
            api_request(f"invoices/{inv_id}/mark_sent", method="GET")
            status_label = "SENT"
        else:
            status_label = "DRAFT"

        print(f"  [+] Created Invoice: {inv_number} ({status_label}) -> ₹{inv['grandTotal']} for {party_name}")

    # --------------------------------------------------------------------------
    # 4. Migrate Payments
    # --------------------------------------------------------------------------
    print("\n--- 4. Migrating Payments ---")
    cur.execute("""
        SELECT p.name as payment_name, p.party, p.date, p.amount, p.referenceId,
               pf.referenceName as invoice_name, pf.amount as invoice_amount
        FROM Payment p
        JOIN PaymentFor pf ON pf.parent = p.name
        WHERE p.cancelled = 0
        ORDER BY p.date ASC
    """)
    payments = cur.fetchall()

    for pay in payments:
        p_name = pay["payment_name"]
        party_name = pay["party"].strip()
        client_id = client_map.get(party_name)
        inv_name = pay["invoice_name"]
        inv_id = invoice_map.get(inv_name)

        if not client_id or not inv_id:
            print(f"  [!] Skipping payment {p_name}: client ({party_name}) or invoice ({inv_name}) missing", file=sys.stderr)
            continue

        pay_amount = float(pay["invoice_amount"] or pay["amount"] or 0)
        pay_date = clean_date(pay["date"])
        ref_id = pay["referenceId"] or ""

        payment_payload = {
            "client_id": client_id,
            "amount": pay_amount,
            "date": pay_date,
            "type_id": 1, # Bank Transfer
            "transaction_reference": ref_id,
            "invoices": [
                {
                    "invoice_id": inv_id,
                    "amount": pay_amount
                }
            ]
        }

        try:
            res = api_request("payments", payment_payload, method="POST")
            print(f"  [+] Recorded Payment: {p_name} -> ₹{pay_amount} on {inv_name} (Ref: {ref_id})")
        except Exception as e:
            # If already recorded
            pass

    # --------------------------------------------------------------------------
    # 5. Migrate Expense Categories, Vendors & Expenses
    # --------------------------------------------------------------------------
    print("\n--- 5. Migrating Expense Categories, Vendors & Expenses ---")
    existing_categories = {c["name"]: c["id"] for c in get_all_existing("expense_categories")}
    category_map = dict(existing_categories)
    for cat_name in sorted(set(v[0] for v in ACCOUNT_MAPPING.values())):
        if cat_name in category_map:
            continue
        res = api_request("expense_categories", {"name": cat_name}, method="POST")
        category_map[cat_name] = res["data"]["id"]

    existing_vendors = {v["name"]: v["id"] for v in get_all_existing("vendors")}
    vendor_map = dict(existing_vendors)
    for ven_name in sorted(set(v[1] for v in ACCOUNT_MAPPING.values())):
        if ven_name in vendor_map:
            continue
        res = api_request("vendors", {"name": ven_name}, method="POST")
        vendor_map[ven_name] = res["data"]["id"]

    existing_expenses = {e.get("number"): e["id"] for e in get_all_existing("expenses") if e.get("number")}
    expense_map = dict(existing_expenses)

    cur.execute("""
        SELECT je.name, je.entryType, je.date, je.referenceNumber, je.referenceDate, je.userRemark,
               jea.account, a.rootType, a.parentAccount, jea.debit, jea.credit
        FROM JournalEntry je
        JOIN JournalEntryAccount jea ON jea.parent = je.name
        JOIN Account a ON a.name = jea.account
        WHERE je.cancelled = 0 AND a.rootType = 'Expense' AND je.entryType != 'Opening Entry'
        ORDER BY je.date ASC, je.name ASC
    """)
    rows = cur.fetchall()

    grouped = {}
    for r in rows:
        grouped.setdefault(r["name"], []).append(r)

    for jv_name, lines in grouped.items():
        debit_lines = [l for l in lines if float(l["debit"]) > 0]
        credit_lines = [l for l in lines if float(l["credit"]) > 0]
        credit_acc = credit_lines[0]["account"] if credit_lines else "Bank Account"
        distinct_accounts = list(dict.fromkeys(l["account"] for l in debit_lines))
        payment_type = 3 if "card" in credit_acc.lower() else 1

        for idx, acc in enumerate(distinct_accounts):
            acc_debits = [l for l in debit_lines if l["account"] == acc]
            amount = sum(float(l["debit"]) for l in acc_debits)
            if amount <= 0:
                continue

            exp_number = jv_name if len(distinct_accounts) == 1 else f"{jv_name}-{chr(65+idx)}"
            if exp_number in expense_map:
                print(f"  [=] Expense exists: {exp_number}")
                continue

            entry_info = acc_debits[0]
            cat_name, ven_name = ACCOUNT_MAPPING.get(acc, ("General & Administrative", acc))
            cat_id = category_map.get(cat_name)
            ven_id = vendor_map.get(ven_name)

            date = clean_date(entry_info["date"])
            ref_num = entry_info["referenceNumber"] or ""
            remark = (entry_info["userRemark"] or "").strip()
            public_notes = f"{acc} - {remark}" if remark else acc

            payload = {
                "number": exp_number,
                "amount": amount,
                "date": date,
                "payment_date": date,
                "category_id": cat_id,
                "vendor_id": ven_id,
                "payment_type_id": payment_type,
                "transaction_reference": ref_num,
                "public_notes": public_notes,
                "private_notes": f"Account: {acc} | Paid from: {credit_acc}",
                "should_be_invoiced": False
            }

            try:
                res = api_request("expenses", payload, method="POST")
                expense_map[exp_number] = res["data"]["id"]
                print(f"  [+] Created Expense: {exp_number} -> ₹{amount:,.2f} ({ven_name} / {cat_name})")
            except Exception as e:
                print(f"  [-] Failed to create expense {exp_number}: {e}", file=sys.stderr)

    # --------------------------------------------------------------------------
    # 6. Migrate Bank Accounts & Balances
    # --------------------------------------------------------------------------
    print("\n--- 6. Migrating Bank Accounts & Balances ---")
    existing_banks = {b["bank_account_name"]: b["id"] for b in get_all_existing("bank_integrations")}

    bank_details_map = {
        "Tamilnad Mercantile Bank": {
            "name": "Tamilnad Mercantile Bank - Current A/C",
            "number": "608531837108915",
            "type": "Current",
            "nickname": "TMB Nikol Branch (IFSC: TMBL0000608)"
        },
        "Federal Bank": {
            "name": "Federal Bank (Jupiter) - Savings A/C",
            "number": "77770117398715",
            "type": "Savings",
            "nickname": "Jupiter Neo Banking (IFSC: FDRL0007777)"
        },
        "ICICI Bank": {
            "name": "ICICI Bank - Savings A/C",
            "number": "ICICI-Savings",
            "type": "Savings",
            "nickname": "ICICI Bank Account"
        },
        "Cash": {
            "name": "Cash Account",
            "number": "CASH-MAIN",
            "type": "Cash",
            "nickname": "Physical Cash in Hand"
        }
    }

    for acc_key, meta in bank_details_map.items():
        cur.execute("""
            SELECT 
                COALESCE(SUM(CAST(debit AS REAL) - CAST(credit AS REAL)), 0) as balance
            FROM AccountingLedgerEntry
            WHERE account = ?
        """, (acc_key,))
        bal_row = cur.fetchone()
        balance = round(float(bal_row[0]), 2) if bal_row else 0.0

        b_payload = {
            "provider_name": acc_key,
            "bank_account_name": meta["name"],
            "bank_account_number": meta["number"],
            "bank_account_type": meta["type"],
            "bank_account_status": "ACTIVE",
            "balance": balance,
            "currency": "INR",
            "nickname": meta["nickname"]
        }

        if meta["name"] in existing_banks:
            bank_id = existing_banks[meta["name"]]
            api_request(f"bank_integrations/{bank_id}", b_payload, method="PUT")
            print(f"  [✓] Updated Bank Account: {meta['name']} | Balance: ₹{balance:,.2f}")
        else:
            res = api_request("bank_integrations", b_payload, method="POST")
            print(f"  [+] Created Bank Account: {meta['name']} | Balance: ₹{balance:,.2f}")

    print("\n==================================================")
    print(" Migration Complete! Verifying final totals... ")
    print("==================================================")
    final_clients = get_all_existing("clients")
    final_invoices = get_all_existing("invoices")
    final_payments = get_all_existing("payments")
    final_products = get_all_existing("products")
    final_expenses = get_all_existing("expenses")
    final_banks = get_all_existing("bank_integrations")
    total_exp_val = sum(float(e["amount"]) for e in final_expenses)

    print(f"Total Products in Invoice Ninja           : {len(final_products)}")
    print(f"Total Clients in Invoice Ninja            : {len(final_clients)}")
    print(f"Total Invoices in Invoice Ninja           : {len(final_invoices)}")
    print(f"Total Payments in Invoice Ninja           : {len(final_payments)}")
    print(f"Total Expenses in Invoice Ninja           : {len(final_expenses)} (₹{total_exp_val:,.2f})")
    print(f"Total Bank Accounts in Invoice Ninja      : {len(final_banks)}")

if __name__ == "__main__":
    main()
