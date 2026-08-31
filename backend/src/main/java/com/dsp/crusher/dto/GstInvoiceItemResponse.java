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
}
