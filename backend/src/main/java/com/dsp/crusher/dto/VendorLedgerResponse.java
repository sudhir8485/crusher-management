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
        private String particulars;    // "To (as per details)" or "By BANK – REF123"
        private String voucherType;    // "Sales" | "Receipt"
        private String invoiceNo;      // set for invoice rows
        private BigDecimal debit;
        private BigDecimal credit;
        private BigDecimal runningBalance;
        private Long sourceId;
        private List<DetailLine> details;  // breakdown lines (invoice only)
    }

    @Data
    public static class DetailLine {
        private String label;    // "Sales", "SGST 9.00%", "CGST 9.00%", "Round Off"
        private BigDecimal amount;
    }
}
