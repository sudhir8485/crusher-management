package com.dsp.crusher.dto;

import lombok.Getter;
import lombok.Setter;
import java.math.BigDecimal;
import java.time.LocalDate;
import java.util.List;

@Getter @Setter
public class PayrollSummaryResponse {

    private Long employeeId;
    private String employeeName;
    private String designation;
    private String wageType;      // DAILY | MONTHLY
    private BigDecimal wageRate;

    private LocalDate from;
    private LocalDate to;

    // Attendance counts for the period
    private int presentCount;
    private int halfDayCount;
    private int absentCount;
    private int leaveCount;

    // Financials — period
    private BigDecimal earnedAmount;   // earned from attendance in selected period
    private BigDecimal advancesPaid;   // payments made in selected period

    // Financials — cumulative (all-time)
    private BigDecimal openingBalance; // all earned before period − all paid before period
    private BigDecimal closingBalance; // opening + earned − paid  (= true all-time balance owed)
    private BigDecimal balanceOwed;    // same as closingBalance (kept for backward compat)

    // Advance entries (populated in detail view; empty in list view)
    private List<AdvanceEntry> advances;

    @Getter @Setter
    public static class AdvanceEntry {
        private Long id;
        private LocalDate paymentDate;
        private BigDecimal amount;
        private String paymentType;    // ADVANCE | SALARY
        private String paymentMethod;  // CASH | BANK_TRANSFER | UPI | OTHER
        private String notes;
    }
}
