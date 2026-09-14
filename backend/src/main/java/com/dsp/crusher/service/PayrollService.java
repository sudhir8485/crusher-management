package com.dsp.crusher.service;

import com.dsp.crusher.config.TenantContext;
import com.dsp.crusher.dto.PayrollSummaryResponse;
import com.dsp.crusher.dto.RecordAdvanceRequest;
import com.dsp.crusher.entity.AttendanceRecord;
import com.dsp.crusher.entity.Employee;
import com.dsp.crusher.entity.EmployeePayment;
import com.dsp.crusher.repository.AttendanceRepository;
import com.dsp.crusher.repository.EmployeePaymentRepository;
import com.dsp.crusher.repository.EmployeeRepository;
import lombok.RequiredArgsConstructor;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.math.BigDecimal;
import java.math.RoundingMode;
import java.time.LocalDate;
import java.time.YearMonth;
import java.time.temporal.ChronoUnit;
import java.util.*;
import java.util.stream.Collectors;

@Service
@RequiredArgsConstructor
public class PayrollService {

    private final EmployeeRepository employeeRepo;
    private final AttendanceRepository attendanceRepo;
    private final EmployeePaymentRepository paymentRepo;

    // ── List all employees with payroll summary ───────────────────────────────

    public List<PayrollSummaryResponse> listPayroll(LocalDate from, LocalDate to) {
        List<Employee> employees = employeeRepo.findByStatusOrderByNameAsc("ACTIVE");

        Map<Long, int[]> periodCounts = fetchAttendanceCounts(
                employees.stream().map(Employee::getId).collect(Collectors.toList()), from, to);

        List<EmployeePayment> periodPayments = paymentRepo.findAllByDateRange(from, to);
        Map<Long, BigDecimal> periodPaidByEmp = periodPayments.stream()
                .collect(Collectors.groupingBy(
                        EmployeePayment::getEmployeeId,
                        Collectors.reducing(BigDecimal.ZERO, EmployeePayment::getAmount, BigDecimal::add)));

        long daysInPeriod = ChronoUnit.DAYS.between(from, to) + 1;

        return employees.stream().map(emp -> {
            int[] counts  = periodCounts.getOrDefault(emp.getId(), new int[4]);
            int present = counts[0], half = counts[1], absent = counts[2], leave = counts[3];

            BigDecimal periodEarned = calculateEarned(emp, present, half, leave, daysInPeriod);
            BigDecimal periodPaid   = periodPaidByEmp.getOrDefault(emp.getId(), BigDecimal.ZERO);

            // Opening = all earned before this period − all paid before this period
            BigDecimal opening = computeEarnedBefore(emp, from)
                    .subtract(paymentRepo.sumAllActiveByEmployeeIdBefore(emp.getId(), from));
            BigDecimal closing = opening.add(periodEarned).subtract(periodPaid);

            PayrollSummaryResponse r = new PayrollSummaryResponse();
            r.setEmployeeId(emp.getId());
            r.setEmployeeName(emp.getName());
            r.setDesignation(emp.getDesignation());
            r.setWageType(emp.getWageType());
            r.setWageRate(emp.getWageRate());
            r.setFrom(from);
            r.setTo(to);
            r.setPresentCount(present);
            r.setHalfDayCount(half);
            r.setAbsentCount(absent);
            r.setLeaveCount(leave);
            r.setEarnedAmount(periodEarned);
            r.setAdvancesPaid(periodPaid);
            r.setOpeningBalance(opening);
            r.setClosingBalance(closing);
            r.setBalanceOwed(closing);
            r.setAdvances(List.of());
            return r;
        }).collect(Collectors.toList());
    }

    // ── Single employee detail ────────────────────────────────────────────────

    public PayrollSummaryResponse getEmployeePayroll(Long employeeId, LocalDate from, LocalDate to) {
        Employee emp = employeeRepo.findById(employeeId)
                .orElseThrow(() -> new IllegalArgumentException("Employee not found: " + employeeId));

        int[] counts = fetchAttendanceCounts(List.of(employeeId), from, to)
                .getOrDefault(employeeId, new int[4]);
        int present = counts[0], half = counts[1], absent = counts[2], leave = counts[3];

        long daysInPeriod = ChronoUnit.DAYS.between(from, to) + 1;
        BigDecimal periodEarned = calculateEarned(emp, present, half, leave, daysInPeriod);

        List<EmployeePayment> payments = paymentRepo.findByEmployeeAndDateRange(employeeId, from, to);
        BigDecimal periodPaid = payments.stream()
                .map(EmployeePayment::getAmount)
                .reduce(BigDecimal.ZERO, BigDecimal::add);

        // Opening = all earned before this period − all paid before this period
        BigDecimal opening = computeEarnedBefore(emp, from)
                .subtract(paymentRepo.sumAllActiveByEmployeeIdBefore(employeeId, from));
        BigDecimal closing = opening.add(periodEarned).subtract(periodPaid);

        List<PayrollSummaryResponse.AdvanceEntry> entries = payments.stream().map(p -> {
            PayrollSummaryResponse.AdvanceEntry e = new PayrollSummaryResponse.AdvanceEntry();
            e.setId(p.getId());
            e.setPaymentDate(p.getPaymentDate());
            e.setAmount(p.getAmount());
            e.setPaymentType(p.getPaymentType() != null ? p.getPaymentType() : "ADVANCE");
            e.setNotes(p.getNotes());
            return e;
        }).collect(Collectors.toList());

        PayrollSummaryResponse r = new PayrollSummaryResponse();
        r.setEmployeeId(emp.getId());
        r.setEmployeeName(emp.getName());
        r.setDesignation(emp.getDesignation());
        r.setWageType(emp.getWageType());
        r.setWageRate(emp.getWageRate());
        r.setFrom(from);
        r.setTo(to);
        r.setPresentCount(present);
        r.setHalfDayCount(half);
        r.setAbsentCount(absent);
        r.setLeaveCount(leave);
        r.setEarnedAmount(periodEarned);
        r.setAdvancesPaid(periodPaid);
        r.setOpeningBalance(opening);
        r.setClosingBalance(closing);
        r.setBalanceOwed(closing);
        r.setAdvances(entries);
        return r;
    }

    // ── Record payment ────────────────────────────────────────────────────────

    @Transactional
    public PayrollSummaryResponse.AdvanceEntry recordAdvance(RecordAdvanceRequest req) {
        EmployeePayment p = new EmployeePayment();
        p.setTenantId(TenantContext.get());
        p.setEmployeeId(req.getEmployeeId());
        p.setPaymentDate(req.getDate());
        p.setAmount(req.getAmount());
        p.setPaymentType(req.getPaymentType() != null ? req.getPaymentType() : "ADVANCE");
        p.setPaymentMethod(req.getPaymentMethod() != null ? req.getPaymentMethod() : "CASH");
        p.setNotes(req.getNotes());
        return toEntry(paymentRepo.save(p));
    }

    // ── Edit payment (date, amount, notes) ───────────────────────────────────

    @Transactional
    public PayrollSummaryResponse.AdvanceEntry updateAdvance(Long id, RecordAdvanceRequest req) {
        EmployeePayment p = paymentRepo.findById(id)
                .orElseThrow(() -> new IllegalArgumentException("Payment not found: " + id));
        p.setPaymentDate(req.getDate());
        p.setAmount(req.getAmount());
        if (req.getPaymentMethod() != null) p.setPaymentMethod(req.getPaymentMethod());
        if (req.getNotes() != null) p.setNotes(req.getNotes());
        return toEntry(paymentRepo.save(p));
    }

    // ── Delete payment ────────────────────────────────────────────────────────

    @Transactional
    public void deleteAdvance(Long id) {
        EmployeePayment p = paymentRepo.findById(id)
                .orElseThrow(() -> new IllegalArgumentException("Payment not found: " + id));
        p.setStatus("INACTIVE");
        paymentRepo.save(p);
    }

    // ── Opening balance: sum earnings for all months before `before` ──────────

    private BigDecimal computeEarnedBefore(Employee emp, LocalDate before) {
        List<AttendanceRecord> records =
                attendanceRepo.findByEmployeeIdAndAttendanceDateBeforeOrderByAttendanceDateAsc(
                        emp.getId(), before);
        if (records.isEmpty()) return BigDecimal.ZERO;

        // Group by YearMonth, compute wage per month, sum
        Map<YearMonth, int[]> byMonth = new LinkedHashMap<>();
        for (AttendanceRecord a : records) {
            YearMonth ym = YearMonth.from(a.getAttendanceDate());
            int[] c = byMonth.computeIfAbsent(ym, k -> new int[4]);
            switch (a.getStatus() != null ? a.getStatus() : "") {
                case "PRESENT"  -> c[0]++;
                case "HALF_DAY" -> c[1]++;
                case "ABSENT"   -> c[2]++;
                case "LEAVE"    -> c[3]++;
            }
        }

        BigDecimal total = BigDecimal.ZERO;
        for (Map.Entry<YearMonth, int[]> entry : byMonth.entrySet()) {
            int[] c = entry.getValue();
            long daysInMonth = entry.getKey().lengthOfMonth();
            total = total.add(calculateEarned(emp, c[0], c[1], c[3], daysInMonth));
        }
        return total;
    }

    // ── Wage calculation ──────────────────────────────────────────────────────

    private BigDecimal calculateEarned(Employee emp, int present, int half, int leave, long daysInPeriod) {
        BigDecimal rate = emp.getWageRate();
        if (rate == null || rate.compareTo(BigDecimal.ZERO) <= 0) return BigDecimal.ZERO;

        if ("DAILY".equals(emp.getWageType())) {
            BigDecimal full    = rate.multiply(BigDecimal.valueOf(present));
            BigDecimal halfPay = rate.multiply(BigDecimal.valueOf(half))
                    .divide(BigDecimal.valueOf(2), 2, RoundingMode.HALF_UP);
            return full.add(halfPay).setScale(2, RoundingMode.HALF_UP);
        } else {
            // Monthly: leave = paid leave. Only absent days deducted.
            BigDecimal perDay = rate.divide(BigDecimal.valueOf(daysInPeriod), 6, RoundingMode.HALF_UP);
            BigDecimal effectiveDays = BigDecimal.valueOf(present)
                    .add(BigDecimal.valueOf(half).divide(BigDecimal.valueOf(2), 6, RoundingMode.HALF_UP))
                    .add(BigDecimal.valueOf(leave));
            return perDay.multiply(effectiveDays).setScale(2, RoundingMode.HALF_UP);
        }
    }

    // ── Helpers ───────────────────────────────────────────────────────────────

    private Map<Long, int[]> fetchAttendanceCounts(List<Long> employeeIds, LocalDate from, LocalDate to) {
        Map<Long, int[]> result = new HashMap<>();
        for (Long empId : employeeIds) {
            List<Object[]> rows = attendanceRepo.countByStatusForEmployee(empId, from, to);
            int[] counts = new int[4];
            for (Object[] row : rows) {
                String status = (String) row[0];
                long cnt = ((Number) row[1]).longValue();
                switch (status) {
                    case "PRESENT"  -> counts[0] += (int) cnt;
                    case "HALF_DAY" -> counts[1] += (int) cnt;
                    case "ABSENT"   -> counts[2] += (int) cnt;
                    case "LEAVE"    -> counts[3] += (int) cnt;
                }
            }
            result.put(empId, counts);
        }
        return result;
    }

    private PayrollSummaryResponse.AdvanceEntry toEntry(EmployeePayment p) {
        PayrollSummaryResponse.AdvanceEntry e = new PayrollSummaryResponse.AdvanceEntry();
        e.setId(p.getId());
        e.setPaymentDate(p.getPaymentDate());
        e.setAmount(p.getAmount());
        e.setPaymentType(p.getPaymentType() != null ? p.getPaymentType() : "ADVANCE");
        e.setPaymentMethod(p.getPaymentMethod() != null ? p.getPaymentMethod() : "CASH");
        e.setNotes(p.getNotes());
        return e;
    }
}
