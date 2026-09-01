package com.dsp.crusher.service;

import com.dsp.crusher.dto.ConsolidatedDailyReport;
import com.dsp.crusher.dto.ConsolidatedDailyReport.*;
import com.dsp.crusher.entity.*;
import com.dsp.crusher.repository.*;
import lombok.RequiredArgsConstructor;
import org.springframework.stereotype.Service;

import java.math.BigDecimal;
import java.time.LocalDate;
import java.util.*;
import java.util.stream.Collectors;

@Service
@RequiredArgsConstructor
public class DailyReportService {

    private final TripRepository tripRepo;
    private final VehicleRepository vehicleRepo;
    private final MaterialRepository materialRepo;
    private final VendorRepository vendorRepo;
    private final DabarEntryRepository dabarRepo;
    private final WaterTankerLogRepository tankerRepo;
    private final DieselReceiptRepository receiptRepo;
    private final DieselUsageRepository usageRepo;
    private final MachineWorkLogRepository machineRepo;
    private final AttendanceRepository attendanceRepo;
    private final EmployeeRepository employeeRepo;
    private final GstInvoiceRepository invoiceRepo;
    private final VendorPaymentRepository paymentRepo;

    public ConsolidatedDailyReport build(LocalDate date) {
        ConsolidatedDailyReport report = new ConsolidatedDailyReport();
        report.setDate(date);
        report.setTrips(buildTrips(date));
        report.setDabar(buildDabar(date));
        report.setWaterTanker(buildWaterTanker(date));
        report.setDiesel(buildDiesel(date));
        report.setMachine(buildMachine(date));
        report.setAttendance(buildAttendance(date));
        report.setFinancial(buildFinancial(date));
        return report;
    }

    // ── Trips ─────────────────────────────────────────────────────────────────

    private TripsSection buildTrips(LocalDate date) {
        List<Trip> trips = tripRepo.findByTripDateAndStatusOrderByIdAsc(date, "ACTIVE");

        Map<Long, Vehicle>  vehicleMap  = vehicleRepo.findAll().stream()
                .collect(Collectors.toMap(Vehicle::getId, v -> v));
        Map<Long, Material> materialMap = materialRepo.findAll().stream()
                .collect(Collectors.toMap(Material::getId, m -> m));
        Map<Long, Vendor>   vendorMap   = vendorRepo.findAll().stream()
                .collect(Collectors.toMap(Vendor::getId, v -> v));

        BigDecimal totalBrass = BigDecimal.ZERO;
        Map<Long, TripsSection.MaterialLine> byMat = new LinkedHashMap<>();
        List<TripsSection.TripRow> rows = new ArrayList<>();

        for (Trip t : trips) {
            BigDecimal brass = t.getQuantityBrass() != null ? t.getQuantityBrass() : BigDecimal.ZERO;
            totalBrass = totalBrass.add(brass);

            Material mat = materialMap.get(t.getMaterialId());
            if (mat != null) {
                TripsSection.MaterialLine ml = byMat.computeIfAbsent(mat.getId(), id -> {
                    TripsSection.MaterialLine l = new TripsSection.MaterialLine();
                    l.setMaterialName(mat.getName() + (mat.getSizeLabel() != null ? " (" + mat.getSizeLabel() + ")" : ""));
                    l.setTripCount(0);
                    l.setTotalBrass(BigDecimal.ZERO);
                    return l;
                });
                ml.setTripCount(ml.getTripCount() + 1);
                ml.setTotalBrass(ml.getTotalBrass().add(brass));
            }

            TripsSection.TripRow row = new TripsSection.TripRow();
            Vehicle v = vehicleMap.get(t.getVehicleId());
            row.setVehicle(v != null ? (v.getDisplayName() != null ? v.getDisplayName() : v.getPlateNumber()) : "—");
            row.setMaterial(mat != null ? mat.getName() : "—");
            row.setQuantityBrass(brass);
            row.setUnloadingLocation(t.getUnloadingLocation());
            row.setChannelNo(t.getChannelNo());
            row.setDspChallanNo(t.getDspChallanNo());
            row.setVendorChallanNo(t.getVendorChallanNo());
            Vendor vnd = t.getVendorId() != null ? vendorMap.get(t.getVendorId()) : null;
            row.setVendor(vnd != null ? vnd.getName() : "—");
            rows.add(row);
        }

        TripsSection s = new TripsSection();
        s.setTripCount(trips.size());
        s.setTotalBrass(totalBrass);
        s.setByMaterial(new ArrayList<>(byMat.values()));
        s.setTrips(rows);
        return s;
    }

    // ── Dabar ─────────────────────────────────────────────────────────────────

    private DabarSection buildDabar(LocalDate date) {
        List<DabarEntry> entries = dabarRepo.findByEntryDateAndStatusOrderByIdAsc(date, "ACTIVE");
        int trips = entries.stream().mapToInt(e -> e.getTripsCount() != null ? e.getTripsCount() : 0).sum();
        BigDecimal brass = entries.stream()
                .map(e -> e.getQuantityBrass() != null ? e.getQuantityBrass() : BigDecimal.ZERO)
                .reduce(BigDecimal.ZERO, BigDecimal::add);
        DabarSection s = new DabarSection();
        s.setEntryCount(entries.size());
        s.setTotalTrips(trips);
        s.setTotalBrass(brass);
        return s;
    }

    // ── Water Tanker ──────────────────────────────────────────────────────────

    private WaterTankerSection buildWaterTanker(LocalDate date) {
        List<WaterTankerLog> logs = tankerRepo.findByLogDateAndStatusOrderByIdAsc(date, "ACTIVE");
        BigDecimal hours  = BigDecimal.ZERO;
        BigDecimal km     = BigDecimal.ZERO;
        BigDecimal amount = BigDecimal.ZERO;
        int trips = 0;
        for (WaterTankerLog l : logs) {
            if (l.getHoursWorked() != null) hours  = hours.add(l.getHoursWorked());
            if (l.getKmRun()       != null) km     = km.add(l.getKmRun());
            if (l.getTripsCount()  != null) trips += l.getTripsCount();
            // Amount = hoursWorked × rate (or tripsCount × rate)
            if (l.getRate() != null) {
                BigDecimal rate = l.getRate();
                if (l.getHoursWorked() != null) {
                    amount = amount.add(l.getHoursWorked().multiply(rate));
                } else if (l.getTripsCount() != null) {
                    amount = amount.add(rate.multiply(java.math.BigDecimal.valueOf(l.getTripsCount())));
                }
            }
        }
        WaterTankerSection s = new WaterTankerSection();
        s.setEntryCount(logs.size());
        s.setTotalHours(hours);
        s.setTotalKm(km);
        s.setTotalTrips(trips);
        s.setTotalAmount(amount);
        return s;
    }

    // ── Diesel ────────────────────────────────────────────────────────────────

    private DieselSection buildDiesel(LocalDate date) {
        List<DieselReceipt> receipts = receiptRepo.findByReceiptDateAndStatusOrderByIdAsc(date, "ACTIVE");
        List<DieselUsage>   usages   = usageRepo.findByUsageDateAndStatusOrderByIdAsc(date, "ACTIVE");

        BigDecimal received = receipts.stream()
                .map(r -> r.getQuantityLiters() != null ? r.getQuantityLiters() : BigDecimal.ZERO)
                .reduce(BigDecimal.ZERO, BigDecimal::add);
        BigDecimal used = usages.stream()
                .map(u -> u.getQuantityLiters() != null ? u.getQuantityLiters() : BigDecimal.ZERO)
                .reduce(BigDecimal.ZERO, BigDecimal::add);

        // Closing stock = all time received - all time used
        BigDecimal totalReceived = receiptRepo.sumTotalReceived();
        BigDecimal totalUsed     = usageRepo.sumTotalUsed();
        BigDecimal closingStock  = totalReceived.subtract(totalUsed);

        DieselSection s = new DieselSection();
        s.setReceivedToday(received);
        s.setUsedToday(used);
        s.setClosingStock(closingStock);
        s.setReceiptCount(receipts.size());
        s.setUsageCount(usages.size());
        return s;
    }

    // ── Machine Work ──────────────────────────────────────────────────────────

    private MachineSection buildMachine(LocalDate date) {
        List<MachineWorkLog> logs = machineRepo.findByLogDateAndStatusOrderByIdDesc(date, "ACTIVE");
        BigDecimal total   = BigDecimal.ZERO;
        BigDecimal bucket  = BigDecimal.ZERO;
        BigDecimal breaker = BigDecimal.ZERO;
        for (MachineWorkLog l : logs) {
            BigDecimal h = l.getTotalHours() != null ? l.getTotalHours() : BigDecimal.ZERO;
            total = total.add(h);
            if ("BREAKER".equals(l.getMode())) breaker = breaker.add(h);
            else                                bucket  = bucket.add(h);
        }
        MachineSection s = new MachineSection();
        s.setEntryCount(logs.size());
        s.setTotalHours(total);
        s.setBucketHours(bucket);
        s.setBreakerHours(breaker);
        return s;
    }

    // ── Attendance ────────────────────────────────────────────────────────────

    private AttendanceSection buildAttendance(LocalDate date) {
        List<AttendanceRecord> records = attendanceRepo.findByAttendanceDateOrderByEmployeeIdAsc(date);
        long totalActive = employeeRepo.findAll().stream()
                .filter(e -> "ACTIVE".equals(e.getStatus())).count();

        int present = 0, halfDay = 0, absent = 0, leave = 0;
        for (AttendanceRecord r : records) {
            switch (r.getStatus()) {
                case "PRESENT"  -> present++;
                case "HALF_DAY" -> halfDay++;
                case "ABSENT"   -> absent++;
                case "LEAVE"    -> leave++;
            }
        }
        int marked = present + halfDay + absent + leave;
        AttendanceSection s = new AttendanceSection();
        s.setPresent(present);
        s.setHalfDay(halfDay);
        s.setAbsent(absent);
        s.setOnLeave(leave);
        s.setTotal((int) totalActive);
        s.setUnmarked(Math.max(0, (int) totalActive - marked));
        return s;
    }

    // ── Financial ─────────────────────────────────────────────────────────────

    private FinancialSection buildFinancial(LocalDate date) {
        List<GstInvoice> invoices = invoiceRepo
                .findByInvoiceDateBetweenAndStatusOrderByInvoiceDateDescIdDesc(date, date, "ACTIVE");
        List<VendorPayment> payments = paymentRepo
                .findByPaymentDateBetweenAndStatusOrderByPaymentDateDescIdDesc(date, date, "ACTIVE");

        BigDecimal invTotal = invoices.stream()
                .map(i -> i.getGrandTotal() != null ? i.getGrandTotal() : BigDecimal.ZERO)
                .reduce(BigDecimal.ZERO, BigDecimal::add);
        BigDecimal payTotal = payments.stream()
                .map(p -> p.getAmount() != null ? p.getAmount() : BigDecimal.ZERO)
                .reduce(BigDecimal.ZERO, BigDecimal::add);

        FinancialSection s = new FinancialSection();
        s.setInvoiceCount(invoices.size());
        s.setInvoiceTotal(invTotal);
        s.setPaymentCount(payments.size());
        s.setPaymentTotal(payTotal);
        return s;
    }
}
