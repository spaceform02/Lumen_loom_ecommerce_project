# Lumen & Loom E-Commerce Revenue Reconciliation

![dbt](https://img.shields.io/badge/dbt-FF694B?style=for-the-badge&logo=dbt&logoColor=white)
![Snowflake](https://img.shields.io/badge/Snowflake-29B5E8?style=for-the-badge&logo=snowflake&logoColor=white)
![Data Engineering](https://img.shields.io/badge/Data_Engineering-production-success?style=for-the-badge)

## 📖 Problem Statement
In high-volume e-commerce environments, a fundamental disconnect often emerges between **Finance** (who track cash collected via payment gateways) and **Operations** (who track revenue based on successful physical fulfillment). 

For Lumen & Loom, flaky carrier APIs, duplicate payment gateway webhooks, and delayed refunds create discrepancies. Without a centralized reconciliation model, it is impossible to identify **revenue leakage** (e.g., orders that were cancelled and paid for, but never refunded) or accurately report monthly net revenue.

## 🎯 Objectives
This dbt project models raw operational feeds into a clean, auditable financial data mart to:
1. **Standardize Currency:** Convert mixed-currency transactions (USD, EUR, GBP) into a unified reporting currency (USD).
2. **Identify Leakage:** Explicitly flag API errors, duplicate payment captures, and unrefunded cancellations.
3. **Bridge Finance & Ops:** Create a monthly reconciliation aggregate that explains the timing differences between cash receipt and order delivery.
4. **Establish a Single Source of Truth:** Provide a unified `mart_lumen_loom__revenue` fact table at the order grain for downstream BI consumption.

---

## 🏗️ Architecture & DAG
The pipeline follows a standard Medallion Architecture (Bronze/Raw -> Silver/Intermediate -> Gold/Mart).

<img width="1536" height="1024" alt="image" src="https://github.com/user-attachments/assets/26145d1d-b1f4-48fa-934c-79dde2ab3dce" />

## 🗂️ Data Dictionary & Layering Strategy

### 1. Staging (`stg_`)
The staging layer provides a 1:1 mapping to the raw tables, handling light transformations like casting data types, trimming strings, and generating surrogate keys.
* **`stg_lumen_loom__orders`**: Core order lifecycle states.
* **`stg_lumen_loom__payments`**: Payment attempts. Contains retries and intentional gateway duplicates.
* **`stg_lumen_loom__refunds`**: Processed refunds, which may be partial and occur in subsequent months.
* **`stg_lumen_loom__shipping`**: Fulfillment tracking.

### 2. Intermediate (`int_`)
The intermediate layer applies core business logic, standardizes currencies, and resolves anomalies from the source systems.
* **`int_lumen_loom__orders`**: Applies seed-based exchange rates and corrects inverted `created_at` / `updated_at` timestamps.
* **`int_lumen_loom__payments`**: Uses window functions to identify and flag `is_valid_revenue`, `is_duplicate_payment`, and `is_failed_attempt`.
* **`int_lumen_loom__refunds`**: Standardizes refund amounts to USD.
* **`int_lumen_loom__shipping`**: Derives true shipping status (`derived_shipping_status`) and flags missing timestamps as `api_error_flag`.

### 3. Mart (`mart_`)
The gold layer designed for stakeholder consumption.
* **`mart_lumen_loom__revenue`**: Wide fact table at the `order_id` grain. Joins all intermediate models to provide a holistic view of expected revenue, collected cash, refunds, and shipping status. Flags `cancellation_leakage`.
* **`mart_lumen_loom_monthly__reconcilliation`**: Monthly aggregate bridge. Calculates `finance_net_revenue` vs `operation_net_revenue` and isolates the `timing_diff`.

---

## 🚀 Setup & Execution

### Prerequisites
* dbt Core (v1.5+)
* Snowflake account with `LUMEN_LOOM.RAW` database populated

### Installation
1. Clone this repository:
   ```bash
   git clone [https://github.com/spaceform02/Lumen_loom_ecommerce_project.git](https://github.com/spaceform02/Lumen_loom_ecommerce_project.git)
   cd Lumen_loom_ecommerce_project
   ```
2. Install dbt dependencies:
   ```bash
   dbt deps
   ```
3. Load the static exchange rate seed:
   ```bash
   dbt seed
   ```
4. Run the models and tests:
   ```bash
   dbt build
   ```

---

## 🧪 Testing & Data Quality
This project enforces strict data contracts using dbt native tests:
* **Primary Key Integrity:** `unique` and `not_null` tests on all natural and surrogate keys.
* **Referential Integrity:** `relationships` tests ensuring payments, refunds, and shipments map back to valid orders.
* **Domain Validations:** `accepted_values` tests on critical states (e.g., `order_status`, `payment_method`, `refund_reason`).
* **Business Logic Assertions (Singular Tests):** Custom SQL tests to catch logical violations, including:
  * Ensuring `refund_amount_usd` never exceeds the original `payment_amount_usd`.
  * Validating chronological integrity for order lifecycle (`updated_at` must be >= `created_at`).
  * Validating chronological integrity for fulfillment (`delivered_at` must be >= `shipped_at`).

---

## 🛣️ Known Limitations & Roadmap (Future Enhancements)
To evolve this pipeline further into enterprise-grade maturity, the following architectural upgrades are planned:

1. **Slowly Changing Dimensions (SCDs) for Currency:** Transition from a static `seed` file to a daily exchange rate table to prevent historical revenue distortion.
2. **Aggregated Joins:** Refactor the `mart_lumen_loom__revenue` model to aggregate the `int_refunds` table prior to the `LEFT JOIN` to strictly defend the 1-to-many grain and prevent potential fan-outs.
3. **Deterministic Deduplication:** Update the `ROW_NUMBER()` logic in `int_lumen_loom__payments` to include `payment_id` in the `ORDER BY` clause, ensuring deterministic behavior for webhook duplicates firing at the exact same millisecond.
4. **Exposing Source System Flaws:** Rather than masking inverted timestamps via `LEAST/GREATEST`, implement boolean anomaly flags to expose upstream engineering bugs to the data consumers.
