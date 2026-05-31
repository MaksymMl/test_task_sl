SELECT 'transactions' AS tbl, COUNT(*)
FROM transactions
UNION ALL
SELECT 'psp', COUNT(*)
FROM psp
UNION ALL
SELECT 'payment_credentials', COUNT(*)
FROM payment_credentials
UNION ALL
SELECT 'currencies', COUNT(*)
FROM currencies
UNION ALL
SELECT 'refunds', COUNT(*)
FROM refunds
UNION ALL
SELECT 'chargebacks', COUNT(*)
FROM chargebacks;


SELECT
    t.id,
    p.name        AS psp_name,
    pc.bin_country,
    c.iso_code    AS currency,
    t.amount,
    t.status
FROM transactions t
         JOIN psp p                  ON t.psp_id = p.id
         JOIN payment_credentials pc ON t.payment_credentials_id = pc.id
         JOIN currencies c           ON t.currency_id = c.id
LIMIT 10;