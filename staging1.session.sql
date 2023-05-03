select scu.fk_user_id,
    oi.created_at,
    oi.invoice_id,
    cc.name,
    pu.name AS user_name,
    COALESCE(
        COALESCE((oi.charge_value), 0) + SUM(oii.taxable_amount) FILTER(
            WHERE oi.created_at < '2023-02-22 00:00:00'
                AND oi.created_at >= '2023-02-21 00:00:00'
        ),
        0
    ) AS Feb_21_23
FROM op_invoice oi
    JOIN op_invoice_item oii ON oii.fk_invoice_id = oi.invoice_id
    AND oi.fk_seller_company_id = 796
    JOIN sales_order_item soi ON soi.sales_order_item_id = oii.fk_sales_order_item_id
    JOIN sales_order so ON so.sales_order_id = soi.fk_sales_order_id
    JOIN seller_company_user scu ON oi.fk_seller_company_id = scu.fk_seller_company_id
    JOIN customer_company cc ON cc.customer_company_id = oi.fk_customer_company_id
    JOIN pra_user pu ON pu.user_id = scu.fk_user_id
WHERE oi.status IN ('replaced', 'created')
    AND oi.payment_status <> 'cancelled'
    AND oi.is_auto_gen = 'no'
    AND scu.fk_user_id = 1201115
    and oi.created_at >= '2023-02-21 00:00:00'
    and oi.created_at < '2023-02-22 00:00:00'
GROUP BY oi.invoice_id,
    pu.name,
    cc.name,
    scu.fk_user_id
order by cc."name"