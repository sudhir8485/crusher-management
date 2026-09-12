package com.dsp.crusher.service;

import com.dsp.crusher.config.SiteContext;
import com.dsp.crusher.dto.AttendanceDayResponse;
import com.dsp.crusher.dto.DashboardResponse;
import com.dsp.crusher.entity.DabarEntry;
import com.dsp.crusher.entity.Material;
import com.dsp.crusher.entity.Vendor;
import com.dsp.crusher.repository.*;
import com.dsp.crusher.repository.JobWorkInvoiceRepository;
import lombok.RequiredArgsConstructor;
import org.springframework.stereotype.Service;

import java.math.BigDecimal;
import java.time.LocalDate;
import java.util.ArrayList;
import java.util.Comparator;
import java.util.HashMap;
import java.util.List;
import java.util.Map;
import java.util.stream.Collectors;

@Service
@RequiredArgsConstructor
public class DashboardService {

    private final TripRepository tripRepo;
    private final DieselReceiptRepository receiptRepo;
    private final DieselUsageRepository usageRepo;
    private final MachineWorkLogRepository machineRepo;
    private final GstInvoiceRepository invoiceRepo;
    private final VendorPaymentRepository paymentRepo;
    private final MaterialRepository materialRepo;
    private final AttendanceService attendanceService;
    private final DabarEntryRepository dabarRepo;
    private final VendorRepository vendorRepo;
    private final JobWorkInvoiceRepository jobWorkInvoiceRepo;

    public DashboardResponse get() {
        LocalDate today = LocalDate.now();
        LocalDate monthStart = today.withDayOfMonth(1);

        DashboardResponse r = new DashboardResponse();
        r.setAsOf(today);

        Long siteId = SiteContext.get();

        // Today's trips
        r.setTodayTripCount(tripRepo.countByDateAndSite(today, siteId));
        r.setTodayTotalBrass(tripRepo.sumBrassByDateAndSite(today, siteId));

        // Diesel balance
        BigDecimal received = receiptRepo.sumTotalReceivedBySite(siteId);
        BigDecimal used = usageRepo.sumTotalUsedBySite(siteId);
        r.setDieselTotalReceived(received);
        r.setDieselTotalUsed(used);
        r.setDieselBalanceLiters(received.subtract(used));

        // This month
        r.setMonthlyMachineHours(machineRepo.sumHoursByDateRangeAndSite(monthStart, today, siteId));
        r.setMonthlyInvoiceTotal(invoiceRepo.sumGrandTotalByDateRange(monthStart, today));
        r.setMonthlyInvoiceCount(invoiceRepo.countByInvoiceDateBetweenAndStatus(monthStart, today, "ACTIVE"));
        r.setMonthlyPaymentsTotal(paymentRepo.sumByDateRange(monthStart, today));

        // Today's attendance
        AttendanceDayResponse att = attendanceService.getDay(today);
        r.setTodayAttendancePresent(att.getPresentCount());
        r.setTodayAttendanceTotal(att.getEmployees().size());

        // Today's machine hours
        r.setTodayMachineHours(machineRepo.sumHoursByDateRangeAndSite(today, today, siteId));

        // Today's dabar brass
        List<DabarEntry> dabarToday = dabarRepo.findByEntryDateAndStatusOrderByIdAsc(today, "ACTIVE");
        BigDecimal dabarBrass = dabarToday.stream()
                .map(e -> e.getQuantityBrass() != null ? e.getQuantityBrass() : BigDecimal.ZERO)
                .reduce(BigDecimal.ZERO, BigDecimal::add);
        r.setTodayDabarBrass(dabarBrass);

        // Financial position (all-time)
        BigDecimal totalInv = invoiceRepo.sumAllGrandTotal();
        BigDecimal totalPaid = paymentRepo.sumAllLinkedPayments();
        r.setTotalInvoiced(totalInv);
        r.setTotalPaymentsLinked(totalPaid);
        r.setTotalOutstanding(totalInv.subtract(totalPaid));

        // Monthly trip summary by material
        List<Object[]> rows = tripRepo.summarizeByMaterialAndSite(monthStart, today, siteId);
        List<Long> matIds = rows.stream()
                .map(row -> (Long) row[0]).collect(Collectors.toList());
        Map<Long, Material> materials = materialRepo.findAllById(matIds).stream()
                .collect(Collectors.toMap(Material::getId, m -> m));

        List<DashboardResponse.MaterialSummary> summary = rows.stream().map(row -> {
            DashboardResponse.MaterialSummary ms = new DashboardResponse.MaterialSummary();
            ms.setMaterialId((Long) row[0]);
            ms.setTripCount((Long) row[1]);
            ms.setTotalBrass((BigDecimal) row[2]);
            Material m = materials.get(row[0]);
            if (m != null) {
                ms.setMaterialName(m.getName());
                ms.setSizeLabel(m.getSizeLabel());
            }
            return ms;
        }).collect(Collectors.toList());

        r.setMonthlyTripSummary(summary);

        // Today's financial
        r.setTodayInvoiceTotal(invoiceRepo.sumGrandTotalByDateRange(today, today));
        r.setTodayInvoiceCount(invoiceRepo.countByInvoiceDateAndStatus(today, "ACTIVE"));
        r.setTodayCollectionsTotal(paymentRepo.sumByDateRange(today, today));
        r.setTodayCollectionsCount(paymentRepo.countByPaymentDateAndStatus(today, "ACTIVE"));

        // Top outstanding parties (top 10)
        List<Vendor> vendors = vendorRepo.findByStatus("ACTIVE");
        List<DashboardResponse.ReceivableParty> receivables = vendors.stream()
                .map(v -> {
                    BigDecimal invTotal = invoiceRepo.sumAllGrandTotalByVendorId(v.getId());
                    BigDecimal paidTotal = paymentRepo.sumByVendorId(v.getId());
                    BigDecimal outstanding = invTotal.subtract(paidTotal);
                    DashboardResponse.ReceivableParty rp = new DashboardResponse.ReceivableParty();
                    rp.setVendorId(v.getId());
                    rp.setVendorName(v.getName());
                    rp.setOutstandingBalance(outstanding);
                    return rp;
                })
                .filter(rp -> rp.getOutstandingBalance().compareTo(BigDecimal.ZERO) > 0)
                .sorted(Comparator.comparing(DashboardResponse.ReceivableParty::getOutstandingBalance).reversed())
                .limit(10)
                .collect(Collectors.toList());
        r.setReceivableParties(receivables);

        // Daily trend for current month
        Map<LocalDate, BigDecimal> dailyInv = new HashMap<>();
        invoiceRepo.sumDailyByDateRange(monthStart, today)
                .forEach(row -> dailyInv.put((LocalDate) row[0], (BigDecimal) row[1]));
        Map<LocalDate, BigDecimal> dailyPay = new HashMap<>();
        paymentRepo.sumDailyByDateRange(monthStart, today)
                .forEach(row -> dailyPay.put((LocalDate) row[0], (BigDecimal) row[1]));
        List<DashboardResponse.DailyTrend> trends = new ArrayList<>();
        for (LocalDate d = monthStart; !d.isAfter(today); d = d.plusDays(1)) {
            DashboardResponse.DailyTrend dt = new DashboardResponse.DailyTrend();
            dt.setDay(d.getDayOfMonth());
            dt.setInvoiceTotal(dailyInv.getOrDefault(d, BigDecimal.ZERO));
            dt.setPaymentTotal(dailyPay.getOrDefault(d, BigDecimal.ZERO));
            trends.add(dt);
        }
        r.setMonthlyTrend(trends);

        // Billing breakdown by source (base amounts, net of GST for trip components)
        r.setMonthlyMaterialSales(tripRepo.sumMaterialAmountByDateRangeAndSite(monthStart, today, siteId));
        r.setMonthlyTransportation(tripRepo.sumTransportationByDateRangeAndSite(monthStart, today, siteId));
        r.setMonthlyJobWorkBilled(jobWorkInvoiceRepo.sumGrandTotalByDateRange(monthStart, today));
        r.setMonthlyMachineWorkBilled(machineRepo.sumBillableTotalAmountByDateRangeAndSite(monthStart, today, siteId));

        // Needs Attention: surface genuinely actionable pending states
        r.setGstPendingCount(invoiceRepo.countByGstStatusPending());
        // Unbilled trips: prior days this month only (exclude today — still being created)
        LocalDate yesterday = today.minusDays(1);
        if (!yesterday.isBefore(monthStart)) {
            r.setUnbilledTripsCount(tripRepo.countUnbilledByDateRangeAndSite(monthStart, yesterday, siteId));
        }
        r.setRatePendingMachineWorkCount(machineRepo.countRatePendingBySite(siteId));
        r.setJwOverlapCount(jobWorkInvoiceRepo.countInvoicesWithOverlappingPeriods());

        return r;
    }
}
