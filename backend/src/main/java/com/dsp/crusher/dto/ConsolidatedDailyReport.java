package com.dsp.crusher.dto;

import lombok.Data;
import java.math.BigDecimal;
import java.time.LocalDate;
import java.util.List;

@Data
public class ConsolidatedDailyReport {

    private LocalDate date;

    private TripsSection trips;
    private DabarSection dabar;
    private WaterTankerSection waterTanker;
    private DieselSection diesel;
    private MachineSection machine;
    private AttendanceSection attendance;
    private FinancialSection financial;

    // ── Sections ──────────────────────────────────────────────────────────────

    @Data
    public static class TripsSection {
        private int tripCount;
        private BigDecimal totalBrass;
        private List<MaterialLine> byMaterial;
        private List<TripRow> trips;

        @Data
        public static class MaterialLine {
            private String materialName;
            private int tripCount;
            private BigDecimal totalBrass;
        }

        @Data
        public static class TripRow {
            private String vehicle;
            private String material;
            private BigDecimal quantityBrass;
            private String unloadingLocation;
            private String channelNo;
            private String dspChallanNo;
            private String vendorChallanNo;
            private String vendor;
        }
    }

    @Data
    public static class DabarSection {
        private int entryCount;
        private int totalTrips;
        private BigDecimal totalBrass;
    }

    @Data
    public static class WaterTankerSection {
        private int entryCount;
        private BigDecimal totalHours;
        private BigDecimal totalKm;
        private int totalTrips;
        private BigDecimal totalAmount;
    }

    @Data
    public static class DieselSection {
        private BigDecimal receivedToday;
        private BigDecimal usedToday;
        private BigDecimal closingStock;   // opening + received - used
        private int receiptCount;
        private int usageCount;
    }

    @Data
    public static class MachineSection {
        private BigDecimal totalHours;
        private BigDecimal bucketHours;
        private BigDecimal breakerHours;
        private int entryCount;
    }

    @Data
    public static class AttendanceSection {
        private int present;
        private int halfDay;
        private int absent;
        private int onLeave;
        private int unmarked;
        private int total;
    }

    @Data
    public static class FinancialSection {
        private int invoiceCount;
        private BigDecimal invoiceTotal;
        private int paymentCount;
        private BigDecimal paymentTotal;
    }
}
