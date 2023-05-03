SELECT string_agg(DISTINCT cc."name",',') AS name
		, string_agg(DISTINCT t.city,',') AS city
		, string_agg(DISTINCT t.state,',') AS state 
		, CASE WHEN oi.created_at >= '2022-05-01' AND oi.payment_status = 'paid' AND (SELECT oipt.payment_date::DATE FROM op_invoice_payment_tx oipt WHERE oipt.fk_invoice_id = oi.invoice_id ORDER BY created_at DESC LIMIT 1)
		- oi.created_at::DATE >= 0 THEN ((SELECT oipt.payment_date::DATE FROM op_invoice_payment_tx oipt WHERE oipt.fk_invoice_id = oi.invoice_id ORDER BY created_at DESC LIMIT 1)
		- oi.created_at::DATE)::DECIMAL
		ELSE 0 END AS days,
		CASE WHEN oi.created_at >= '2022-05-01' AND oi.payment_status = 'paid' THEN 1 ELSE 0 END AS no_of_invoices_paid 
		,CASE WHEN oi.created_at >= '2022-05-01' AND ((
				(oi.due_date IS NULL OR oi.due_date::TEXT ='0000-00-00 00:00:00') 
				AND DATE_PART('day', DATE_TRUNC('day', (
				SELECT pay.payment_date FROM op_invoice_payment_tx pay 
				WHERE fk_invoice_id = oi.invoice_id AND oi.payment_status = 'paid'
				ORDER BY pay.created_at DESC LIMIT 1)) - DATE_TRUNC('day', oi.created_at)) <= 0 
				)
				OR (
				DATE_PART('day', DATE_TRUNC('day', (
				SELECT pay.payment_date FROM op_invoice_payment_tx pay 
				WHERE fk_invoice_id = oi.invoice_id AND oi.payment_status = 'paid'
				ORDER BY pay.created_at DESC LIMIT 1)) - DATE_TRUNC('day', oi.due_date)) <= 0
				))
				THEN 1 
				ELSE 0 END on_time
		, CASE WHEN oi.created_at >= '2022-05-01' AND ((oi.payment_status = 'paid') OR (oi.payment_status <> 'cancelled' AND (oi.due_date::DATE <= now()::DATE OR oi.due_date IS NULL OR oi.due_date::TEXT ='0000-00-00 00:00:00')
				)) THEN 1
				ELSE 0 END total
		, oi.fk_customer_company_id AS customer_company_id
		, oi.fk_seller_company_id AS seller_company_id
		, oi.created_at 
		, oi.due_date
		, CASE WHEN oi.payment_status = 'due' THEN 1 ELSE 0 END AS unpaid_invoices
		, CASE WHEN oi.payment_status = 'due' THEN oi.invoice_total - (SELECT COALESCE(SUM(pay.payment_amount),0) FROM op_invoice_payment_tx pay WHERE pay.fk_invoice_id = oi.invoice_id) 
			   ELSE 0 END AS receivables
		, SUM(oi.invoice_total - (SELECT COALESCE(SUM(pay.payment_amount),0) FROM op_invoice_payment_tx pay WHERE pay.fk_invoice_id = oi.invoice_id) 
			   ) FILTER(WHERE oi.payment_status = 'due'  AND oi.due_date >= '2022-05-01'  ) OVER() AS total_receivables
		, string_agg(DISTINCT cc.parent_id::TEXT,',') AS parent_id
	FROM op_invoice oi 
		JOIN customer_company cc ON cc.customer_company_id = oi.fk_customer_company_id 
		JOIN LATERAL ( 
				SELECT CASE WHEN a.city IS NULL THEN soa.city ELSE a.city END
				, CASE WHEN a.state IS NULL THEN soa.state ELSE a.state END , 
				CASE WHEN cc.customer_company_id IS NULL THEN oi.fk_customer_company_id ELSE cc.customer_company_id END 
				FROM customer_company cc2
					LEFT JOIN customer_company_address cca ON cc2.customer_company_id = cca.fk_customer_company_id
					LEFT JOIN address a ON a.address_id = cca.fk_address_id
					LEFT JOIN sales_order_address soa ON soa.fk_sales_order_id = oi.fk_billing_address_id 
				WHERE (cc2.customer_company_id = cc.customer_company_id OR cc2.parent_id = cc.customer_company_id)
				AND (a.type is null OR a.type ='billing' and a.status = 'enable')
			ORDER BY a.created_at asc
			LIMIT 1
			) AS t ON t.customer_company_id = cc.customer_company_id
		WHERE oi.fk_seller_company_id = 858 AND oi.status IN ('replaced','created') 
			AND oi.is_auto_gen = 'no'  AND oi.fk_customer_company_id = 195540 
		GROUP BY oi.invoice_id
