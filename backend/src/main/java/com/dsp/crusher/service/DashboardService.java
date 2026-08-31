package com.dsp.crusher.service;

import com.dsp.crusher.dto.DashboardResponse;
import com.dsp.crusher.entity.Material;
import com.dsp.crusher.repository.*;
import lombok.RequiredArgsConstructor;
import org.springframework.stereotype.Service;

import java.math.BigDecimal;
import java.time.LocalDate;
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

    public DashboardResponse get() {
        LocalDate today = LocalDate.now();
        LocalDate monthStart = today.withDayOfMonth(1);

        DashboardResponse r = new DashboardResponse();
        r.setAsOf(today);

        // Today's trips
        r.setTodayTripCount(tripRepo.countByTripDateAndStatus(today, "ACTIVE"));
        r.setTodayTotalBrass(tripRepo.sumBrassByDate(today));

        // Diesel balance
        BigDecimal received = receiptRepo.sumTotalReceived();
        BigDecimal used = usageRepo.sumTotalUsed();
        r.setDieselTotalReceived(received);
        r.setDieselTotalUsed(used);
        r.setDieselBalanceLiters(received.subtract(used));

        // This month
        r.setMonthlyMachineHours(machineRepo.sumHoursByDateRange(monthStart, today));
        r.setMonthlyInvoiceTotal(invoiceRepo.sumGrandTotalByDateRange(monthStart, today));
        r.setMonthlyInvoiceCount(invoiceRepo.countByInvoiceDateBetweenAndStatus(monthStart, today, "ACTIVE"));
        r.setMonthlyPaymentsTotal(paymentRepo.sumByDateRange(monthStart, today));

        // Monthly trip summary by material
        List<Object[]> rows = tripRepo.summarizeByMaterial(monthStart, today);
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
        return r;
    }
}
