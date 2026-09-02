package com.dsp.crusher.repository;

import com.dsp.crusher.entity.AttendanceRecord;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;

import java.time.LocalDate;
import java.util.List;
import java.util.Optional;

public interface AttendanceRepository extends JpaRepository<AttendanceRecord, Long> {

    List<AttendanceRecord> findByAttendanceDateOrderByEmployeeIdAsc(LocalDate date);

    @Query("SELECT a FROM AttendanceRecord a WHERE a.attendanceDate = :date AND (:siteId IS NULL OR a.siteId = :siteId) ORDER BY a.employeeId ASC")
    List<AttendanceRecord> findByDateAndSite(@Param("date") LocalDate date, @Param("siteId") Long siteId);

    Optional<AttendanceRecord> findByAttendanceDateAndEmployeeId(LocalDate date, Long employeeId);

    List<AttendanceRecord> findByAttendanceDateBetweenOrderByAttendanceDateAscEmployeeIdAsc(
            LocalDate from, LocalDate to);

    // For wage summary: count by status in a date range for one employee
    @Query("SELECT a.status, COUNT(a) FROM AttendanceRecord a " +
           "WHERE a.employeeId = :empId AND a.attendanceDate BETWEEN :from AND :to " +
           "GROUP BY a.status")
    List<Object[]> countByStatusForEmployee(@Param("empId") Long empId,
                                            @Param("from") LocalDate from,
                                            @Param("to") LocalDate to);
}
