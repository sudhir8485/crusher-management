package com.dsp.crusher.repository;

import com.dsp.crusher.entity.EmployeePayment;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;

import java.math.BigDecimal;
import java.time.LocalDate;
import java.util.List;

public interface EmployeePaymentRepository extends JpaRepository<EmployeePayment, Long> {

    List<EmployeePayment> findByEmployeeIdAndStatusOrderByPaymentDateAscIdAsc(Long employeeId, String status);

    @Query("SELECT p FROM EmployeePayment p WHERE p.employeeId = :empId AND p.paymentDate BETWEEN :from AND :to AND p.status = 'ACTIVE' ORDER BY p.paymentDate ASC, p.id ASC")
    List<EmployeePayment> findByEmployeeAndDateRange(@Param("empId") Long empId,
                                                      @Param("from") LocalDate from,
                                                      @Param("to") LocalDate to);

    @Query("SELECT p FROM EmployeePayment p WHERE p.paymentDate BETWEEN :from AND :to AND p.status = 'ACTIVE' ORDER BY p.employeeId ASC, p.paymentDate ASC")
    List<EmployeePayment> findAllByDateRange(@Param("from") LocalDate from, @Param("to") LocalDate to);

    @Query("SELECT COALESCE(SUM(p.amount), 0) FROM EmployeePayment p WHERE p.employeeId = :empId AND p.paymentDate BETWEEN :from AND :to AND p.status = 'ACTIVE'")
    BigDecimal sumByEmployeeAndDateRange(@Param("empId") Long empId,
                                         @Param("from") LocalDate from,
                                         @Param("to") LocalDate to);

    // All-time total paid for an employee (for closing balance)
    @Query("SELECT COALESCE(SUM(p.amount), 0) FROM EmployeePayment p WHERE p.employeeId = :empId AND p.status = 'ACTIVE'")
    BigDecimal sumAllActiveByEmployeeId(@Param("empId") Long empId);

    // Total paid strictly before a date (for opening balance)
    @Query("SELECT COALESCE(SUM(p.amount), 0) FROM EmployeePayment p WHERE p.employeeId = :empId AND p.status = 'ACTIVE' AND p.paymentDate < :before")
    BigDecimal sumAllActiveByEmployeeIdBefore(@Param("empId") Long empId, @Param("before") LocalDate before);
}
