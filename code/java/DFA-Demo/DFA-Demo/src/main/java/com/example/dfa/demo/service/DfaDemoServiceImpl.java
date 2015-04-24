/*
 * To change this license header, choose License Headers in Project Properties.
 * To change this template file, choose Tools | Templates
 * and open the template in the editor.
 */
package com.example.dfa.demo.service;

import com.example.dfa.demo.dto.DfaFindDTO;
import com.example.dfa.demo.dto.DfaWorkflowsDTO;
import java.io.Serializable;
import java.util.Collection;
import java.util.Map;
import javax.sql.DataSource;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.jdbc.core.BeanPropertyRowMapper;
import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.jdbc.core.namedparam.BeanPropertySqlParameterSource;
import org.springframework.jdbc.core.namedparam.SqlParameterSource;
import org.springframework.jdbc.core.simple.ParameterizedBeanPropertyRowMapper;
import org.springframework.jdbc.core.simple.SimpleJdbcCall;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

/**
 *
 * @author Richard
 */
@Transactional
@Service
public class DfaDemoServiceImpl implements Serializable, DfaDemoService {
 
    JdbcTemplate jdbcTemplate;
    SimpleJdbcCall findWorkflowsSpaCall;
    
    @Autowired 
    public void setJdbcTemplate(JdbcTemplate jdbcTemplate) {
        this.jdbcTemplate = jdbcTemplate;
        findWorkflowsSpaCall = new SimpleJdbcCall(jdbcTemplate).withProcedureName("sp_findEmployeeWorkflows").withCatalogName("demo_employee")
                .returningResultSet("workflows", 
                        BeanPropertyRowMapper.newInstance(DfaWorkflowsDTO.class));
    }
    
    public Collection<DfaWorkflowsDTO> findWorkflows(DfaFindDTO criteria) {
        SqlParameterSource inParams = new BeanPropertySqlParameterSource(criteria);
        Map<String,Object> out = findWorkflowsSpaCall.execute(inParams);
        Collection<DfaWorkflowsDTO> workflows = (Collection)out.get("workflows");
        return workflows;
    }
    
}
