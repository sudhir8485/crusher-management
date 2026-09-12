package com.dsp.crusher.config;

import com.dsp.crusher.filter.JwtAuthFilter;
import lombok.RequiredArgsConstructor;
import org.springframework.context.annotation.Bean;
import org.springframework.context.annotation.Configuration;
import org.springframework.http.HttpMethod;
import org.springframework.security.config.annotation.method.configuration.EnableMethodSecurity;
import org.springframework.security.config.annotation.web.builders.HttpSecurity;
import org.springframework.security.config.annotation.web.configuration.EnableWebSecurity;
import org.springframework.security.config.annotation.web.configurers.AbstractHttpConfigurer;
import org.springframework.security.config.http.SessionCreationPolicy;
import org.springframework.security.crypto.bcrypt.BCryptPasswordEncoder;
import org.springframework.security.crypto.password.PasswordEncoder;
import org.springframework.security.web.SecurityFilterChain;
import org.springframework.security.web.authentication.UsernamePasswordAuthenticationFilter;
import org.springframework.web.cors.CorsConfiguration;
import org.springframework.web.cors.CorsConfigurationSource;
import org.springframework.web.cors.UrlBasedCorsConfigurationSource;

import java.util.List;

@Configuration
@EnableWebSecurity
@EnableMethodSecurity
@RequiredArgsConstructor
public class SecurityConfig {

    private final JwtAuthFilter jwtAuthFilter;

    @Bean
    public SecurityFilterChain securityFilterChain(HttpSecurity http) throws Exception {
        http
            .csrf(AbstractHttpConfigurer::disable)
            .cors(cors -> cors.configurationSource(corsConfigurationSource()))
            .sessionManagement(s -> s.sessionCreationPolicy(SessionCreationPolicy.STATELESS))
            .authorizeHttpRequests(auth -> auth
                // ── Public ────────────────────────────────────────────────────────────
                .requestMatchers("/api/auth/**", "/swagger-ui/**", "/swagger-ui.html",
                        "/api-docs/**", "/v3/api-docs/**").permitAll()

                // ── Platform admin: SUPER_ADMIN only ─────────────────────────────────
                .requestMatchers("/api/admin/**").hasRole("SUPER_ADMIN")

                // ── Tenant admin: OWNER_ADMIN only ────────────────────────────────────
                .requestMatchers("/api/users/**").hasRole("OWNER_ADMIN")
                // Tenant profile: GET open to tenant roles; PUT is OWNER_ADMIN only (enforced by @PreAuthorize)
                // SUPER_ADMIN excluded — has no tenant scope
                .requestMatchers("/api/tenant/**").hasAnyRole("OWNER_ADMIN", "OFFICE_ACCOUNTANT", "SITE_STAFF")

                // ── Finance + Reports: no SITE_STAFF ─────────────────────────────────
                .requestMatchers("/api/invoices/**", "/api/job-work-invoices/**",
                        "/api/party-payments/**", "/api/ledger/**",
                        "/api/reports/**").hasAnyRole("OWNER_ADMIN", "OFFICE_ACCOUNTANT")

                // ── Dashboard: split by role ──────────────────────────────────────────
                .requestMatchers("/api/dashboard/site-staff").hasRole("SITE_STAFF")
                .requestMatchers("/api/dashboard").hasAnyRole("OWNER_ADMIN", "OFFICE_ACCOUNTANT")

                // ── Operations: all three roles (SITE_STAFF does data entry here) ─────
                .requestMatchers("/api/trips/**").hasAnyRole("OWNER_ADMIN", "OFFICE_ACCOUNTANT", "SITE_STAFF")
                .requestMatchers("/api/diesel/**").hasAnyRole("OWNER_ADMIN", "OFFICE_ACCOUNTANT", "SITE_STAFF")
                .requestMatchers("/api/dabar/**").hasAnyRole("OWNER_ADMIN", "OFFICE_ACCOUNTANT", "SITE_STAFF")
                .requestMatchers("/api/machine-work/**").hasAnyRole("OWNER_ADMIN", "OFFICE_ACCOUNTANT", "SITE_STAFF")
                .requestMatchers("/api/attendance/**").hasAnyRole("OWNER_ADMIN", "OFFICE_ACCOUNTANT")

                // ── Reference/master data: reads needed by all three (form pickers) ───
                .requestMatchers(HttpMethod.GET, "/api/sites/**").hasAnyRole("OWNER_ADMIN", "OFFICE_ACCOUNTANT", "SITE_STAFF")
                .requestMatchers(HttpMethod.GET, "/api/vehicles/**").hasAnyRole("OWNER_ADMIN", "OFFICE_ACCOUNTANT", "SITE_STAFF")
                .requestMatchers(HttpMethod.GET, "/api/materials/**").hasAnyRole("OWNER_ADMIN", "OFFICE_ACCOUNTANT", "SITE_STAFF")
                .requestMatchers(HttpMethod.GET, "/api/machines/**").hasAnyRole("OWNER_ADMIN", "OFFICE_ACCOUNTANT", "SITE_STAFF")
                .requestMatchers(HttpMethod.GET, "/api/services/**").hasAnyRole("OWNER_ADMIN", "OFFICE_ACCOUNTANT", "SITE_STAFF")
                .requestMatchers(HttpMethod.GET, "/api/employees/**").hasAnyRole("OWNER_ADMIN", "OFFICE_ACCOUNTANT", "SITE_STAFF")

                // ── Parties: financial sub-resources excluded for SITE_STAFF ──────────
                // More-specific paths must come before the catch-all /api/parties/**
                .requestMatchers(HttpMethod.GET, "/api/parties/balances").hasAnyRole("OWNER_ADMIN", "OFFICE_ACCOUNTANT")
                .requestMatchers(HttpMethod.GET, "/api/parties/*/statement").hasAnyRole("OWNER_ADMIN", "OFFICE_ACCOUNTANT")
                .requestMatchers(HttpMethod.GET, "/api/parties/*/trip-balance").hasAnyRole("OWNER_ADMIN", "OFFICE_ACCOUNTANT")
                .requestMatchers(HttpMethod.GET, "/api/parties/*/unsettled-payables").hasAnyRole("OWNER_ADMIN", "OFFICE_ACCOUNTANT")
                // Basic party list + detail: all three roles (needed for trip/JW pickers)
                .requestMatchers(HttpMethod.GET, "/api/parties", "/api/parties/*").hasAnyRole("OWNER_ADMIN", "OFFICE_ACCOUNTANT", "SITE_STAFF")
                // Party writes: OWNER_ADMIN + OFFICE_ACCOUNTANT (method-level @PreAuthorize handles OWNER_ADMIN-only delete)
                .requestMatchers("/api/parties/**").hasAnyRole("OWNER_ADMIN", "OFFICE_ACCOUNTANT")

                // ── Write operations on master data (method-level @PreAuthorize handles specifics) ──
                .requestMatchers("/api/sites/**", "/api/vehicles/**", "/api/materials/**",
                        "/api/machines/**", "/api/services/**",
                        "/api/employees/**").hasAnyRole("OWNER_ADMIN", "OFFICE_ACCOUNTANT")

                // ── Default deny: anything not explicitly listed is blocked ───────────
                .anyRequest().denyAll()
            )
            .addFilterBefore(jwtAuthFilter, UsernamePasswordAuthenticationFilter.class);

        return http.build();
    }

    @Bean
    public PasswordEncoder passwordEncoder() {
        return new BCryptPasswordEncoder(12);
    }

    @Bean
    public CorsConfigurationSource corsConfigurationSource() {
        CorsConfiguration config = new CorsConfiguration();
        config.setAllowedOriginPatterns(List.of("*"));
        config.setAllowedMethods(List.of("GET", "POST", "PUT", "PATCH", "DELETE", "OPTIONS"));
        config.setAllowedHeaders(List.of("*"));
        config.setAllowCredentials(true);
        UrlBasedCorsConfigurationSource source = new UrlBasedCorsConfigurationSource();
        source.registerCorsConfiguration("/**", config);
        return source;
    }
}
