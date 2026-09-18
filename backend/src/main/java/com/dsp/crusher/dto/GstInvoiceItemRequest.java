package com.dsp.crusher.dto;

import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.NotNull;
import lombok.Getter;
import lombok.Setter;
import java.math.BigDecimal;

@Getter @Setter
public class GstInvoiceItemRequest {

    @NotBlank
    private String description;

    private String hsn;

    private BigDecimal quantityBrass;

    private BigDecimal rate;

    @NotNull
    private BigDecimal amount;

    /** Optional — links this line item to a Material Master record. */
    private Long materialId;

    /** Optional — links this line item to a Service Master record. */
    private Long serviceId;

    /** Combined GST rate for this line item (e.g. 18 → SGST 9% + CGST 9%).
     *  null = PENDING (invoice line unresolved); 0 = zero-rated (resolved, no tax). */
    private BigDecimal gstRate;
}
