package com.dsp.crusher.controller;

import com.dsp.crusher.dto.EmployeeRequest;
import com.dsp.crusher.dto.EmployeeResponse;
import com.dsp.crusher.service.EmployeeService;
import jakarta.validation.Valid;
import lombok.RequiredArgsConstructor;
import org.springframework.web.bind.annotation.*;

import java.util.List;

@RestController
@RequestMapping("/api/employees")
@RequiredArgsConstructor
public class EmployeeController {

    private final EmployeeService service;

    @GetMapping
    public List<EmployeeResponse> list(@RequestParam(defaultValue = "false") boolean all) {
        return all ? service.listAll() : service.listActive();
    }

    @GetMapping("/{id}")
    public EmployeeResponse get(@PathVariable Long id) {
        return service.get(id);
    }

    @PostMapping
    public EmployeeResponse create(@Valid @RequestBody EmployeeRequest req) {
        return service.create(req);
    }

    @PutMapping("/{id}")
    public EmployeeResponse update(@PathVariable Long id, @Valid @RequestBody EmployeeRequest req) {
        return service.update(id, req);
    }

    @DeleteMapping("/{id}")
    public EmployeeResponse deactivate(@PathVariable Long id) {
        return service.deactivate(id);
    }
}
