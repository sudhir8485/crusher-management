package com.dsp.crusher.dto;

import lombok.Getter;
import lombok.Setter;
import java.math.BigDecimal;

@Getter @Setter
public class JobWorkInvoiceItemResponse {
    private Long id;
    private Long serviceId;
    private String description;
    private String sacCode;
    private BigDecimal quantity;
    private BigDecimal rate;
    private BigDecimal amount;
}
