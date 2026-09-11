package com.dsp.crusher.dto;

import jakarta.validation.constraints.NotNull;
import lombok.Getter;
import lombok.Setter;
import java.math.BigDecimal;
import java.time.LocalDate;

@Getter @Setter
public class VendorPaymentRequest {

    @NotNull
    private Long vendorId;

    @NotNull
    private LocalDate paymentDate;

    @NotNull
    private BigDecimal amount;

    @NotNull
    private String paymentMode = "CASH";  // CASH | BANK | CHEQUE | UPI

    private String referenceNo;
    private String notes;
    private Long invoiceId;            // optional — link to a specific GST invoice
    private String direction = "RECEIVED"; // RECEIVED | PAID
    private Long transportPayableId;   // optional — PAID payment settling a transport payable
}
