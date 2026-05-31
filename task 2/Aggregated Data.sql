SELECT p.name AS psp,
       pc.bin_country,
       t.status,
       t.amount
FROM transactions t
         JOIN psp p ON t.psp_id = p.id
         JOIN payment_credentials pc ON t.payment_credentials_id = pc.id
LIMIT 20;



SELECT p.name  AS psp,
       pc.bin_country,
       CASE
           WHEN r.id IS NOT NULL THEN 'refund'
           WHEN cb.id IS NOT NULL THEN 'chargeback'
           ELSE 'payment'
           END AS operation_type,
       t.status,
       t.amount
FROM transactions t
         JOIN psp p ON t.psp_id = p.id
         JOIN payment_credentials pc ON t.payment_credentials_id = pc.id
         LEFT JOIN refunds r ON t.id = r.transaction_id
         LEFT JOIN chargebacks cb ON t.id = cb.transaction_id
LIMIT 20;



SELECT p.name                                                                   AS psp,
       pc.bin_country,
       CASE
           WHEN r.id IS NOT NULL THEN 'refund'
           WHEN cb.id IS NOT NULL THEN 'chargeback'
           ELSE 'payment'
           END                                                                  AS operation_type,
       t.status,
       COUNT(*)                                                                 AS transaction_count,
       ROUND(AVG(t.amount), 2)                                                  AS avg_amount,
       ROUND(COUNT(*) FILTER (WHERE t.status = 'success')::NUMERIC
                 / SUM(COUNT(*)) OVER (PARTITION BY p.name, pc.bin_country), 4) AS success_rate,
       ROUND(COUNT(*) FILTER (WHERE t.status = 'failed')::NUMERIC
                 / SUM(COUNT(*)) OVER (PARTITION BY p.name, pc.bin_country), 4) AS failed_rate,
       ROUND(COUNT(*) FILTER (WHERE t.status = 'pending')::NUMERIC
                 / SUM(COUNT(*)) OVER (PARTITION BY p.name, pc.bin_country), 4) AS pending_rate
FROM transactions t
         JOIN psp p ON t.psp_id = p.id
         JOIN payment_credentials pc ON t.payment_credentials_id = pc.id
         LEFT JOIN refunds r ON t.id = r.transaction_id
         LEFT JOIN chargebacks cb ON t.id = cb.transaction_id
GROUP BY p.name,
         pc.bin_country,
         operation_type,
         t.status
ORDER BY p.name,
         pc.bin_country,
         operation_type,
         t.status;



WITH success_rates AS (SELECT p.name AS psp,
                              pc.bin_country,
                              ROUND(
                                      COUNT(*) FILTER (WHERE t.status = 'success')::NUMERIC
                                          / COUNT(*), 4
                              )      AS success_rate
                       FROM transactions t
                                JOIN psp p ON t.psp_id = p.id
                                JOIN payment_credentials pc ON t.payment_credentials_id = pc.id
                       GROUP BY p.name,
                                pc.bin_country)
SELECT *
FROM success_rates
ORDER BY bin_country, success_rate DESC;


WITH success_rates AS (SELECT p.name AS psp,
                              pc.bin_country,
                              ROUND(
                                      COUNT(*) FILTER (WHERE t.status = 'success')::NUMERIC
                                          / COUNT(*), 4
                              )      AS success_rate
                       FROM transactions t
                                JOIN psp p ON t.psp_id = p.id
                                JOIN payment_credentials pc ON t.payment_credentials_id = pc.id
                       GROUP BY p.name,
                                pc.bin_country),
     ranked AS (SELECT psp,
                       bin_country,
                       success_rate,
                       ROW_NUMBER() OVER (
                           PARTITION BY bin_country
                           ORDER BY success_rate DESC
                           ) AS rank
                FROM success_rates)
SELECT psp,
       bin_country,
       success_rate,
       rank
FROM ranked
WHERE rank <= 3
ORDER BY bin_country,
         rank;

WITH success_rates AS (
    SELECT
        p.name  AS psp,
        pc.bin_country,
        ROUND(
                COUNT(*) FILTER (WHERE t.status = 'success')::NUMERIC
                / COUNT(*), 4
        )   AS success_rate
    FROM transactions t
             JOIN psp p ON t.psp_id = p.id
             JOIN payment_credentials pc ON t.payment_credentials_id = pc.id
    GROUP BY
        p.name,
        pc.bin_country
),
     ranked AS (
         SELECT
             psp,
             bin_country,
             success_rate,
             ROW_NUMBER() OVER (
                 PARTITION BY bin_country
                 ORDER BY success_rate DESC
                 )               AS rank
         FROM success_rates
     )
SELECT
    psp,
    bin_country,
    success_rate,
    rank
FROM ranked
WHERE rank <= 3
ORDER BY
    bin_country,
    rank;