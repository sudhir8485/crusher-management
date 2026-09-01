package com.dsp.crusher.service;

import com.dsp.crusher.config.TenantContext;
import com.dsp.crusher.dto.AttendanceDayResponse;
import com.dsp.crusher.dto.AttendanceMarkRequest;
import com.dsp.crusher.dto.AttendanceMonthlyResponse;
import com.dsp.crusher.entity.AttendanceRecord;
import com.dsp.crusher.entity.Employee;
import com.dsp.crusher.repository.AttendanceRepository;
import com.dsp.crusher.repository.EmployeeRepository;
import lombok.RequiredArgsConstructor;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.time.LocalDate;
import java.time.YearMonth;
import java.util.*;
import java.util.stream.Collectors;

@Service
@RequiredArgsConstructor
public class AttendanceService {

    private final AttendanceRepository attendanceRepo;
    private final EmployeeRepository employeeRepo;

    // Returns all active employees + their attendance status for the given date.
    // Employees not yet marked show attendanceStatus = null.
    public AttendanceDayResponse getDay(LocalDate date) {
        List<Employee> activeEmployees = employeeRepo.findByStatusOrderByNameAsc("ACTIVE");
        List<AttendanceRecord> records = attendanceRepo.findByAttendanceDateOrderByEmployeeIdAsc(date);

        Map<Long, AttendanceRecord> byEmployee = records.stream()
                .collect(Collectors.toMap(AttendanceRecord::getEmployeeId, r -> r));

        int present = 0, absent = 0, halfDay = 0, leave = 0, unmarked = 0;

        List<AttendanceDayResponse.EmployeeAttendance> rows =
                activeEmployees.stream().map(emp -> {
                    AttendanceDayResponse.EmployeeAttendance ea =
                            new AttendanceDayResponse.EmployeeAttendance();
                    ea.setEmployeeId(emp.getId());
                    ea.setEmployeeName(emp.getName());
                    ea.setDesignation(emp.getDesignation());
                    ea.setWageType(emp.getWageType());

                    AttendanceRecord rec = byEmployee.get(emp.getId());
                    if (rec != null) {
                        ea.setRecordId(rec.getId());
                        ea.setAttendanceStatus(rec.getStatus());
                        ea.setNotes(rec.getNotes());
                    }
                    return ea;
                }).collect(Collectors.toList());

        for (AttendanceDayResponse.EmployeeAttendance ea : rows) {
            String s = ea.getAttendanceStatus();
            if (s == null) unmarked++;
            else switch (s) {
                case "PRESENT"  -> present++;
                case "ABSENT"   -> absent++;
                case "HALF_DAY" -> halfDay++;
                case "LEAVE"    -> leave++;
                default         -> unmarked++;
            }
        }

        AttendanceDayResponse r = new AttendanceDayResponse();
        r.setDate(date);
        r.setPresentCount(present);
        r.setAbsentCount(absent);
        r.setHalfDayCount(halfDay);
        r.setLeaveCount(leave);
        r.setUnmarkedCount(unmarked);
        r.setEmployees(rows);
        return r;
    }

    // Upsert: create or update attendance for one employee on a date.
    @Transactional
    public AttendanceDayResponse mark(AttendanceMarkRequest req) {
        Optional<AttendanceRecord> existing =
                attendanceRepo.findByAttendanceDateAndEmployeeId(req.getDate(), req.getEmployeeId());

        AttendanceRecord rec = existing.orElseGet(() -> {
            AttendanceRecord nr = new AttendanceRecord();
            nr.setTenantId(TenantContext.get());
            nr.setAttendanceDate(req.getDate());
            nr.setEmployeeId(req.getEmployeeId());
            return nr;
        });

        rec.setStatus(req.getStatus());
        rec.setNotes(req.getNotes());
        attendanceRepo.save(rec);

        return getDay(req.getDate());
    }

    public AttendanceMonthlyResponse getMonth(YearMonth ym) {
        LocalDate from = ym.atDay(1);
        LocalDate to = ym.atEndOfMonth();
        int daysInMonth = ym.lengthOfMonth();

        List<Employee> activeEmployees = employeeRepo.findByStatusOrderByNameAsc("ACTIVE");
        List<AttendanceRecord> records =
                attendanceRepo.findByAttendanceDateBetweenOrderByAttendanceDateAscEmployeeIdAsc(from, to);

        // employeeId → (dayOfMonth → status)
        Map<Long, Map<Integer, String>> byEmployee = new HashMap<>();
        for (AttendanceRecord rec : records) {
            byEmployee
                .computeIfAbsent(rec.getEmployeeId(), k -> new HashMap<>())
                .put(rec.getAttendanceDate().getDayOfMonth(), rec.getStatus());
        }

        List<AttendanceMonthlyResponse.EmployeeMonth> empList = activeEmployees.stream().map(emp -> {
            AttendanceMonthlyResponse.EmployeeMonth em = new AttendanceMonthlyResponse.EmployeeMonth();
            em.setEmployeeId(emp.getId());
            em.setEmployeeName(emp.getName());
            em.setDesignation(emp.getDesignation());
            em.setWageType(emp.getWageType());

            Map<Integer, String> dayMap = byEmployee.getOrDefault(emp.getId(), Collections.emptyMap());
            List<String> days = new ArrayList<>();
            int present = 0, half = 0, absent = 0, leave = 0;
            for (int d = 1; d <= daysInMonth; d++) {
                String status = dayMap.get(d);
                days.add(status);
                if ("PRESENT".equals(status)) present++;
                else if ("HALF_DAY".equals(status)) half++;
                else if ("ABSENT".equals(status)) absent++;
                else if ("LEAVE".equals(status)) leave++;
            }
            em.setDays(days);
            em.setPresentCount(present);
            em.setHalfDayCount(half);
            em.setAbsentCount(absent);
            em.setLeaveCount(leave);
            return em;
        }).collect(Collectors.toList());

        AttendanceMonthlyResponse r = new AttendanceMonthlyResponse();
        r.setMonth(ym.toString());
        r.setDaysInMonth(daysInMonth);
        r.setEmployees(empList);
        return r;
    }
}
