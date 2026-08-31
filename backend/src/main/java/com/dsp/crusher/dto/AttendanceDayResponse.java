package com.dsp.crusher.dto;

import lombok.Getter;
import lombok.Setter;
import java.time.LocalDate;
import java.util.List;

@Getter @Setter
public class AttendanceDayResponse {

    private LocalDate date;
    private int presentCount;
    private int absentCount;
    private int halfDayCount;
    private int leaveCount;
    private int unmarkedCount;
    private List<EmployeeAttendance> employees;

    @Getter @Setter
    public static class EmployeeAttendance {
        private Long employeeId;
        private String employeeName;
        private String designation;
        private String wageType;
        private Long recordId;          // null if not yet marked
        private String attendanceStatus; // PRESENT | ABSENT | HALF_DAY | LEAVE | null
        private String notes;
    }
}
