package com.dsp.crusher.dto;

import lombok.Getter;
import lombok.Setter;
import java.math.BigDecimal;
import java.time.LocalDate;
import java.time.LocalDateTime;
import java.util.List;

@Getter @Setter
public class GstInvoiceResponse {
    private Long id;
    private Long vendorId;
    private String vendorName;
    private String vendorGstin;
    private String invoiceNo;
    private LocalDate invoiceDate;
    private LocalDate supplyDate;
    private String poNo;
    private BigDecimal cgstRate;
    private BigDecimal sgstRate;
    private BigDecimal subtotal;
    private BigDecimal cgstAmount;
    private BigDecimal sgstAmount;
    private BigDecimal grandTotal;
    private String notes;
    private String status;
    private List<GstInvoiceItemResponse> items;

    // Computed payment info
    private BigDecimal totalPaid;
    private BigDecimal outstandingAmount;
    private String paymentStatus;   // UNPAID | PARTIAL | PAID

    // GST status
    private String gstStatus;       // PENDING | SET

    // Recalculate-GST audit trail
    private String gstRecalculatedBy;
    private LocalDateTime gstRecalculatedAt;
    private BigDecimal gstPrevSgstRate;
    private BigDecimal gstPrevCgstRate;

    private LocalDateTime createdAt;
    private String createdByName;
    private String updatedByName;
}
