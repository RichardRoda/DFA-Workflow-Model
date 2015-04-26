/*
 * To change this license header, choose License Headers in Project Properties.
 * To change this template file, choose Tools | Templates
 * and open the template in the editor.
 */
package com.example.dfa.demo.service;

import com.example.dfa.demo.dto.DfaFindDTO;
import com.example.dfa.demo.dto.DfaWorkflowDetailDTO;
import com.example.dfa.demo.dto.DfaWorkflowsDTO;
import com.example.dfa.demo.dto.NextEventDTO;
import com.example.dfa.demo.dto.SelectedEventsDTO;
import com.example.dfa.demo.dto.WorkflowStatesDTO;
import java.io.Serializable;
import java.util.Collection;
import java.util.Collections;
import java.util.Map;
import javax.sql.DataSource;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.jdbc.core.BeanPropertyRowMapper;
import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.jdbc.core.namedparam.BeanPropertySqlParameterSource;
import org.springframework.jdbc.core.namedparam.MapSqlParameterSource;
import org.springframework.jdbc.core.namedparam.SqlParameterSource;
import org.springframework.jdbc.core.simple.ParameterizedBeanPropertyRowMapper;
import org.springframework.jdbc.core.simple.SimpleJdbcCall;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

/**
 *
 * @author Richard
 */
@Transactional(rollbackFor = Throwable.class)
@Service
public class DfaDemoServiceImpl implements Serializable, DfaDemoService {
 
    JdbcTemplate jdbcTemplate;
    SimpleJdbcCall findWorkflowsSpaCall;
    SimpleJdbcCall getWorkflowsSpaCall;
    SimpleJdbcCall getSelectedEventsAndStatesSpaCall;
    SimpleJdbcCall processWorkflowEventSpaCall;
    
    @Autowired 
    public void setJdbcTemplate(JdbcTemplate jdbcTemplate) {
        this.jdbcTemplate = jdbcTemplate;
        findWorkflowsSpaCall = new SimpleJdbcCall(jdbcTemplate).withProcedureName("sp_findEmployeeWorkflows").withCatalogName("demo_employee")
                .returningResultSet("workflows", 
                        BeanPropertyRowMapper.newInstance(DfaWorkflowsDTO.class));

        getWorkflowsSpaCall = new SimpleJdbcCall(jdbcTemplate).withProcedureName("sp_findWorkflowAndCurrentSubWorkflows").withCatalogName("demo_employee")
                .returningResultSet("workflows", 
                        BeanPropertyRowMapper.newInstance(DfaWorkflowsDTO.class));

        getSelectedEventsAndStatesSpaCall = new SimpleJdbcCall(jdbcTemplate).withProcedureName("sp_selectWorkflowEventsAndStates").withCatalogName("demo_employee")
                .returningResultSet("events", 
                        BeanPropertyRowMapper.newInstance(SelectedEventsDTO.class))
                .returningResultSet("states", 
                        BeanPropertyRowMapper.newInstance(WorkflowStatesDTO.class));
        
        processWorkflowEventSpaCall = new SimpleJdbcCall(jdbcTemplate).withProcedureName("sp_processWorkflowEvent").withCatalogName("demo_employee");
    }
    
    @Override
    public Collection<DfaWorkflowsDTO> findWorkflows(DfaFindDTO criteria) {
        SqlParameterSource inParams = new BeanPropertySqlParameterSource(criteria);
        Map<String,Object> out = findWorkflowsSpaCall.execute(inParams);
        Collection<DfaWorkflowsDTO> workflows = (Collection)out.get("workflows");
        return workflows;
    }
    
    @Override
    public DfaWorkflowDetailDTO getWorkflowDetail(Long dfaWorkflowId) {
        SqlParameterSource inParam = new MapSqlParameterSource("dfaWorkflowId", dfaWorkflowId);
        Map<String,Object> out = getWorkflowsSpaCall.execute(inParam);
        Collection<DfaWorkflowsDTO> workflows = (Collection)out.get("workflows");
        out = getSelectedEventsAndStatesSpaCall.execute(inParam);
        Collection<SelectedEventsDTO> events = (Collection)out.get("events");
        Collection<WorkflowStatesDTO> states = (Collection)out.get("states");
        
        return new DfaWorkflowDetailDTO(dfaWorkflowId, workflows, events, states);  
    }
    
    @Override
    public NextEventDTO processWorkflowEvent(NextEventDTO nextEvent) {
        SqlParameterSource inParams = new BeanPropertySqlParameterSource(nextEvent);
        processWorkflowEventSpaCall.execute(inParams);
        NextEventDTO result = jdbcTemplate.queryForObject("SELECT dws.DFA_WORKFLOW_ID,dws.DFA_STATE_ID FROM dfa.DFA_WORKFLOW JOIN dfa.DFA_WORKFLOW_STATE dws ON dws.DFA_WORKFLOW_ID = IF(SUB_STATE, dfa.DFA_WORKFLOW.SPAWN_DFA_WORKFLOW_ID, dfa.DFA_WORKFLOW.DFA_WORKFLOW_ID) AND dws.IS_CURRENT = 1 WHERE dfa.DFA_WORKFLOW.DFA_WORKFLOW_ID = ?", new BeanPropertyRowMapper<NextEventDTO>(NextEventDTO.class), nextEvent.getDfaWorkflowId());
        return result;
    }
}
