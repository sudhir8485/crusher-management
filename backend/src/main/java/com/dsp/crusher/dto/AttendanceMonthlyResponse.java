package com.dsp.crusher.dto;

import lombok.Getter;
import lombok.Setter;
import java.util.List;

@Getter @Setter
public class AttendanceMonthlyResponse {

    private String month;       // "2026-09"
    private int daysInMonth;
    private List<EmployeeMonth> employees;

    @Getter @Setter
    public static class EmployeeMonth {
        private Long employeeId;
        private String employeeName;
        private String designation;
        private String wageType;
        private List<String> days;  // index 0 = day 1; null means no record
        private int presentCount;
        private int halfDayCount;
        private int absentCount;
        private int leaveCount;
    }
}
