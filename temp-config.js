module.exports = {
        "forecast": {
            table: "forecast",
            fields: [
                { name: "year", type: "number", label: "Year" },
                { name: "forecast_qty", type: "number", label: "Forecast Qty" },
                { name: "date_of_sowing", type: "date", label: "Date of Sowing" },
                { name: "enlistment_status", type: "boolean", label: "Enlistment Status" }
            ]
        },
        "bank_debit_advice": {
            table: "bank_debit_advice",
            fields: [
                { name: "is_received", type: "boolean", label: "Is Received" },
                { name: "received_at", type: "datetime-local", label: "Received At", readonly: true },
                { name: "received_by", type: "uuid", label: "Received By", fk: { relation: "app_user", displayColumn: "full_name" }, readonly: true }
            ]
        },
        "good_declaration": {
            table: "good_declaration",
            fields: [
                { name: "gd_number", type: "text", label: "GD Number" },
                { name: "gd_date", type: "date", label: "GD Date" },
                { name: "gd_file_date", type: "date", label: "GD File Date" },
                { name: "clearing_agent_id", type: "uuid", label: "Clearing Agent", fk: { relation: "clearing_agent", displayColumn: "name" } }
            ]
        },
        "enlistment_verification": {
            table: "enlistment_verification",
            fields: [
                { name: "verified", type: "boolean", label: "Verified" },
                { name: "verification_notes", type: "text", label: "Verification Notes" },
                { name: "verified_at", type: "datetime-local", label: "Verified At" },
                { name: "verifier_id", type: "uuid", label: "Verifier", fk: { relation: "app_user", displayColumn: "full_name" } },
                { name: "verification_doc_url", type: "text", label: "Document URL", readonly: true }
            ]
        },
        "availability_confirmation": {
            table: "availability_confirmation",
            fields: [
                { name: "available", type: "boolean", label: "Available" },
                { name: "notes", type: "text", label: "Notes" },
                { name: "confirmed_at", type: "datetime-local", label: "Confirmed At" },
                { name: "confirmed_by", type: "uuid", label: "Confirmed By", fk: { relation: "app_user", displayColumn: "full_name" } },
                { name: "supplier_id", type: "uuid", label: "Supplier", fk: { relation: "supplier", displayColumn: "name" } }
            ]
        },
        "purchase_order": {
            table: "purchase_order",
            fields: [
                { name: "po_number", type: "text", label: "PO Number" },
                { name: "po_date", type: "date", label: "PO Date" }
            ]
        },
        "proforma": {
            table: "proforma_invoice",
            fields: [
                { name: "proforma_number", type: "text", label: "Proforma Number" },
                { name: "proforma_date", type: "date", label: "Proforma Date" }
            ]
        },
        "invoice": {
            table: "commercial_invoice",
            fields: [
                { name: "invoice_number", type: "text", label: "Invoice Number" },
                { name: "invoice_date", type: "date", label: "Invoice Date" }
            ]
        },
        "ip_number": {
            table: "ip_number",
            fields: [
                { name: "issued_date", type: "date", label: "Issued Date" },
                { name: "references", type: "jsonb", label: "IP References" }
            ]
        },
        "lc_opening": {
            table: "letter_of_credit",
            fields: [
                { name: "lc_number", type: "text", label: "LC Number" },
                { name: "opened_date", type: "date", label: "Opened Date" },
                { name: "lc_shared_date", type: "date", label: "Shared with Supplier Date" },
                { name: "notes", type: "textarea", label: "Notes" },
                { name: "bank_id", type: "uuid", label: "Bank", fk: { relation: "bank", displayColumn: "name" } }
            ]
        },
        "shipment_details_from_supplier": {
            table: "supplier_shipment_details",
            fields: [
                { name: "readiness_date", type: "date", label: "Readiness Date" },
                { name: "address", type: "text", label: "Pickup Address" },
                { name: "origin", type: "text", label: "Origin" },
                { name: "transport", type: "select", label: "Transport Mode", options: ["air", "sea", "road", "rail"] },
                { name: "inco_terms", type: "select", label: "Incoterms", options: [], dynamicOptions: true },
                { name: "container_type", type: "select", label: "Container Type", options: ["carton", "pallet"] },
                { name: "cartons_count", type: "number", label: "Cartons Count" },
                { name: "gross_weight", type: "number", label: "Gross Weight (kg)" },
                { name: "net_weight", type: "number", label: "Net Weight (kg)" },
                { name: "length", type: "number", label: "Length (cm)" },
                { name: "width", type: "number", label: "Width (cm)" },
                { name: "height", type: "number", label: "Height (cm)" },
                { name: "details_received_date", type: "date", label: "Details Received Date" }
            ]
        },
        "freight_query": {
            table: "freight_query",
            fields: [
                { name: "logistics_company_id", type: "uuid", label: "Logistics Company", fk: { relation: "logistics_company", displayColumn: "name" } },
                { name: "sent_at", type: "datetime-local", label: "Sent At" },
                { name: "term", type: "select", label: "Terms", options: ["FOB", "CIF", "CFR", "EXW", "FCA", "CPT", "CIP", "DAT", "DAP", "DDP"] },
                { name: "shipment_from", type: "text", label: "Shipment From" },
                { name: "destination", type: "text", label: "Destination" },
                { name: "origin", type: "text", label: "Origin" },
                { name: "readiness_date", type: "date", label: "Readiness Date", autoMap: "supplier_shipment_details.readiness_date" },
                { name: "gross_weight", type: "number", label: "Gross Weight (kg)", autoMap: "supplier_shipment_details.gross_weight" },
                { name: "net_weight", type: "number", label: "Net Weight (kg)" },
                { name: "chargeable_weight", type: "number", label: "Chargeable Weight (kg)" },
                { name: "no_of_cartoons", type: "number", label: "Number of Cartons", autoMap: "supplier_shipment_details.cartons_count" },
                { name: "pick_up_address", type: "text", label: "Pick Up Address" },
                { name: "remarks", type: "textarea", label: "Remarks" }
            ]
        },
        "award_shipment": {
            table: "shipment_awarded",
            fields: [
                { name: "awarded", type: "boolean", label: "Awarded" },
                { name: "notes", type: "text", label: "Notes" },
                { name: "awarded_at", type: "datetime-local", label: "Awarded At", readonly: true },
                { name: "awarded_by", type: "uuid", label: "Awarded By", fk: { relation: "app_user", displayColumn: "full_name" }, readonly: true },
                { name: "freight_quote_response_id", type: "uuid", label: "Freight Quote Response", fk: { relation: "freight_quote_response", displayColumn: "name_of_your_company" } }
            ]
        },
        "non_negotiable_docs": {
            table: "non_negotiable_docs",
            fields: [
                { name: "status", type: "select", label: "Status", options: ["Sended", "Arrived", "Pending"] },
                { name: "sended_at", type: "datetime-local", label: "Sended At" },
                { name: "uploaded_by", type: "uuid", label: "Uploaded By", fk: { relation: "app_user", displayColumn: "full_name", constraint: "non_negotiable_docs_uploaded_by_fkey" } },
                { name: "file_url", type: "text", label: "Docs URL", readonly: true },
                { name: "bank_id", type: "uuid", label: "Bank", fk: { relation: "bank", displayColumn: "name" } }
            ]
        },
        "original_docs": {
            table: "original_docs",
            fields: [
                { name: "status", type: "text", label: "Status" },
                { name: "received_at", type: "datetime-local", label: "Received At" },
                { name: "bl_date", type: "date", label: "BL Date" },
                { name: "uploaded_by", type: "uuid", label: "Uploaded By", fk: { relation: "app_user", displayColumn: "full_name", constraint: "original_docs_uploaded_by_fkey" } },
                { name: "docs_url", type: "text", label: "Docs URL", readonly: true },
                { name: "shipping_company", type: "text", label: "Shipping Company" },
                { name: "tracking_number", type: "text", label: "Tracking Number" },
                { name: "shipping_guarantee_applied_date", type: "date", label: "Shipping Guarantee Applied Date" },
                { name: "shipping_guarantee_received_date", type: "date", label: "Shipping Guarantee Received Date" },
                { name: "dispatch_date", type: "date", label: "Dispatch Date" },
                { name: "arrival_at_bank", type: "date", label: "Arrival at Bank" },
                { name: "due_date", type: "date", label: "Due Date" },
                { name: "payment_date", type: "date", label: "Payment Date" },
                { name: "bank_id", type: "uuid", label: "Bank", fk: { relation: "bank", displayColumn: "name" } }
            ]
        },
        "bank_endorsement": {
            table: "bank_endorsement",
            fields: [
                { name: "endorsed", type: "boolean", label: "Endorsed" },
                { name: "endorsed_at", type: "datetime-local", label: "Endorsed At" },
                { name: "updated_by", type: "uuid", label: "Updated By", fk: { relation: "app_user", displayColumn: "full_name" } }
            ]
        },
        "send_to_clearing_agent": {
            table: "docs_to_clearing_agent",
            fields: [
                { name: "name", type: "text", label: "Name" },
                { name: "shipping_company", type: "text", label: "Shipping Company" },
                { name: "tracking_number", type: "text", label: "Tracking Number" },
                { name: "sended_at", type: "date", label: "Sended At" },
                { name: "expected_arrival_date", type: "date", label: "Expected Arrival Date" },
                { name: "slip_picture_url", type: "text", label: "Slip Picture URL", readonly: true },
                { name: "clearing_agent_id", type: "uuid", label: "Clearing Agent", fk: { relation: "clearing_agent", displayColumn: "name" } }
            ]
        },
        "under_clearing_agent": {
            table: "under_clearing_agent",
            fields: [
                { name: "is_received", type: "boolean", label: "Received" },
                { name: "receiving_date", type: "date", label: "Receiving Date" },
                { name: "destuffed_date", type: "date", label: "Destuffed Date" },
                { name: "frsd_application_date", type: "date", label: "FRSD Application Date" },
                { name: "duty_payment_date", type: "date", label: "Duty Payment Date" },
                { name: "sampling_date", type: "date", label: "Sampling Date" },
                { name: "do_date", type: "date", label: "DO Date" },
                { name: "clearing_agent_id", type: "uuid", label: "Clearing Agent", fk: { relation: "clearing_agent", displayColumn: "name" } }
            ]
        },
        "release_orders": {
            table: "release_orders",
            fields: [
                { name: "dpp_ro_number", type: "text", label: "DPP RO Number" },
                { name: "dpp_date", type: "date", label: "DPP Date" },
                { name: "fscrd_ro_number", type: "text", label: "FSCRD RO Number" },
                { name: "fscrd_date", type: "date", label: "FSCRD Date" }
            ]
        },
        "gate_out": {
            table: "gate_out",
            fields: [
                { name: "is_gate_out", type: "boolean", label: "Gate Out" },
                { name: "gate_out_date", type: "date", label: "Gate Out Date" },
                { name: "updated_by", type: "uuid", label: "Updated By", fk: { relation: "app_user", displayColumn: "full_name" } }
            ]
        },
        "transportation": {
            table: "transporter",
            fields: [
                { name: "transporter_name", type: "text", label: "Transporter Name" },
                { name: "bilti_number", type: "text", label: "Bilti Number" },
                { name: "bilti_date", type: "date", label: "Bilti Date" },
                { name: "no_of_pieces", type: "number", label: "No of Pieces" },
                { name: "updated_by", type: "uuid", label: "Updated By", fk: { relation: "app_user", displayColumn: "full_name" } }
            ]
        },
        "warehouse": {
            table: "warehouse_arrival",
            fields: [
                { name: "warehouse_id", type: "fk", label: "Warehouse Name", fk: { relation: "warehouse", displayColumn: "warehouse_name" } },
                { name: "arrival_date", type: "date", label: "Arrival Date" },
                { name: "gr_no", type: "text", label: "GR No" },
                { name: "updated_by", type: "uuid", label: "Updated By", fk: { relation: "app_user", displayColumn: "full_name" } }
            ]
        },
        "documents": {
            table: "document",
            fields: [],
            isDocumentStage: true
        },
        "bills": {
            table: "costing",
            fields: [
                { name: "final_payment", type: "number", label: "Final Payment" },
                { name: "invoice_charges", type: "number", label: "Invoice Charges" },
                { name: "exchange_rate", type: "number", label: "Exchange Rate" },
                { name: "ip_charges", type: "number", label: "IP Charges" },
                { name: "bank_contract_opening_charges", type: "number", label: "Bank Contract Opening Charges" },
                { name: "shipping_guarantee", type: "number", label: "Shipping Guarantee" },
                { name: "fbr_duty", type: "number", label: "FBR Duty" },
                { name: "forwarder_charges", type: "number", label: "Forwarder Charges" },
                { name: "clearing_charges", type: "number", label: "Clearing Charges" },
                { name: "local_transporter", type: "number", label: "Local Transporter" },
                { name: "port_charges", type: "number", label: "Port Charges" },
                { name: "final_payment_charges", type: "number", label: "Final Payment Charges" },
                { name: "total", type: "number", label: "Total" },
                { name: "total_cost", type: "number", label: "Total Cost" },
                { name: "oh_perc", type: "number", label: "OH %" },
                { name: "qty", type: "number", label: "Qty" },
                { name: "per_unit_rate", type: "number", label: "Per Unit Rate" }
            ]
        }
    }