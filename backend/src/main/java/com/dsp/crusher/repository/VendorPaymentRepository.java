package com.dsp.crusher.repository;

import com.dsp.crusher.entity.VendorPayment;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;
import java.math.BigDecimal;
import java.time.LocalDate;
import java.util.List;

public interface VendorPaymentRepository extends JpaRepository<VendorPayment, Long> {

    List<VendorPayment> findByStatusOrderByPaymentDateDescIdDesc(String status);

    List<VendorPayment> findByVendorIdAndStatusOrderByPaymentDateDescIdDesc(Long vendorId, String status);

    List<VendorPayment> findByPaymentDateBetweenAndStatusOrderByPaymentDateDescIdDesc(
            LocalDate from, LocalDate to, String status);

    @Query("SELECT COALESCE(SUM(p.amount), 0) FROM VendorPayment p WHERE p.vendorId = :vendorId AND p.status = 'ACTIVE'")
    BigDecimal sumByVendorId(@Param("vendorId") Long vendorId);
}
