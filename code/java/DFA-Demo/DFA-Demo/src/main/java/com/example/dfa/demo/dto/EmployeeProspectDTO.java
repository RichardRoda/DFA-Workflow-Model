/*
 * To change this license header, choose License Headers in Project Properties.
 * To change this template file, choose Tools | Templates
 * and open the template in the editor.
 */
package com.example.dfa.demo.dto;

import java.io.Serializable;
import java.math.BigDecimal;
import java.math.BigInteger;

/**
 *
 * @author Richard
 */
public class EmployeeProspectDTO implements Serializable {
    Long employeeId;
    String lastNm; // VARCHAR(64) NOT NULL,
    String firstNm; //FIRST_NM VARCHAR(64) NOT NULL,
    String middleNm; //MIDDLE_NM VARCHAR(64) NULL,
    String streetNm; //STREET_NM VARCHAR(64) NULL,
    String cityNm; // CITY_NM VARCHAR(64) NULL,
    Short  stateId; //STATE_ID SMALLINT UNSIGNED NULL,
    String phoneNum; // PHONE_NUM VARCHAR(20) NULL,
    String emailAddr; // EMAIL_ADDR VARCHAR(64) NULL,
    String position; // POSITION VARCHAR(32) NULL,
    BigDecimal salary; // NUMERIC(12,2) NULL,
    Integer workflowTyp = 1000;
    String commentTx = "New employee added.";
    String modBy = "Add Employee User";
    Long dfaWorkflowId;
    
    public Long getEmployeeId() {
        return employeeId;
    }

    public void setEmployeeId(Long employeeId) {
        this.employeeId = employeeId;
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

    public String getMiddleNm() {
        return middleNm;
    }

    public void setMiddleNm(String middleNm) {
        this.middleNm = middleNm;
    }

    public String getStreetNm() {
        return streetNm;
    }

    public void setStreetNm(String streetNm) {
        this.streetNm = streetNm;
    }

    public String getCityNm() {
        return cityNm;
    }

    public void setCityNm(String cityNm) {
        this.cityNm = cityNm;
    }

    public Short getStateId() {
        return stateId;
    }

    public void setStateId(Short stateId) {
        this.stateId = stateId;
    }

    public String getPhoneNum() {
        return phoneNum;
    }

    public void setPhoneNum(String phoneNum) {
        this.phoneNum = phoneNum;
    }

    public String getEmailAddr() {
        return emailAddr;
    }

    public void setEmailAddr(String emailAddr) {
        this.emailAddr = emailAddr;
    }

    public String getPosition() {
        return position;
    }

    public void setPosition(String position) {
        this.position = position;
    }

    public BigDecimal getSalary() {
        return salary;
    }

    public void setSalary(BigDecimal salary) {
        this.salary = salary;
    }

    public Integer getWorkflowTyp() {
        return workflowTyp;
    }

    public void setWorkflowTyp(Integer workflowTyp) {
        this.workflowTyp = workflowTyp;
    }

    public String getCommentTx() {
        return commentTx;
    }

    public void setCommentTx(String commentTx) {
        this.commentTx = commentTx;
    }

    public String getModBy() {
        return modBy;
    }

    public void setModBy(String modBy) {
        this.modBy = modBy;
    }

    public Long getDfaWorkflowId() {
        return dfaWorkflowId;
    }

    public void setDfaWorkflowId(Long dfaWorkflowId) {
        this.dfaWorkflowId = dfaWorkflowId;
    }

    public Boolean getRaiseError() {
        return Boolean.TRUE;
    }
}
