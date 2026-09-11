package com.dsp.crusher.dto;

import lombok.Getter;
import lombok.Setter;
import java.math.BigDecimal;
import java.time.LocalDate;
import java.time.LocalDateTime;

@Getter @Setter
public class DieselReceiptResponse {
    private Long id;
    private LocalDate receiptDate;
    private String source;           // PUMP | DIRECT | PARTY_ADVANCE
    private BigDecimal quantityLiters;
    private BigDecimal ratePerLiter;
    private BigDecimal amount;
    private Long vendorId;
    private String vendorName;
    private String invoiceNo;
    private String notes;
    // PARTY_ADVANCE enrichment
    private Long advancePartyId;
    private String advancePartyName;
    private BigDecimal advanceAmount; // the ₹ credited to that party's ledger
    private LocalDateTime createdAt;
    private String createdByName;
    private String updatedByName;
}
