package com.dsp.crusher.repository;

import com.dsp.crusher.entity.Employee;
import org.springframework.data.jpa.repository.JpaRepository;
import java.util.List;

public interface EmployeeRepository extends JpaRepository<Employee, Long> {
    List<Employee> findByStatusOrderByNameAsc(String status);
}
