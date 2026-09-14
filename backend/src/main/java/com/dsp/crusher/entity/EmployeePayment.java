package com.dsp.crusher.entity;

import jakarta.persistence.*;
import lombok.Getter;
import lombok.Setter;
import java.math.BigDecimal;
import java.time.LocalDate;
import java.time.LocalDateTime;

@Entity
@Table(name = "employee_payments")
@Getter @Setter
public class EmployeePayment {

    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    private Long id;

    @Column(name = "tenant_id", nullable = false)
    private Long tenantId;

    @Column(name = "employee_id", nullable = false)
    private Long employeeId;

    @Column(name = "payment_date", nullable = false)
    private LocalDate paymentDate;

    @Column(nullable = false, precision = 12, scale = 2)
    private BigDecimal amount;

    @Column(length = 500)
    private String notes;

    @Column(name = "payment_type", nullable = false, length = 20)
    private String paymentType = "ADVANCE";  // ADVANCE | SALARY

    @Column(name = "payment_method", nullable = false, length = 30)
    private String paymentMethod = "CASH";   // CASH | BANK_TRANSFER | UPI | OTHER

    @Column(name = "created_by_name", length = 200)
    private String createdByName;

    @Column(nullable = false, length = 20)
    private String status = "ACTIVE";

    @Column(nullable = false)
    private LocalDateTime createdAt = LocalDateTime.now();
}
