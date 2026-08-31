package com.dsp.crusher.repository;

import com.dsp.crusher.entity.DieselUsage;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Query;
import java.math.BigDecimal;
import java.time.LocalDate;
import java.util.List;

public interface DieselUsageRepository extends JpaRepository<DieselUsage, Long> {
    List<DieselUsage> findByStatusOrderByUsageDateDescIdDesc(String status);
    List<DieselUsage> findByUsageDateAndStatusOrderByIdAsc(LocalDate date, String status);
    List<DieselUsage> findByUsageDateBetweenAndStatusOrderByUsageDateDescIdDesc(LocalDate from, LocalDate to, String status);

    @Query("SELECT COALESCE(SUM(u.quantityLiters), 0) FROM DieselUsage u WHERE u.status = 'ACTIVE'")
    BigDecimal sumTotalUsed();
}
