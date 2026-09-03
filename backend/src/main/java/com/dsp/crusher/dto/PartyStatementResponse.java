package com.dsp.crusher.dto;

import lombok.Getter;
import lombok.Setter;
import java.math.BigDecimal;
import java.time.LocalDate;
import java.util.List;

/** Khatabook-style trip+payment unified ledger for a single party. */
@Getter @Setter
public class PartyStatementResponse {
    private Long vendorId;
    private String vendorName;
    private String vendorContact;
    /** True when this party is GST-registered — drives PDF format branching. */
    private Boolean gstRegistered;
    private LocalDate from;
    private LocalDate to;
    private BigDecimal openingBalance;  // balance before 'from' date (positive = owes)
    private BigDecimal totalBilled;
    private BigDecimal totalReceived;
    private BigDecimal closingBalance;  // positive = party owes us; negative = advance

    private List<StatementEntry> entries;

    @Getter @Setter
    public static class StatementEntry {
        private Long id;
        /** BILLED (trip/invoice debit) or RECEIVED (payment credit). */
        private String type;
        private LocalDate date;
        private String description;
        private BigDecimal amount;
        /** Running balance AFTER this entry (positive = owed, negative = advance). */
        private BigDecimal runningBalance;
        /** GST rate snapshot (only set for BILLED trip entries; 0 = non-taxable). */
        private BigDecimal gstRate;
        /** Material-only amount (pre-tax base for SGST/CGST calculation; null for old trips). */
        private BigDecimal materialAmount;
        /** Transportation charge (non-taxable; added to debit separately from GST base). */
        private BigDecimal transportationCharge;
    }
}
