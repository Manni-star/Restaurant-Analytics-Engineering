import duckdb
import random
from datetime import datetime, timedelta
import pandas as pd

# Connect to DuckDB
conn = duckdb.connect(database=':memory:')

# Reproducibility
random.seed(42)

# Date range
start_date = datetime.strptime("16/02/2023", "%d/%m/%Y")
end_date = datetime.strptime("25/10/2025", "%d/%m/%Y")

item_ids = [f"it{str(i).zfill(3)}" for i in range(1, 33)]

orders_temp = []

current_date = start_date

# -----------------------------
# STEP 1: Generate orders
# -----------------------------
while current_date <= end_date:
    num_orders = random.randint(20, 25)

    for _ in range(num_orders):

        cust_id = random.randint(1, 1000)
        add_id = cust_id
        delivery = random.choice(["Y", "N"])

        # Generate RANDOM TIME (08:00–23:59)
        start_time = datetime.combine(current_date, datetime.strptime("08:00:00", "%H:%M:%S").time())
        end_time = datetime.combine(current_date, datetime.strptime("23:59:59", "%H:%M:%S").time())

        random_seconds = random.randint(0, int((end_time - start_time).total_seconds()))
        created_datetime = start_time + timedelta(seconds=random_seconds)

        num_items = random.randint(1, 4)
        selected_items = random.sample(item_ids, num_items)

        orders_temp.append({
            "created_at": created_datetime,
            "cust_id": cust_id,
            "add_id": add_id,
            "delivery": delivery,
            "items": selected_items
        })

    current_date += timedelta(days=1)

# -----------------------------
# STEP 2: SORT by timestamp
# -----------------------------
orders_temp = sorted(orders_temp, key=lambda x: x["created_at"])

# -----------------------------
# STEP 3: Assign order_id + shift_id
# -----------------------------
records = []
order_counter = 1

for order in orders_temp:
    order_id = f"ORD_{str(order_counter).zfill(5)}"  # 5-digit padding for scalability

    created_datetime = order["created_at"]

    # 🔥 Assign SHIFT
    if created_datetime.time() < datetime.strptime("16:00:00", "%H:%M:%S").time():
        shift_id = "sh0001"  # Morning
    else:
        shift_id = "sh0002"  # Afternoon

    for item in order["items"]:
        quantity = random.randint(1, 4)

        records.append({
            "order_id": order_id,
            "created_at": created_datetime.strftime("%Y-%m-%d %H:%M:%S"),
            "date": created_datetime.strftime("%Y-%m-%d"),  # helper column
            "shift_id": shift_id,
            "item_id": item,
            "quantity": quantity,
            "delivery": order["delivery"],
            "cust_id": order["cust_id"],
            "add_id": order["add_id"]
        })

    order_counter += 1

# -----------------------------
# STEP 4: Create DataFrame
# -----------------------------
df = pd.DataFrame(records)

# Create DuckDB table
conn.execute("CREATE OR REPLACE TABLE transactions AS SELECT * FROM df")

# Preview
print(conn.execute("SELECT * FROM transactions LIMIT 15").fetchdf())

# Save CSV
df.to_csv("/Users/manvesh/Desktop/transactions_FINAL.csv", index=False)