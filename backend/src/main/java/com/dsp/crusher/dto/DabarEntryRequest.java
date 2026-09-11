package com.dsp.crusher.dto;

import jakarta.validation.constraints.NotNull;
import lombok.Getter;
import lombok.Setter;
import java.math.BigDecimal;
import java.time.LocalDate;

@Getter @Setter
public class DabarEntryRequest {
    @NotNull private LocalDate entryDate;
    @NotNull private Long vehicleId;
    private Long vendorId;
    private Integer tripsCount;
    private BigDecimal quantityBrass;
    private String notes;

    /**
     * When true, creates a transport payable to the vehicle's owning party.
     * Only valid when the vehicle is VENDOR-owned and that party differs from the site's billed party.
     * null = no change on update; false = deactivate any existing payable.
     */
    private Boolean createTransportPayable;

    /**
     * Agreed transport amount to store on the payable (does NOT auto-settle — settlement
     * happens only via a PAID direction VendorPayment linked to the payable).
     * null = no change to existing amount.
     */
    private java.math.BigDecimal transportPayableAmount;
}
