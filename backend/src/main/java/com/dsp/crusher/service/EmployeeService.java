package com.dsp.crusher.service;

import com.dsp.crusher.config.TenantContext;
import com.dsp.crusher.dto.EmployeeRequest;
import com.dsp.crusher.dto.EmployeeResponse;
import com.dsp.crusher.entity.Employee;
import com.dsp.crusher.exception.ResourceNotFoundException;
import com.dsp.crusher.repository.EmployeeRepository;
import lombok.RequiredArgsConstructor;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.util.List;
import java.util.stream.Collectors;

@Service
@RequiredArgsConstructor
public class EmployeeService {

    private final EmployeeRepository repo;

    public List<EmployeeResponse> listActive() {
        return repo.findByStatusOrderByNameAsc("ACTIVE").stream()
                .map(this::toResponse).collect(Collectors.toList());
    }

    public List<EmployeeResponse> listAll() {
        return repo.findAll().stream()
                .map(this::toResponse).collect(Collectors.toList());
    }

    public EmployeeResponse get(Long id) {
        return toResponse(repo.findById(id)
                .orElseThrow(() -> new ResourceNotFoundException("Employee not found: " + id)));
    }

    @Transactional
    public EmployeeResponse create(EmployeeRequest req) {
        Employee e = new Employee();
        e.setTenantId(TenantContext.get());
        apply(e, req);
        return toResponse(repo.save(e));
    }

    @Transactional
    public EmployeeResponse update(Long id, EmployeeRequest req) {
        Employee e = repo.findById(id)
                .orElseThrow(() -> new ResourceNotFoundException("Employee not found: " + id));
        apply(e, req);
        return toResponse(repo.save(e));
    }

    @Transactional
    public EmployeeResponse deactivate(Long id) {
        Employee e = repo.findById(id)
                .orElseThrow(() -> new ResourceNotFoundException("Employee not found: " + id));
        e.setStatus("INACTIVE");
        return toResponse(repo.save(e));
    }

    private void apply(Employee e, EmployeeRequest req) {
        e.setName(req.getName());
        e.setDesignation(req.getDesignation());
        e.setWageType(req.getWageType() != null ? req.getWageType() : "DAILY");
        e.setWageRate(req.getWageRate());
    }

    private EmployeeResponse toResponse(Employee e) {
        EmployeeResponse r = new EmployeeResponse();
        r.setId(e.getId());
        r.setName(e.getName());
        r.setDesignation(e.getDesignation());
        r.setWageType(e.getWageType());
        r.setWageRate(e.getWageRate());
        r.setStatus(e.getStatus());
        return r;
    }
}
