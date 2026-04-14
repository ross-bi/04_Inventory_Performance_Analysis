CREATE OR REPLACE VIEW staging.stg_invoice_purchases AS
SELECT
    NULLIF(TRIM(vendor_number), '')::INT          AS vendor_no,
    NULLIF(TRIM(vendor_name), '')                 AS vendor_name,
    NULLIF(TRIM(invoice_date), '')::DATE          AS invoice_date,
    NULLIF(TRIM(po_number), '')::INT              AS po_number,
    NULLIF(TRIM(po_date), '')::DATE               AS po_date,
    NULLIF(TRIM(pay_date), '')::DATE              AS pay_date,
    NULLIF(TRIM(quantity), '')::INT               AS quantity,
    NULLIF(TRIM(dollars), '')::NUMERIC(12,2)      AS dollars,
    NULLIF(TRIM(freight), '')::NUMERIC(12,2)      AS freight,
    NULLIF(TRIM(approval), '')                    AS approval
FROM raw.raw_invoice_purchases;