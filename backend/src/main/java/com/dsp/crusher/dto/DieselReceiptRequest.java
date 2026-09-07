package com.dsp.crusher.dto;

import jakarta.validation.constraints.NotNull;
import lombok.Getter;
import lombok.Setter;
import java.math.BigDecimal;
import java.time.LocalDate;

@Getter @Setter
public class DieselReceiptRequest {
    @NotNull private LocalDate receiptDate;
    @NotNull private String source;           // PUMP | DIRECT | PARTY_ADVANCE
    @NotNull private BigDecimal quantityLiters;
    private BigDecimal ratePerLiter;          // PUMP / DIRECT only
    private Long vendorId;                    // PUMP / DIRECT supplier (optional)
    private String invoiceNo;                 // PUMP / DIRECT only
    private String notes;
    // PARTY_ADVANCE fields
    private Long advancePartyId;              // required when source=PARTY_ADVANCE
    private BigDecimal advanceAmount;         // ₹ advanced by the party (may differ from qty×rate)
}
