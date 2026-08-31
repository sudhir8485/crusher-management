package com.dsp.crusher.controller;

import com.dsp.crusher.dto.UserRequest;
import com.dsp.crusher.dto.UserResponse;
import com.dsp.crusher.service.UserService;
import jakarta.validation.Valid;
import lombok.RequiredArgsConstructor;
import org.springframework.web.bind.annotation.*;

import java.util.List;

@RestController
@RequestMapping("/api/users")
@RequiredArgsConstructor
public class UserController {

    private final UserService service;

    @GetMapping
    public List<UserResponse> list() {
        return service.listAll();
    }

    @PostMapping
    public UserResponse create(@Valid @RequestBody UserRequest req) {
        return service.create(req);
    }

    @PutMapping("/{id}")
    public UserResponse update(@PathVariable Long id, @Valid @RequestBody UserRequest req) {
        return service.update(id, req);
    }

    @DeleteMapping("/{id}")
    public UserResponse deactivate(@PathVariable Long id) {
        return service.deactivate(id);
    }
}
