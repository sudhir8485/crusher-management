package com.dsp.crusher.dto;

import lombok.Getter;
import lombok.Setter;
import java.math.BigDecimal;

@Getter @Setter
public class GstInvoiceItemResponse {
    private Long id;
    private String description;
    private String hsn;
    private BigDecimal quantityBrass;
    private BigDecimal rate;
    private BigDecimal amount;
    private Long materialId;
    private Long serviceId;
    /** Per-item GST rate entered by the user. null = PENDING. 0 = zero-rated. */
    private BigDecimal gstRate;
    /** Current GST rate in the linked Material/Service master (null if not configured or no link).
     *  Used by the frontend to show an informational mismatch note — never blocks saving. */
    private BigDecimal masterGstRate;
}
