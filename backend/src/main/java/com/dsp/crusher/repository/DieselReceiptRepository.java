package com.dsp.crusher.repository;

import com.dsp.crusher.entity.DieselReceipt;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;
import java.math.BigDecimal;
import java.time.LocalDate;
import java.util.List;

public interface DieselReceiptRepository extends JpaRepository<DieselReceipt, Long> {
    List<DieselReceipt> findByStatusOrderByReceiptDateDescIdDesc(String status);
    List<DieselReceipt> findByReceiptDateAndStatusOrderByIdAsc(LocalDate date, String status);
    List<DieselReceipt> findByReceiptDateBetweenAndStatusOrderByReceiptDateDescIdDesc(LocalDate from, LocalDate to, String status);

    @Query("SELECT COALESCE(SUM(r.quantityLiters), 0) FROM DieselReceipt r WHERE r.status = 'ACTIVE'")
    BigDecimal sumTotalReceived();

    List<DieselReceipt> findByReceiptDateBetweenAndStatusOrderByReceiptDateAscIdAsc(LocalDate from, LocalDate to, String status);

    @Query("SELECT COALESCE(SUM(r.quantityLiters), 0) FROM DieselReceipt r WHERE r.receiptDate < :before AND r.status = 'ACTIVE'")
    BigDecimal sumReceivedBefore(@Param("before") LocalDate before);
}
