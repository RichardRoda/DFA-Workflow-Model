<%-- 
    Document   : DisplayWorkflowList
    Created on : Apr 24, 2015, 9:23:41 AM
    Author     : rodare
--%>

<%@page contentType="text/html" pageEncoding="UTF-8"%>
<%@ include file="/jsp/JspHeaderSetup.jsp" %>
<tiles:importAttribute name="dfaWorkflowId" ignore="true"/>
<!DOCTYPE html>
<html>
    <head>
        <meta http-equiv="Content-Type" content="text/html; charset=UTF-8">
        <title>Active Workflows</title>
    </head>
    <body>
        <h1>Active Workflows</h1>
        <a href="<c:url value='/addNewEmployeeProspect.htm'/>">Add New Prospective Employee</a>
    <tiles:insertDefinition name="workflowsTable">
        <tiles:putAttribute name="workflows" value="${workflows}"/>
        <tiles:putAttribute name="showActive" value="${empty query.active}"/>        
    </tiles:insertDefinition>
    </body>
</html>
