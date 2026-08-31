package com.dsp.crusher.dto;

import lombok.Getter;
import lombok.Setter;
import java.math.BigDecimal;
import java.time.LocalDate;

@Getter @Setter
public class VendorPaymentResponse {
    private Long id;
    private Long vendorId;
    private String vendorName;
    private LocalDate paymentDate;
    private BigDecimal amount;
    private String paymentMode;
    private String referenceNo;
    private String notes;
    private String status;
}
