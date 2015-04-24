/*
 * To change this license header, choose License Headers in Project Properties.
 * To change this template file, choose Tools | Templates
 * and open the template in the editor.
 */
package com.example.dfa.demo.dto;

import java.io.Serializable;

/**
 *
 * @author rodare
 */
public class DfaWorkflowsDTO implements Serializable {
    
    String position;
    String lastNm;
    String firstNm; 
    String stateAbbr; 
    Boolean active;
    String workflowTx;
    String eventTx; 
    String stateTx;
    String expectedNextEventTx;

    public String getPosition() {
        return position;
    }

    public void setPosition(String position) {
        this.position = position;
    }

    public String getLastNm() {
        return lastNm;
    }

    public void setLastNm(String lastNm) {
        this.lastNm = lastNm;
    }

    public String getFirstNm() {
        return firstNm;
    }

    public void setFirstNm(String firstNm) {
        this.firstNm = firstNm;
    }

    public String getStateAbbr() {
        return stateAbbr;
    }

    public void setStateAbbr(String stateAbbr) {
        this.stateAbbr = stateAbbr;
    }

    public Boolean getActive() {
        return active;
    }

    public void setActive(Boolean active) {
        this.active = active;
    }

    public String getWorkflowTx() {
        return workflowTx;
    }

    public void setWorkflowTx(String workflowTx) {
        this.workflowTx = workflowTx;
    }

    public String getEventTx() {
        return eventTx;
    }

    public void setEventTx(String eventTx) {
        this.eventTx = eventTx;
    }

    public String getStateTx() {
        return stateTx;
    }

    public void setStateTx(String stateTx) {
        this.stateTx = stateTx;
    }

    public String getExpectedNextEventTx() {
        return expectedNextEventTx;
    }

    public void setExpectedNextEventTx(String expectedNextEventTx) {
        this.expectedNextEventTx = expectedNextEventTx;
    }


}
