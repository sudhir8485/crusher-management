package com.dsp.crusher.service;

import com.dsp.crusher.config.SiteContext;
import com.dsp.crusher.dto.ReportResponse;
import com.dsp.crusher.dto.ReportResponse.Row;
import com.dsp.crusher.dto.ReportResponse.Summary;
import com.dsp.crusher.entity.*;
import com.dsp.crusher.repository.*;
import com.dsp.crusher.entity.Employee;
import lombok.RequiredArgsConstructor;
import org.springframework.security.core.Authentication;
import org.springframework.security.core.context.SecurityContextHolder;
import org.springframework.stereotype.Service;

import java.math.BigDecimal;
import java.time.LocalDate;
import java.util.*;
import java.util.stream.Collectors;

@Service
@RequiredArgsConstructor
public class ReportService {

    private final VehicleRepository vehicleRepo;
    private final MachineWorkLogRepository machineWorkRepo;
    private final MachineRepository machineRepo;
    private final DieselReceiptRepository receiptRepo;
    private final DieselUsageRepository usageRepo;
    private final TripRepository tripRepo;
    private final MaterialRepository materialRepo;
    private final VendorRepository vendorRepo;
    private final DabarEntryRepository dabarRepo;
    private final AttendanceRepository attendanceRepo;
    private final EmployeeRepository employeeRepo;

    private Long effectiveSiteId() {
        Authentication auth = SecurityContextHolder.getContext().getAuthentication();
        boolean isSiteStaff = auth != null && auth.getAuthorities().stream()
                .anyMatch(a -> a.getAuthority().equals("ROLE_SITE_STAFF"));
        return isSiteStaff ? SiteContext.get() : null;
    }

    private Long resolvedSiteId(Long paramSiteId) {
        Long forced = effectiveSiteId();
        return forced != null ? forced : paramSiteId;
    }

    // ── Machine Work Report ───────────────────────────────────────────────────

    public ReportResponse machineWorkReport(Long machineId, Long siteId, LocalDate from, LocalDate to) {
        siteId = resolvedSiteId(siteId);

        List<MachineWorkLog> logs;
        String filterLabel;

        if (machineId != null) {
            logs = machineWorkRepo.findByMachineIdAndDateRangeAndSite(machineId, from, to, siteId);
            filterLabel = machineRepo.findById(machineId)
                    .map(Machine::getName)
                    .orElse("Machine " + machineId);
        } else {
            logs = machineWorkRepo.findByDateRangeAndSiteAsc(from, to, siteId);
            filterLabel = "All Machines";
        }

        Map<Long, Machine> machineMap = machineRepo.findAll().stream()
                .collect(Collectors.toMap(Machine::getId, m -> m));

        BigDecimal totalHours = BigDecimal.ZERO;
        BigDecimal bucketHours = BigDecimal.ZERO;
        BigDecimal breakerHours = BigDecimal.ZERO;
        List<Row> rows = new ArrayList<>();

        for (MachineWorkLog l : logs) {
            Machine m = machineMap.get(l.getMachineId());
            String machineName = m != null ? m.getName() : "—";
            BigDecimal hrs = l.getTotalHours() != null ? l.getTotalHours() : BigDecimal.ZERO;
            totalHours = totalHours.add(hrs);
            if ("BUCKET".equals(l.getMode())) {
                bucketHours = bucketHours.add(hrs);
            } else {
                breakerHours = breakerHours.add(hrs);
            }

            Row row = new Row();
            row.setDate(l.getLogDate());
            row.setCol1(machineName);
            row.setCol2(l.getMode() != null ? l.getMode() : "BUCKET");
            row.setCol3(l.getWorkDescription() != null ? l.getWorkDescription() : "—");
            row.setCol4(l.getOpeningReading() != null ? l.getOpeningReading().toPlainString() : "—");
            row.setCol5(l.getClosingReading() != null ? l.getClosingReading().toPlainString() : "—");
            row.setCol6(hrs.compareTo(BigDecimal.ZERO) > 0 ? hrs.toPlainString() + " hrs" : "—");
            row.setCol7(l.getNotes() != null ? l.getNotes() : "");
            rows.add(row);
        }

        Summary summary = new Summary();
        summary.setTotalRows(rows.size());
        summary.setTotalHours(totalHours);
        summary.setBucketHours(bucketHours);
        summary.setBreakerHours(breakerHours);

        ReportResponse res = new ReportResponse();
        res.setReportType("MACHINE_WORK");
        res.setFromDate(from);
        res.setToDate(to);
        res.setFilterLabel(filterLabel);
        res.setSummary(summary);
        res.setRows(rows);
        return res;
    }

    // ── Diesel Report ─────────────────────────────────────────────────────────

    public ReportResponse dieselReport(Long siteId, LocalDate from, LocalDate to) {
        siteId = resolvedSiteId(siteId);

        BigDecimal openingReceived = receiptRepo.sumReceivedBeforeAndSite(from, siteId);
        BigDecimal openingUsed     = usageRepo.sumUsedBeforeAndSite(from, siteId);
        BigDecimal openingStock    = openingReceived.subtract(openingUsed);

        List<DieselReceipt> receipts = receiptRepo.findByDateRangeAndSite(from, to, siteId);
        List<DieselUsage> usages = usageRepo.findByDateRangeAndSite(from, to, siteId);

        Map<Long, Vendor> vendorMap = vendorRepo.findAll().stream()
                .collect(Collectors.toMap(Vendor::getId, v -> v));
        Map<Long, Machine> machineMap = machineRepo.findAll().stream()
                .collect(Collectors.toMap(Machine::getId, m -> m));
        Map<Long, Vehicle> vehicleMap = vehicleRepo.findAll().stream()
                .collect(Collectors.toMap(Vehicle::getId, v -> v));

        List<Row> rows = new ArrayList<>();
        BigDecimal running = openingStock;
        BigDecimal totalReceived = BigDecimal.ZERO;
        BigDecimal totalUsed = BigDecimal.ZERO;

        record DieselEntry(LocalDate date, boolean isReceipt, Object obj) {}
        List<DieselEntry> all = new ArrayList<>();
        receipts.forEach(r -> all.add(new DieselEntry(r.getReceiptDate(), true, r)));
        usages.forEach(u -> all.add(new DieselEntry(u.getUsageDate(), false, u)));
        all.sort(Comparator.comparing(DieselEntry::date)
                .thenComparing(e -> e.isReceipt() ? 0 : 1));

        for (DieselEntry e : all) {
            Row row = new Row();
            row.setDate(e.date());
            if (e.isReceipt()) {
                DieselReceipt r = (DieselReceipt) e.obj();
                BigDecimal qty = r.getQuantityLiters() != null ? r.getQuantityLiters() : BigDecimal.ZERO;
                running = running.add(qty);
                totalReceived = totalReceived.add(qty);
                String vendor = r.getVendorId() != null && vendorMap.containsKey(r.getVendorId())
                        ? vendorMap.get(r.getVendorId()).getName() : "—";
                row.setCol1("RECEIVED");
                row.setCol2(r.getSource() != null ? r.getSource() : "PUMP");
                row.setCol3(qty.toPlainString() + " L");
                row.setCol4(vendor);
                row.setCol5(r.getAmount() != null ? "₹" + r.getAmount().toPlainString() : "—");
                row.setCol6(running.toPlainString() + " L");
                row.setCol7(r.getNotes() != null ? r.getNotes() : "");
            } else {
                DieselUsage u = (DieselUsage) e.obj();
                BigDecimal qty = u.getQuantityLiters() != null ? u.getQuantityLiters() : BigDecimal.ZERO;
                running = running.subtract(qty);
                totalUsed = totalUsed.add(qty);
                String consumer;
                if (u.getMachineId() != null && machineMap.containsKey(u.getMachineId())) {
                    consumer = machineMap.get(u.getMachineId()).getName();
                } else if (u.getVehicleId() != null && vehicleMap.containsKey(u.getVehicleId())) {
                    Vehicle v = vehicleMap.get(u.getVehicleId());
                    consumer = v.getDisplayName() != null ? v.getDisplayName() : v.getPlateNumber();
                } else {
                    consumer = "—";
                }
                row.setCol1("USED");
                row.setCol2(consumer);
                row.setCol3(qty.toPlainString() + " L");
                row.setCol4("—");
                row.setCol5("—");
                row.setCol6(running.toPlainString() + " L");
                row.setCol7(u.getNotes() != null ? u.getNotes() : "");
            }
            rows.add(row);
        }

        Summary summary = new Summary();
        summary.setTotalRows(rows.size());
        summary.setOpeningStock(openingStock);
        summary.setTotalReceived(totalReceived);
        summary.setTotalUsed(totalUsed);
        summary.setClosingStock(openingStock.add(totalReceived).subtract(totalUsed));

        ReportResponse res = new ReportResponse();
        res.setReportType("DIESEL");
        res.setFromDate(from);
        res.setToDate(to);
        res.setFilterLabel("All");
        res.setSummary(summary);
        res.setRows(rows);
        return res;
    }

    // ── Trips Report ──────────────────────────────────────────────────────────

    public ReportResponse tripsReport(Long vehicleId, Long materialId, Long vendorId,
                                       Long siteId, LocalDate from, LocalDate to) {
        siteId = resolvedSiteId(siteId);

        List<Trip> trips;
        String filterLabel;

        if (vehicleId != null) {
            trips = tripRepo.findByVehicleIdAndDateRangeAndSite(vehicleId, from, to, siteId);
            filterLabel = vehicleRepo.findById(vehicleId)
                    .map(v -> v.getDisplayName() != null ? v.getDisplayName() : v.getPlateNumber())
                    .orElse("Vehicle " + vehicleId);
        } else if (materialId != null) {
            trips = tripRepo.findByMaterialIdAndDateRangeAndSite(materialId, from, to, siteId);
            filterLabel = materialRepo.findById(materialId)
                    .map(Material::getName)
                    .orElse("Material " + materialId);
        } else if (vendorId != null) {
            trips = tripRepo.findByVendorIdAndDateRangeAndSite(vendorId, from, to, siteId);
            filterLabel = vendorRepo.findById(vendorId)
                    .map(Vendor::getName)
                    .orElse("Vendor " + vendorId);
        } else {
            trips = tripRepo.findByDateRangeAndSiteAsc(from, to, siteId);
            filterLabel = "All Trips";
        }

        Map<Long, Vehicle> vehicleMap = vehicleRepo.findAll().stream()
                .collect(Collectors.toMap(Vehicle::getId, v -> v));
        Map<Long, Material> materialMap = materialRepo.findAll().stream()
                .collect(Collectors.toMap(Material::getId, m -> m));
        Map<Long, Vendor> vendorMap = vendorRepo.findAll().stream()
                .collect(Collectors.toMap(Vendor::getId, v -> v));

        BigDecimal totalBrass = BigDecimal.ZERO;
        List<Row> rows = new ArrayList<>();

        for (Trip t : trips) {
            Vehicle v = vehicleMap.get(t.getVehicleId());
            Material m = materialMap.get(t.getMaterialId());
            Vendor vnd = t.getVendorId() != null ? vendorMap.get(t.getVendorId()) : null;

            String vehicleName = v != null
                    ? (v.getDisplayName() != null ? v.getDisplayName() : v.getPlateNumber()) : "—";
            String matName = m != null ? m.getName() : "—";
            String vendorName = vnd != null ? vnd.getName() : "—";

            BigDecimal brass = t.getQuantityBrass() != null ? t.getQuantityBrass() : BigDecimal.ZERO;
            totalBrass = totalBrass.add(brass);

            Row row = new Row();
            row.setDate(t.getTripDate());
            row.setCol1(vehicleName);
            row.setCol2(matName);
            row.setCol3(brass.compareTo(BigDecimal.ZERO) > 0 ? brass.toPlainString() + " Brass" : "—");
            row.setCol4(vendorName);
            String challan = buildChallan(t.getDspChallanNo(), t.getVendorChallanNo());
            row.setCol5(challan);
            row.setCol6(t.getChannelNo() != null ? t.getChannelNo() : "—");
            row.setCol7(t.getLoadingLocation() != null ? t.getLoadingLocation() : "—");
            rows.add(row);
        }

        Summary summary = new Summary();
        summary.setTotalRows(rows.size());
        summary.setTripCount(rows.size());
        summary.setTotalBrass(totalBrass);

        ReportResponse res = new ReportResponse();
        res.setReportType("TRIPS");
        res.setFromDate(from);
        res.setToDate(to);
        res.setFilterLabel(filterLabel);
        res.setSummary(summary);
        res.setRows(rows);
        return res;
    }

    // ── Dabar Report ──────────────────────────────────────────────────────────

    public ReportResponse dabarReport(Long vehicleId, Long vendorId, Long siteId, LocalDate from, LocalDate to) {
        siteId = resolvedSiteId(siteId);

        List<DabarEntry> entries = dabarRepo.findByDateRangeAndFilters(from, to, siteId, vehicleId, vendorId);

        Map<Long, Vehicle> vehicleMap = vehicleRepo.findAll().stream()
                .collect(Collectors.toMap(Vehicle::getId, v -> v));
        Map<Long, Vendor> vendorMap = vendorRepo.findAll().stream()
                .collect(Collectors.toMap(Vendor::getId, v -> v));

        String filterLabel = "All Dabar";
        if (vehicleId != null) {
            Vehicle v = vehicleMap.get(vehicleId);
            filterLabel = v != null ? (v.getDisplayName() != null ? v.getDisplayName() : v.getPlateNumber()) : "Vehicle " + vehicleId;
        } else if (vendorId != null) {
            Vendor vnd = vendorMap.get(vendorId);
            filterLabel = vnd != null ? vnd.getName() : "Vendor " + vendorId;
        }

        BigDecimal totalBrass = BigDecimal.ZERO;
        int totalTrips = 0;
        List<Row> rows = new ArrayList<>();

        for (DabarEntry d : entries) {
            Vehicle v = d.getVehicleId() != null ? vehicleMap.get(d.getVehicleId()) : null;
            Vendor vnd = d.getVendorId() != null ? vendorMap.get(d.getVendorId()) : null;

            String vehicleName = v != null ? (v.getDisplayName() != null ? v.getDisplayName() : v.getPlateNumber()) : "—";
            String vendorName = vnd != null ? vnd.getName() : "—";

            BigDecimal brass = d.getQuantityBrass() != null ? d.getQuantityBrass() : BigDecimal.ZERO;
            int trips = d.getTripsCount() != null ? d.getTripsCount() : 0;
            totalBrass = totalBrass.add(brass);
            totalTrips += trips;

            Row row = new Row();
            row.setDate(d.getEntryDate());
            row.setCol1(vehicleName);
            row.setCol2(vendorName);
            row.setCol3(trips > 0 ? String.valueOf(trips) : "—");
            row.setCol4(brass.compareTo(BigDecimal.ZERO) > 0 ? brass.toPlainString() + " Brass" : "—");
            row.setCol5(d.getNotes() != null ? d.getNotes() : "");
            rows.add(row);
        }

        Summary summary = new Summary();
        summary.setTotalRows(rows.size());
        summary.setTripCount(totalTrips);
        summary.setTotalBrass(totalBrass);

        ReportResponse res = new ReportResponse();
        res.setReportType("DABAR");
        res.setFromDate(from);
        res.setToDate(to);
        res.setFilterLabel(filterLabel);
        res.setSummary(summary);
        res.setRows(rows);
        return res;
    }

    // ── Attendance Report ─────────────────────────────────────────────────────

    public ReportResponse attendanceReport(Long employeeId, Long siteId, LocalDate from, LocalDate to) {
        siteId = resolvedSiteId(siteId);

        List<AttendanceRecord> records = attendanceRepo.findByDateRangeAndFilters(from, to, siteId, employeeId);

        Map<Long, Employee> employeeMap = employeeRepo.findAll().stream()
                .collect(Collectors.toMap(Employee::getId, e -> e));

        String filterLabel = "All Employees";
        if (employeeId != null) {
            Employee emp = employeeMap.get(employeeId);
            filterLabel = emp != null ? emp.getName() : "Employee " + employeeId;
        }

        int presentCount = 0, absentCount = 0, halfDayCount = 0, leaveCount = 0;
        List<Row> rows = new ArrayList<>();

        for (AttendanceRecord r : records) {
            Employee emp = employeeMap.get(r.getEmployeeId());
            String empName = emp != null ? emp.getName() : "Employee " + r.getEmployeeId();

            switch (r.getStatus() != null ? r.getStatus() : "") {
                case "PRESENT"  -> presentCount++;
                case "ABSENT"   -> absentCount++;
                case "HALF_DAY" -> halfDayCount++;
                case "LEAVE"    -> leaveCount++;
            }

            Row row = new Row();
            row.setDate(r.getAttendanceDate());
            row.setCol1(empName);
            row.setCol2(r.getStatus() != null ? r.getStatus() : "—");
            row.setCol3(r.getNotes() != null ? r.getNotes() : "");
            rows.add(row);
        }

        Summary summary = new Summary();
        summary.setTotalRows(rows.size());
        summary.setPresentCount(presentCount);
        summary.setAbsentCount(absentCount);
        summary.setHalfDayCount(halfDayCount);
        summary.setLeaveCount(leaveCount);

        ReportResponse res = new ReportResponse();
        res.setReportType("ATTENDANCE");
        res.setFromDate(from);
        res.setToDate(to);
        res.setFilterLabel(filterLabel);
        res.setSummary(summary);
        res.setRows(rows);
        return res;
    }

    // ── Helpers ───────────────────────────────────────────────────────────────

    private String dayNightStr(Integer day, Integer night) {
        List<String> parts = new ArrayList<>();
        if (day != null && day > 0) parts.add(day + " day");
        if (night != null && night > 0) parts.add(night + " night");
        return parts.isEmpty() ? "—" : String.join(" + ", parts);
    }

    private String buildChallan(String dsp, String vdr) {
        List<String> parts = new ArrayList<>();
        if (dsp != null && !dsp.isBlank()) parts.add("DSP: " + dsp);
        if (vdr != null && !vdr.isBlank()) parts.add("Vdr: " + vdr);
        return parts.isEmpty() ? "—" : String.join(" / ", parts);
    }
}
