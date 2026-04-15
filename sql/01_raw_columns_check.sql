SELECT
    table_name,
    column_name,
    data_type,
    ordinal_position
FROM information_schema.columns
WHERE table_schema = 'raw'
  AND table_name IN (
      'raw_sales',
      'raw_purchases',
      'raw_beg_inventory',
      'raw_end_inventory',
      'raw_purchase_prices',
      'raw_invoice_purchases'
  )
ORDER BY table_name, ordinal_position;