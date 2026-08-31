package com.dsp.crusher.dto;

import lombok.Getter;
import lombok.Setter;
import java.math.BigDecimal;
import java.time.LocalDate;
import java.util.List;

@Getter @Setter
public class DashboardResponse {

    private LocalDate asOf;

    // Today
    private long todayTripCount;
    private BigDecimal todayTotalBrass;

    // Diesel
    private BigDecimal dieselBalanceLiters;
    private BigDecimal dieselTotalReceived;
    private BigDecimal dieselTotalUsed;

    // This month
    private BigDecimal monthlyMachineHours;
    private BigDecimal monthlyInvoiceTotal;
    private long monthlyInvoiceCount;
    private BigDecimal monthlyPaymentsTotal;

    // Month trip summary by material
    private List<MaterialSummary> monthlyTripSummary;

    @Getter @Setter
    public static class MaterialSummary {
        private Long materialId;
        private String materialName;
        private String sizeLabel;
        private long tripCount;
        private BigDecimal totalBrass;
    }
}
