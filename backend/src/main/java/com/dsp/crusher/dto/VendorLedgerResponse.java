package com.dsp.crusher.dto;

import lombok.Data;
import java.math.BigDecimal;
import java.time.LocalDate;
import java.util.List;

@Data
public class VendorLedgerResponse {

    private Long vendorId;
    private String vendorName;
    private LocalDate fromDate;
    private LocalDate toDate;

    private BigDecimal openingBalance = BigDecimal.ZERO;
    private BigDecimal totalDebit     = BigDecimal.ZERO;
    private BigDecimal totalCredit    = BigDecimal.ZERO;
    private BigDecimal closingBalance = BigDecimal.ZERO;

    private List<LedgerEntry> entries;

    @Data
    public static class LedgerEntry {
        private LocalDate date;
        private String txnType;       // INVOICE | PAYMENT
        private String reference;     // invoice_no or payment ref
        private String description;
        private BigDecimal debit;     // null for payments
        private BigDecimal credit;    // null for invoices
        private BigDecimal runningBalance;
        private Long sourceId;        // id in source table (for linking)
    }
}
