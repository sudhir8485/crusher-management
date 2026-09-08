package com.dsp.crusher.dto;

import lombok.AllArgsConstructor;
import lombok.Getter;
import lombok.NoArgsConstructor;
import lombok.Setter;
import java.math.BigDecimal;
import java.time.LocalDate;
import java.util.List;
import java.util.Map;

@Getter @Setter @NoArgsConstructor
public class AutoQtyResponse {
    /** Computed total quantity of UNbilled records — what to pre-fill on the invoice line. */
    private BigDecimal quantity;
    /** Unit of the computed quantity — matches the service's defaultUnit (BRASS or TON). */
    private String unit;
    /** Number of unbilled underlying records summed. */
    private int count;
    /** TRIP_QUANTITIES | DABAR_QUANTITIES */
    private String source;
    /** Unbilled records for transparency drill-down. */
    private List<Map<String, Object>> records;

    /** Count of records in this period already billed by a previous invoice. */
    private int billedCount;
    /** Sum of already-billed records' quantities in this period. */
    private BigDecimal billedQuantity;
    /** Invoice number that billed the already-billed records (first invoice found, for the "no new trips" message). */
    private String billedByInvoiceNo;

    /** Non-null when an existing invoice's period overlaps the requested period for the same site+service. */
    private OverlapInfo overlappingInvoice;

    @Getter @Setter @AllArgsConstructor @NoArgsConstructor
    public static class OverlapInfo {
        private String invoiceNo;
        private LocalDate periodFrom;
        private LocalDate periodTo;
    }
}
